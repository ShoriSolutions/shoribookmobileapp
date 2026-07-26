-- ================================================================
-- Shorivo -- Booking Confirmation Window (Phase 1): logic.
--
-- Depends on 20260726000001 (schema). Adds:
--   * effective_reminder_channels()  -- shared channel resolver
--   * generate_confirmation_reminders() -- nudge before the deadline
--   * generate_reminders() tweak     -- don't schedule appt reminders while
--                                       a booking is still awaiting confirmation
--   * create_customer_appointment_safe() -- online no-deposit bookings for a
--       confirmation-required business start as 'pending_confirmation'
--   * confirm_appointment() / confirm_guest_appointment() -- confirm a booking
--   * expire_unconfirmed_appointments() + pg_cron -- auto-cancel + notify
--
-- Additive + idempotent. ASCII only. Run manually in the SQL editor.
-- ================================================================

-- 1. Shared channel resolver -------------------------------------------------
-- Effective channels = vendor-enabled AND customer opted-in. Mirrors the logic
-- in generate_reminders so confirmation nudges honour the same preferences.
CREATE OR REPLACE FUNCTION public.effective_reminder_channels(
  p_business_id UUID,
  p_user_id     UUID
)
RETURNS TEXT[]
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_push BOOLEAN; v_email BOOLEAN; v_wa BOOLEAN; v_wa_conn BOOLEAN;
  v_cust_push BOOLEAN := true; v_cust_wa BOOLEAN := true; v_cust_email BOOLEAN := true;
  v_channels TEXT[] := ARRAY[]::TEXT[];
BEGIN
  SELECT push_enabled, email_enabled, whatsapp_enabled, whatsapp_connected
    INTO v_push, v_email, v_wa, v_wa_conn
    FROM public.notification_settings WHERE business_id = p_business_id;
  IF NOT FOUND THEN
    v_push := true; v_email := true; v_wa := false; v_wa_conn := false;
  END IF;
  IF p_user_id IS NOT NULL THEN
    SELECT push_enabled, whatsapp_enabled, email_enabled
      INTO v_cust_push, v_cust_wa, v_cust_email
      FROM public.customer_notification_preferences WHERE user_id = p_user_id;
  END IF;
  IF v_push  AND (p_user_id IS NULL OR v_cust_push)  THEN v_channels := array_append(v_channels, 'push');  END IF;
  IF v_email AND (p_user_id IS NULL OR v_cust_email) THEN v_channels := array_append(v_channels, 'email'); END IF;
  IF v_wa AND v_wa_conn AND (p_user_id IS NULL OR v_cust_wa) THEN v_channels := array_append(v_channels, 'whatsapp'); END IF;
  RETURN v_channels;
END;
$$;

-- 2. Confirmation nudges before the deadline --------------------------------
-- Candidate times: halfway to the deadline, 30 min before, and 10 min before.
-- Past / post-deadline candidates are skipped, so short windows naturally get
-- fewer nudges. Dedup guard prevents doubles across re-runs.
CREATE OR REPLACE FUNCTION public.generate_confirmation_reminders(p_booking_id UUID)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_appt       RECORD;
  v_uid        UUID;
  v_channels   TEXT[];
  v_deadline   TIMESTAMPTZ;
  v_window_min INT;
  v_times      TIMESTAMPTZ[];
  v_when       TIMESTAMPTZ;
  v_ch         TEXT;
BEGIN
  SELECT id, business_id, customer_id, status, created_at, confirmation_deadline
    INTO v_appt FROM public.appointments WHERE id = p_booking_id;
  IF NOT FOUND THEN RETURN; END IF;
  IF v_appt.status <> 'pending_confirmation' OR v_appt.confirmation_deadline IS NULL THEN RETURN; END IF;
  v_deadline := v_appt.confirmation_deadline;
  IF v_deadline <= now() THEN RETURN; END IF;

  SELECT user_id INTO v_uid FROM public.customers WHERE id = v_appt.customer_id;
  v_channels := public.effective_reminder_channels(v_appt.business_id, v_uid);
  IF v_channels IS NULL OR array_length(v_channels, 1) IS NULL THEN RETURN; END IF;

  v_window_min := GREATEST(1, (EXTRACT(EPOCH FROM (v_deadline - v_appt.created_at)) / 60)::int);
  v_times := ARRAY[
    v_appt.created_at + ((v_window_min / 2) || ' minutes')::interval,
    v_deadline - interval '30 minutes',
    v_deadline - interval '10 minutes'
  ];

  FOREACH v_when IN ARRAY v_times LOOP
    CONTINUE WHEN v_when <= now() OR v_when >= v_deadline;
    FOREACH v_ch IN ARRAY v_channels LOOP
      INSERT INTO public.reminder_queue(
        booking_id, business_id, user_id, channel, scheduled_for, kind, payload)
      SELECT p_booking_id, v_appt.business_id, v_uid, v_ch, v_when,
             'confirmation_reminder', jsonb_build_object('deadline', v_deadline)
      WHERE NOT EXISTS (
        SELECT 1 FROM public.reminder_queue
        WHERE booking_id = p_booking_id AND channel = v_ch AND scheduled_for = v_when
          AND kind = 'confirmation_reminder' AND status = 'pending'
      );
    END LOOP;
  END LOOP;
END;
$$;

-- 3. generate_reminders: don't schedule appointment reminders while a booking
--    is still awaiting confirmation. Everything else is unchanged from
--    20260714000000; they are (re)generated when it becomes 'confirmed'.
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
  -- Wait until the booking is actually confirmed before scheduling reminders.
  IF v_appt.status = 'pending_confirmation' THEN RETURN; END IF;
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

-- 4. create_customer_appointment_safe: enter 'pending_confirmation' for online
--    no-deposit bookings at a confirmation-required business. (Copied from
--    20260721000015; only the status decision + INSERT + return changed.)
CREATE OR REPLACE FUNCTION public.create_customer_appointment_safe(
  p_business_id                   UUID,
  p_service_id                    UUID,
  p_start_time                    TIMESTAMPTZ,
  p_customer_first_name           TEXT,
  p_customer_phone                TEXT,
  p_staff_profile_id              UUID DEFAULT NULL,
  p_customer_last_name            TEXT DEFAULT NULL,
  p_customer_whatsapp             TEXT DEFAULT NULL,
  p_customer_email                TEXT DEFAULT NULL,
  p_notes                         TEXT DEFAULT NULL,
  p_cancellation_policy_accepted  BOOLEAN DEFAULT false
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid                UUID;
  v_business            RECORD;
  v_service             RECORD;
  v_end_time             TIMESTAMPTZ;
  v_customer_id          UUID;
  v_existing_by_user      RECORD;
  v_existing_by_phone     RECORD;
  v_lock_key              BIGINT;
  v_conflicts             JSONB;
  v_deposit_amount        NUMERIC;
  v_deposit_status         TEXT;
  v_status                 TEXT;
  v_new_id                 UUID;
  v_conf_required          BOOLEAN := false;
  v_window                 INT;
  v_deadline               TIMESTAMPTZ;
BEGIN
  v_uid := (SELECT auth.uid());  -- NULL for guest bookings (no account)

  IF NOT p_cancellation_policy_accepted THEN
    RAISE EXCEPTION 'cancellation policy must be accepted';
  END IF;

  IF p_customer_first_name IS NULL OR btrim(p_customer_first_name) = '' THEN
    RAISE EXCEPTION 'name is required';
  END IF;
  IF p_customer_phone IS NULL OR btrim(p_customer_phone) = '' THEN
    RAISE EXCEPTION 'phone is required';
  END IF;

  SELECT * INTO v_business FROM public.businesses WHERE id = p_business_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'business not found';
  END IF;
  IF NOT v_business.booking_enabled OR v_business.status = 'not_accepting_bookings' THEN
    RETURN jsonb_build_object('status', 'not_accepting_bookings');
  END IF;

  SELECT * INTO v_service
  FROM public.services
  WHERE id = p_service_id AND business_id = p_business_id AND is_active = true;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'service not found or inactive';
  END IF;

  IF p_staff_profile_id IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.staff_profiles
      WHERE id = p_staff_profile_id
        AND business_id = p_business_id
        AND is_active = true
        AND is_bookable = true
    ) THEN
      RAISE EXCEPTION 'staff member not found or not bookable';
    END IF;
    IF EXISTS (
      SELECT 1 FROM public.service_staff WHERE service_id = p_service_id
    ) AND NOT EXISTS (
      SELECT 1 FROM public.service_staff
      WHERE service_id = p_service_id AND staff_profile_id = p_staff_profile_id
    ) THEN
      RAISE EXCEPTION 'selected staff member does not perform this service';
    END IF;
  END IF;

  v_end_time := p_start_time + (
    (v_service.buffer_before_minutes + v_service.duration_minutes + v_service.buffer_after_minutes)
    * INTERVAL '1 minute'
  );
  IF p_start_time < now() THEN
    RAISE EXCEPTION 'cannot book an appointment in the past';
  END IF;

  -- Guest anti-abuse: cap bookings per phone per business in a rolling day.
  IF v_uid IS NULL THEN
    IF (
      SELECT count(*) FROM public.appointments
      WHERE business_id = p_business_id
        AND customer_phone = btrim(p_customer_phone)
        AND created_at > now() - INTERVAL '24 hours'
    ) >= 6 THEN
      RETURN jsonb_build_object('status', 'rate_limited');
    END IF;
  END IF;

  -- Resolve the customer row. Use `.id IS NOT NULL` (not the RECORD
  -- `IS NOT NULL`, which is false when any column is null) to detect a hit.
  IF v_uid IS NOT NULL THEN
    SELECT * INTO v_existing_by_user
    FROM public.customers
    WHERE business_id = p_business_id AND user_id = v_uid;

    IF v_existing_by_user.id IS NOT NULL THEN
      UPDATE public.customers SET
        first_name = p_customer_first_name,
        last_name = p_customer_last_name,
        phone = p_customer_phone,
        whatsapp_number = p_customer_whatsapp,
        email = p_customer_email
      WHERE id = v_existing_by_user.id;
      v_customer_id := v_existing_by_user.id;
    ELSE
      SELECT * INTO v_existing_by_phone
      FROM public.customers
      WHERE business_id = p_business_id AND phone = trim(p_customer_phone);

      IF v_existing_by_phone.id IS NOT NULL THEN
        IF v_existing_by_phone.user_id IS NOT NULL THEN
          RETURN jsonb_build_object('status', 'phone_conflict');
        END IF;
        UPDATE public.customers SET
          user_id = v_uid,
          first_name = p_customer_first_name,
          last_name = p_customer_last_name,
          whatsapp_number = p_customer_whatsapp,
          email = p_customer_email
        WHERE id = v_existing_by_phone.id;
        v_customer_id := v_existing_by_phone.id;
      ELSE
        INSERT INTO public.customers (
          business_id, user_id, first_name, last_name, phone, whatsapp_number, email
        ) VALUES (
          p_business_id, v_uid, p_customer_first_name, p_customer_last_name,
          trim(p_customer_phone), p_customer_whatsapp, p_customer_email
        )
        RETURNING id INTO v_customer_id;
      END IF;
    END IF;
  ELSE
    SELECT * INTO v_existing_by_phone
    FROM public.customers
    WHERE business_id = p_business_id AND phone = trim(p_customer_phone);

    IF v_existing_by_phone.id IS NOT NULL THEN
      v_customer_id := v_existing_by_phone.id;
      IF v_existing_by_phone.user_id IS NULL THEN
        UPDATE public.customers SET
          first_name = p_customer_first_name,
          last_name = p_customer_last_name,
          whatsapp_number = p_customer_whatsapp,
          email = p_customer_email
        WHERE id = v_existing_by_phone.id;
      END IF;
    ELSE
      INSERT INTO public.customers (
        business_id, user_id, first_name, last_name, phone, whatsapp_number, email
      ) VALUES (
        p_business_id, NULL, p_customer_first_name, p_customer_last_name,
        trim(p_customer_phone), p_customer_whatsapp, p_customer_email
      )
      RETURNING id INTO v_customer_id;
    END IF;
  END IF;

  v_lock_key := hashtext(
    COALESCE(p_staff_profile_id::TEXT, 'business:' || p_business_id::TEXT)
  );
  PERFORM pg_advisory_xact_lock(v_lock_key);

  SELECT jsonb_agg(jsonb_build_object(
           'id', a.id,
           'start_time', a.start_time,
           'end_time', a.end_time,
           'status', a.status,
           'customer_name', a.customer_name
         ))
    INTO v_conflicts
    FROM public.appointments a
   WHERE a.business_id = p_business_id
     AND a.staff_profile_id IS NOT DISTINCT FROM p_staff_profile_id
     AND a.status NOT IN ('cancelled', 'no_show')
     AND a.start_time < v_end_time
     AND a.end_time   > p_start_time;

  IF v_conflicts IS NOT NULL THEN
    RETURN jsonb_build_object('status', 'conflict', 'conflicts', v_conflicts);
  END IF;

  IF v_service.deposit_required THEN
    -- Deposit bookings keep their own 'pending' gate; confirmation is skipped
    -- (per product decision: online, no-deposit bookings only).
    v_deposit_amount := CASE
      WHEN v_service.deposit_type = 'PERCENTAGE' AND v_service.deposit_percentage IS NOT NULL
        THEN ROUND(v_service.price * v_service.deposit_percentage / 100, 2)
      ELSE v_service.deposit_amount
    END;
    v_deposit_status := 'PENDING';
    v_status := 'pending';
  ELSE
    v_deposit_amount := NULL;
    v_deposit_status := 'NOT_REQUIRED';
    v_status := 'confirmed';
    -- Confirmation window: online no-deposit booking at a business that
    -- requires confirmation enters 'pending_confirmation' with a deadline of
    -- min(now + window, start_time). Imminent bookings (no useful window) just
    -- confirm right away.
    IF COALESCE(v_business.require_confirmation, false) THEN
      v_window := GREATEST(5, COALESCE(v_business.confirmation_window_minutes, 120));
      v_deadline := LEAST(now() + (v_window || ' minutes')::interval, p_start_time);
      IF v_deadline > now() + interval '2 minutes' THEN
        v_status := 'pending_confirmation';
        v_conf_required := true;
      END IF;
    END IF;
  END IF;

  INSERT INTO public.appointments (
    business_id, service_id, staff_profile_id, customer_id,
    start_time, end_time, status, price, currency,
    deposit_required, deposit_amount, deposit_paid, deposit_status,
    cancellation_policy_accepted,
    customer_name, customer_phone, customer_email,
    notes, booking_source,
    confirmation_required, confirmation_deadline
  ) VALUES (
    p_business_id, p_service_id, p_staff_profile_id, v_customer_id,
    p_start_time, v_end_time, v_status, v_service.price,
    COALESCE(v_service.currency, v_business.currency),
    v_service.deposit_required, v_deposit_amount, false, v_deposit_status,
    true,
    trim(p_customer_first_name || ' ' || COALESCE(p_customer_last_name, '')),
    trim(p_customer_phone), p_customer_email,
    p_notes, 'ONLINE',
    v_conf_required,
    CASE WHEN v_conf_required THEN v_deadline ELSE NULL END
  )
  RETURNING id INTO v_new_id;

  IF v_conf_required THEN
    PERFORM public.generate_confirmation_reminders(v_new_id);
  END IF;

  RETURN jsonb_build_object(
    'status', 'created',
    'appointment_id', v_new_id,
    'customer_id', v_customer_id,
    'confirmation_required', v_conf_required,
    'confirmation_deadline', CASE WHEN v_conf_required THEN v_deadline ELSE NULL END
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.create_customer_appointment_safe(
  UUID, UUID, TIMESTAMPTZ, TEXT, TEXT, UUID, TEXT, TEXT, TEXT, TEXT, BOOLEAN
) TO anon, authenticated;

-- 5. Confirm a booking -------------------------------------------------------
-- Internal: flips pending_confirmation -> confirmed and stops the confirmation
-- nudges. The status trigger (re)generates the normal appointment reminders.
CREATE OR REPLACE FUNCTION public.confirm_appointment_internal(p_booking_id UUID)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_rows INT; v_status TEXT;
BEGIN
  UPDATE public.appointments
     SET status = 'confirmed', confirmed_at = now(), updated_at = now()
   WHERE id = p_booking_id AND status = 'pending_confirmation';
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  IF v_rows = 0 THEN
    SELECT status INTO v_status FROM public.appointments WHERE id = p_booking_id;
    IF v_status = 'confirmed' THEN
      RETURN jsonb_build_object('status', 'already_confirmed');
    END IF;
    RETURN jsonb_build_object('status', 'expired', 'appointment_status', v_status);
  END IF;
  UPDATE public.reminder_queue SET status = 'cancelled'
   WHERE booking_id = p_booking_id AND kind = 'confirmation_reminder' AND status = 'pending';
  RETURN jsonb_build_object('status', 'confirmed');
END;
$$;

-- Logged-in customer (owns the booking) or business staff/admin.
CREATE OR REPLACE FUNCTION public.confirm_appointment(p_booking_id UUID)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_uid UUID := (SELECT auth.uid()); v_biz UUID; v_cust UUID;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'authentication required'; END IF;
  SELECT business_id, customer_id INTO v_biz, v_cust
    FROM public.appointments WHERE id = p_booking_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'appointment not found'; END IF;
  IF NOT (
    EXISTS (SELECT 1 FROM public.customers c WHERE c.id = v_cust AND c.user_id = v_uid)
    OR public.get_my_business_role(v_biz) IS NOT NULL
    OR public.is_admin()
  ) THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN public.confirm_appointment_internal(p_booking_id);
END;
$$;
GRANT EXECUTE ON FUNCTION public.confirm_appointment(UUID) TO authenticated;

-- Guest: same trust model as cancel_guest_appointment (id + matching phone).
CREATE OR REPLACE FUNCTION public.confirm_guest_appointment(
  p_booking_id UUID,
  p_phone      TEXT
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_match INT;
BEGIN
  SELECT count(*) INTO v_match FROM public.appointments a
   WHERE a.id = p_booking_id
     AND btrim(COALESCE(p_phone, '')) <> ''
     AND a.customer_phone = btrim(p_phone);
  IF v_match = 0 THEN RAISE EXCEPTION 'appointment not found'; END IF;
  RETURN public.confirm_appointment_internal(p_booking_id);
END;
$$;
GRANT EXECUTE ON FUNCTION public.confirm_guest_appointment(UUID, TEXT) TO anon, authenticated;

-- 6. Auto-cancel expired confirmations + notify customer and vendor ----------
-- Run every minute by pg_cron. Cancels bookings whose confirmation deadline has
-- passed, records the reason, frees the slot, and enqueues an email notice to
-- the customer and the business owner. The status trigger cancels any remaining
-- reminders when the row flips to 'cancelled'.
CREATE OR REPLACE FUNCTION public.expire_unconfirmed_appointments()
RETURNS INT
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_appt  RECORD;
  v_uid   UUID;
  v_owner UUID;
  v_count INT := 0;
BEGIN
  FOR v_appt IN
    SELECT a.id, a.business_id, a.customer_id
    FROM public.appointments a
    WHERE a.status = 'pending_confirmation'
      AND a.confirmation_deadline IS NOT NULL
      AND a.confirmation_deadline < now()
    ORDER BY a.confirmation_deadline
    LIMIT 500
  LOOP
    UPDATE public.appointments
       SET status = 'cancelled',
           cancellation_reason = 'confirmation_expired',
           updated_at = now()
     WHERE id = v_appt.id AND status = 'pending_confirmation';
    CONTINUE WHEN NOT FOUND;  -- lost a race with a confirm; skip

    SELECT user_id INTO v_uid FROM public.customers WHERE id = v_appt.customer_id;
    SELECT owner_id INTO v_owner FROM public.businesses WHERE id = v_appt.business_id;

    -- Email is the guaranteed delivery path today (push/whatsapp are stubs);
    -- the dispatcher resolves the address from the appointment / owner profile.
    INSERT INTO public.reminder_queue(booking_id, business_id, user_id, channel, scheduled_for, kind)
      VALUES (v_appt.id, v_appt.business_id, v_uid, 'email', now(), 'confirmation_expired_customer');
    INSERT INTO public.reminder_queue(booking_id, business_id, user_id, channel, scheduled_for, kind)
      VALUES (v_appt.id, v_appt.business_id, v_owner, 'email', now(), 'confirmation_expired_vendor');

    v_count := v_count + 1;
  END LOOP;
  RETURN v_count;
END;
$$;

-- Schedule the sweep every minute. Guarded so the migration still succeeds if
-- pg_cron isn't installed; schedule 'expire-unconfirmed-bookings' manually then.
DO $$
BEGIN
  PERFORM cron.schedule(
    'expire-unconfirmed-bookings', '* * * * *',
    $cron$ SELECT public.expire_unconfirmed_appointments(); $cron$);
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'pg_cron not available - schedule expire-unconfirmed-bookings manually.';
END $$;
