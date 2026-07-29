-- ================================================================
-- Shorivo -- Deposit Verification Phase 2: expose FirstPay details to the
-- paying customer (the one sanctioned exception to the OWNER/ADMIN-only rule).
--
-- Returns the business's FirstPay payment details + the deposit summary ONLY to
-- someone who owns a pending_deposit booking with that business (authed
-- customer, or guest via id + matching phone). Anyone else gets 'forbidden'.
-- Additive + idempotent. ASCII only. Run manually.
-- ================================================================

CREATE OR REPLACE FUNCTION public.get_deposit_payment_details(
  p_appointment_id UUID,
  p_phone          TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_uid  UUID := (SELECT auth.uid());
  v_appt RECORD;
  v_pp   RECORD;
BEGIN
  SELECT a.status, a.deposit_amount, a.currency, a.start_time, a.customer_phone,
         a.business_id, a.deposit_deadline,
         c.user_id AS cust_uid, s.name AS service_name, b.name AS business_name,
         b.timezone AS tz
    INTO v_appt
    FROM public.appointments a
    JOIN public.businesses b ON b.id = a.business_id
    LEFT JOIN public.services s ON s.id = a.service_id
    LEFT JOIN public.customers c ON c.id = a.customer_id
    WHERE a.id = p_appointment_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'appointment not found'; END IF;

  -- Must own this booking: the signed-in customer, or a guest with the phone.
  IF NOT (
    (v_uid IS NOT NULL AND v_appt.cust_uid = v_uid)
    OR (p_phone IS NOT NULL AND btrim(p_phone) <> ''
        AND v_appt.customer_phone = btrim(p_phone))
  ) THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  IF v_appt.status <> 'pending_deposit' THEN
    RETURN jsonb_build_object('status', 'not_pending',
      'appointment_status', v_appt.status);
  END IF;

  SELECT details, deposit_instructions INTO v_pp
    FROM public.payment_profiles
    WHERE business_id = v_appt.business_id AND provider = 'firstpay';
  IF v_pp IS NULL OR NOT public.payment_profile_ready('firstpay', v_pp.details) THEN
    RETURN jsonb_build_object('status', 'no_payment_method');
  END IF;

  RETURN jsonb_build_object(
    'status', 'ok',
    'provider', 'firstpay',
    'deposit_amount', v_appt.deposit_amount,
    'currency', v_appt.currency,
    'service_name', v_appt.service_name,
    'business_name', v_appt.business_name,
    'start_time', v_appt.start_time,
    'deposit_deadline', v_appt.deposit_deadline,
    'account_number', v_pp.details->>'account_number',
    'account_holder_name', v_pp.details->>'account_holder_name',
    'email', v_pp.details->>'email',
    'deposit_instructions', v_pp.deposit_instructions
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_deposit_payment_details(UUID, TEXT)
  TO anon, authenticated;
