-- ================================================================
-- Shorivo -- Deposit Verification Flow Phase 1: logic.
--
-- Depends on 20260726000008. Adds:
--   * set_pending_deposit trigger -- online deposit bookings enter
--     'pending_deposit' with a submission deadline (no rewrite of the big
--     create_customer_appointment_safe needed).
--   * generate_reminders tweak -- don't schedule appt reminders while a booking
--     is still awaiting deposit verification.
--   * submit_deposit / approve_deposit / reject_deposit RPCs (+ audit log +
--     notifications through the existing reminder pipeline).
--   * expire_pending_deposits() + pg_cron -- auto-cancel + notify (+ waitlist
--     via the existing cancel trigger).
--
-- Additive + idempotent. ASCII only. Run manually.
-- ================================================================

-- 1. Online deposit bookings -> 'pending_deposit' + deadline ------------------
CREATE OR REPLACE FUNCTION public.set_pending_deposit()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_min INT;
BEGIN
  IF TG_OP = 'INSERT' AND NEW.deposit_required IS TRUE
     AND NEW.status = 'pending' AND NEW.booking_source = 'ONLINE' THEN
    NEW.status := 'pending_deposit';
    SELECT deposit_expiry_minutes INTO v_min
      FROM public.businesses WHERE id = NEW.business_id;
    IF v_min IS NOT NULL AND v_min > 0 THEN
      NEW.deposit_deadline := now() + (v_min || ' minutes')::interval;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_set_pending_deposit ON public.appointments;
CREATE TRIGGER trg_set_pending_deposit
  BEFORE INSERT ON public.appointments
  FOR EACH ROW EXECUTE FUNCTION public.set_pending_deposit();

-- 2. generate_reminders: also skip 'pending_deposit' (reminders start on
--    confirmation, i.e. once the deposit is approved). Otherwise unchanged.
CREATE OR REPLACE FUNCTION public.generate_reminders(p_booking_id UUID)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_appt        RECORD;
  v_push        BOOLEAN; v_email BOOLEAN; v_wa BOOLEAN; v_sms BOOLEAN;
  v_wa_conn     BOOLEAN;
  v_offsets     INT[];
  v_uid         UUID;
  v_cust_push   BOOLEAN := true;
  v_cust_wa     BOOLEAN := true;
  v_cust_email  BOOLEAN := true;
  v_channels    TEXT[] := ARRAY[]::TEXT[];
  v_offset      INT;
  v_ch          TEXT;
  v_when        TIMESTAMPTZ;
BEGIN
  SELECT id, business_id, customer_id, start_time, status
    INTO v_appt FROM public.appointments WHERE id = p_booking_id;
  IF NOT FOUND THEN RETURN; END IF;
  IF v_appt.status IN ('cancelled', 'completed', 'no_show') THEN RETURN; END IF;
  IF v_appt.status IN ('pending_confirmation', 'pending_deposit') THEN RETURN; END IF;
  IF v_appt.start_time <= now() THEN RETURN; END IF;

  SELECT push_enabled, email_enabled, whatsapp_enabled, sms_enabled,
         whatsapp_connected, reminder_offsets
    INTO v_push, v_email, v_wa, v_sms, v_wa_conn, v_offsets
    FROM public.notification_settings WHERE business_id = v_appt.business_id;
  IF NOT FOUND THEN
    v_push := true; v_email := true; v_wa := false; v_sms := false;
    v_wa_conn := false; v_offsets := ARRAY[1440, 120];
  END IF;

  SELECT user_id INTO v_uid FROM public.customers WHERE id = v_appt.customer_id;
  IF v_uid IS NOT NULL THEN
    SELECT push_enabled, whatsapp_enabled, email_enabled
      INTO v_cust_push, v_cust_wa, v_cust_email
      FROM public.customer_notification_preferences WHERE user_id = v_uid;
  END IF;

  IF v_push  AND (v_uid IS NULL OR v_cust_push)  THEN v_channels := array_append(v_channels, 'push');  END IF;
  IF v_email AND (v_uid IS NULL OR v_cust_email) THEN v_channels := array_append(v_channels, 'email'); END IF;
  IF v_wa AND v_wa_conn AND (v_uid IS NULL OR v_cust_wa) THEN v_channels := array_append(v_channels, 'whatsapp'); END IF;

  IF array_length(v_channels, 1) IS NULL OR v_offsets IS NULL THEN RETURN; END IF;

  FOREACH v_offset IN ARRAY v_offsets LOOP
    v_when := v_appt.start_time - (v_offset || ' minutes')::interval;
    CONTINUE WHEN v_when <= now();
    FOREACH v_ch IN ARRAY v_channels LOOP
      INSERT INTO public.reminder_queue(booking_id, business_id, user_id, channel, scheduled_for)
      SELECT p_booking_id, v_appt.business_id, v_uid, v_ch, v_when
      WHERE NOT EXISTS (
        SELECT 1 FROM public.reminder_queue
        WHERE booking_id = p_booking_id AND channel = v_ch
          AND scheduled_for = v_when AND status = 'pending'
      );
    END LOOP;
  END LOOP;
END;
$$;

-- 3. Submit a deposit (authed customer). Guests submit via an Edge Function
--    (service role) in Phase 2; the recording logic here mirrors it.
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

  INSERT INTO public.deposit_audit_log(business_id, appointment_id, submission_id, action, actor_id)
    VALUES (v_appt.business_id, p_appointment_id, v_sub, 'submitted', v_uid);

  SELECT owner_id INTO v_owner FROM public.businesses WHERE id = v_appt.business_id;
  INSERT INTO public.reminder_queue(booking_id, business_id, user_id, channel, scheduled_for, kind)
    VALUES (p_appointment_id, v_appt.business_id, v_owner, 'email', now(), 'deposit_submitted_vendor');

  RETURN jsonb_build_object('status', 'submitted', 'submission_id', v_sub);
END;
$$;
GRANT EXECUTE ON FUNCTION public.submit_deposit(UUID, TEXT, TEXT, TEXT) TO authenticated;

-- 4. Approve a deposit -> confirm the booking (OWNER/ADMIN) ------------------
CREATE OR REPLACE FUNCTION public.approve_deposit(p_submission_id UUID)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_uid   UUID := (SELECT auth.uid());
  v_sub   RECORD;
  v_cust  UUID;
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

  UPDATE public.deposit_submissions
     SET status = 'approved', reviewed_by = v_uid, reviewed_at = now()
   WHERE id = p_submission_id;

  UPDATE public.appointments
     SET status = 'confirmed', deposit_status = 'PAID', deposit_paid = true,
         deposit_paid_at = now(), confirmed_at = now(), updated_at = now()
   WHERE id = v_sub.appointment_id AND status = 'pending_deposit';

  INSERT INTO public.deposit_audit_log(business_id, appointment_id, submission_id, action, actor_id)
    VALUES (v_sub.business_id, v_sub.appointment_id, p_submission_id, 'approved', v_uid);

  SELECT c.user_id INTO v_cust FROM public.appointments a
    JOIN public.customers c ON c.id = a.customer_id WHERE a.id = v_sub.appointment_id;
  INSERT INTO public.reminder_queue(booking_id, business_id, user_id, channel, scheduled_for, kind)
    VALUES (v_sub.appointment_id, v_sub.business_id, v_cust, 'email', now(), 'deposit_approved_customer');

  RETURN jsonb_build_object('status', 'approved');
END;
$$;
GRANT EXECUTE ON FUNCTION public.approve_deposit(UUID) TO authenticated;

-- 5. Reject a deposit -> keep the booking pending (OWNER/ADMIN) --------------
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

  -- Booking stays 'pending_deposit' so the customer can resubmit.
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

-- 6. Auto-cancel deposits not submitted before the deadline ------------------
-- Only cancels when NO proof is awaiting review (submitted) or approved; a
-- submission under review is never auto-cancelled. The cancel trigger notifies
-- the waitlist and stops reminders.
CREATE OR REPLACE FUNCTION public.expire_pending_deposits()
RETURNS INT
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_appt RECORD; v_uid UUID; v_count INT := 0;
BEGIN
  FOR v_appt IN
    SELECT a.id, a.business_id, a.customer_id
    FROM public.appointments a
    WHERE a.status = 'pending_deposit'
      AND a.deposit_deadline IS NOT NULL
      AND a.deposit_deadline < now()
      AND NOT EXISTS (
        SELECT 1 FROM public.deposit_submissions s
        WHERE s.appointment_id = a.id AND s.status IN ('submitted', 'approved')
      )
    ORDER BY a.deposit_deadline
    LIMIT 500
  LOOP
    UPDATE public.appointments
       SET status = 'cancelled', cancellation_reason = 'deposit_expired',
           updated_at = now()
     WHERE id = v_appt.id AND status = 'pending_deposit';
    CONTINUE WHEN NOT FOUND;

    SELECT user_id INTO v_uid FROM public.customers WHERE id = v_appt.customer_id;
    INSERT INTO public.reminder_queue(booking_id, business_id, user_id, channel, scheduled_for, kind)
      VALUES (v_appt.id, v_appt.business_id, v_uid, 'email', now(), 'deposit_expired_customer');
    v_count := v_count + 1;
  END LOOP;
  RETURN v_count;
END;
$$;

DO $$
BEGIN
  PERFORM cron.schedule(
    'expire-pending-deposits', '* * * * *',
    $cron$ SELECT public.expire_pending_deposits(); $cron$);
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'pg_cron not available - schedule expire-pending-deposits manually.';
END $$;
