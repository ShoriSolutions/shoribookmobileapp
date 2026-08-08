-- ================================================================
-- Shorivo -- reflect a submitted deposit on the appointment.
--
-- submit_deposit() recorded the proof but left the appointment untouched
-- (status stays 'pending_deposit' until the vendor verifies). So the customer's
-- booking still read "Deposit required" after they uploaded proof -- looking
-- like nothing happened. Set appointments.deposit_status = 'SUBMITTED' on
-- submit (status stays pending_deposit so expiry/resubmit still work), and put
-- it back to 'PENDING' on rejection so they can resubmit. Approval already sets
-- 'PAID'.
--
-- Idempotent (CREATE OR REPLACE). Run manually.
-- ================================================================

CREATE OR REPLACE FUNCTION public.submit_deposit(
  p_appointment_id UUID,
  p_proof_path     TEXT,
  p_reference      TEXT DEFAULT NULL,
  p_notes          TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_uid   UUID := (SELECT auth.uid());
  v_appt  RECORD;
  v_owner UUID;
  v_sub   UUID;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'authentication required'; END IF;
  SELECT a.id, a.business_id, a.status, a.deposit_amount, a.currency,
         c.user_id AS cust_uid
    INTO v_appt
    FROM public.appointments a
    JOIN public.customers c ON c.id = a.customer_id
    WHERE a.id = p_appointment_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'appointment not found'; END IF;
  IF v_appt.cust_uid IS DISTINCT FROM v_uid THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF v_appt.status <> 'pending_deposit' THEN
    RETURN jsonb_build_object('status', 'not_pending',
      'appointment_status', v_appt.status);
  END IF;

  UPDATE public.deposit_submissions SET status = 'superseded'
   WHERE appointment_id = p_appointment_id AND status IN ('submitted', 'rejected');

  INSERT INTO public.deposit_submissions(
    appointment_id, business_id, user_id, amount, currency, proof_path,
    reference_number, customer_notes, status)
  VALUES (p_appointment_id, v_appt.business_id, v_uid, v_appt.deposit_amount,
          v_appt.currency, p_proof_path,
          NULLIF(btrim(COALESCE(p_reference, '')), ''),
          NULLIF(btrim(COALESCE(p_notes, '')), ''), 'submitted')
  RETURNING id INTO v_sub;

  -- Reflect on the booking so the customer sees "Deposit submitted" while the
  -- vendor reviews (status stays pending_deposit for expiry/resubmit logic).
  UPDATE public.appointments SET deposit_status = 'SUBMITTED'
   WHERE id = p_appointment_id;

  INSERT INTO public.deposit_audit_log(business_id, appointment_id, submission_id, action, actor_id)
    VALUES (v_appt.business_id, p_appointment_id, v_sub, 'submitted', v_uid);

  SELECT owner_id INTO v_owner FROM public.businesses WHERE id = v_appt.business_id;
  INSERT INTO public.reminder_queue(booking_id, business_id, user_id, channel, scheduled_for, kind)
    VALUES (p_appointment_id, v_appt.business_id, v_owner, 'email', now(), 'deposit_submitted_vendor');

  RETURN jsonb_build_object('status', 'submitted', 'submission_id', v_sub);
END;
$$;
GRANT EXECUTE ON FUNCTION public.submit_deposit(UUID, TEXT, TEXT, TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.reject_deposit(
  p_submission_id UUID,
  p_reason        TEXT,
  p_notes         TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_uid  UUID := (SELECT auth.uid());
  v_sub  RECORD;
  v_cust UUID;
BEGIN
  SELECT * INTO v_sub FROM public.deposit_submissions WHERE id = p_submission_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'submission not found'; END IF;
  IF public.get_my_business_role(v_sub.business_id) NOT IN ('OWNER', 'ADMIN')
     AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  IF v_sub.status <> 'submitted' THEN
    RETURN jsonb_build_object('status', 'unchanged');
  END IF;
  IF p_reason IS NULL OR btrim(p_reason) = '' THEN
    RAISE EXCEPTION 'a reason is required';
  END IF;

  UPDATE public.deposit_submissions
     SET status = 'rejected', reject_reason = p_reason,
         reject_notes = NULLIF(btrim(COALESCE(p_notes, '')), ''),
         reviewed_by = v_uid, reviewed_at = now()
   WHERE id = p_submission_id;

  -- Booking stays 'pending_deposit' so the customer can resubmit; clear the
  -- SUBMITTED marker back to PENDING so it reads "deposit due" again.
  UPDATE public.appointments SET deposit_status = 'PENDING'
   WHERE id = v_sub.appointment_id AND status = 'pending_deposit';

  INSERT INTO public.deposit_audit_log(business_id, appointment_id, submission_id, action, reason, notes, actor_id)
    VALUES (v_sub.business_id, v_sub.appointment_id, p_submission_id, 'rejected',
            p_reason, NULLIF(btrim(COALESCE(p_notes, '')), ''), v_uid);

  SELECT c.user_id INTO v_cust FROM public.appointments a
    JOIN public.customers c ON c.id = a.customer_id WHERE a.id = v_sub.appointment_id;
  INSERT INTO public.reminder_queue(booking_id, business_id, user_id, channel, scheduled_for, kind, payload)
    VALUES (v_sub.appointment_id, v_sub.business_id, v_cust, 'email', now(),
            'deposit_rejected_customer', jsonb_build_object('reason', p_reason));

  RETURN jsonb_build_object('status', 'rejected');
END;
$$;
GRANT EXECUTE ON FUNCTION public.reject_deposit(UUID, TEXT, TEXT) TO authenticated;
