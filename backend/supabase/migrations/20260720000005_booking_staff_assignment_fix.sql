-- ================================================================
-- ShoriBooks -- fix: booking failed when staff were not assigned to services.
--
-- The staff->service assignment feature made create_customer_appointment_safe
-- reject ANY booking that named a staff member unless a service_staff link
-- existed. But the app's availability calculator treats "this service has no
-- assignments" as "every bookable staff can perform it" -- so a customer would
-- see slots, pick one (tied to a staff member), and then hit an error on the
-- final Confirm step for any business that never used the new assignment UI.
--
-- This replaces the function so the assignment check matches the app: only
-- enforce the service_staff link when the service ACTUALLY HAS assignments.
-- A service with zero service_staff rows is bookable by any bookable staff.
-- Everything else in the function is unchanged. Additive + idempotent.
-- ================================================================

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
  IF v_business IS NULL THEN
    RAISE EXCEPTION 'business not found';
  END IF;
  IF NOT v_business.booking_enabled OR v_business.status = 'not_accepting_bookings' THEN
    RETURN jsonb_build_object('status', 'not_accepting_bookings');
  END IF;

  SELECT * INTO v_service
  FROM public.services
  WHERE id = p_service_id AND business_id = p_business_id AND is_active = true;
  IF v_service IS NULL THEN
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
    -- Only enforce the service<->staff assignment when this service actually
    -- HAS assignments. A service with no service_staff rows is bookable by any
    -- bookable staff (matches the app's availability fallback).
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

  -- Resolve the customer row.
  IF v_uid IS NOT NULL THEN
    SELECT * INTO v_existing_by_user
    FROM public.customers
    WHERE business_id = p_business_id AND user_id = v_uid;

    IF v_existing_by_user IS NOT NULL THEN
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

      IF v_existing_by_phone IS NOT NULL THEN
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

    IF v_existing_by_phone IS NOT NULL THEN
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

  -- Advisory lock so a customer self-booking and an owner manual-booking
  -- racing the same slot serialize against each other.
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
  END IF;

  INSERT INTO public.appointments (
    business_id, service_id, staff_profile_id, customer_id,
    start_time, end_time, status, price, currency,
    deposit_required, deposit_amount, deposit_paid, deposit_status,
    cancellation_policy_accepted,
    customer_name, customer_phone, customer_email,
    notes, booking_source
  ) VALUES (
    p_business_id, p_service_id, p_staff_profile_id, v_customer_id,
    p_start_time, v_end_time, v_status, v_service.price,
    COALESCE(v_service.currency, v_business.currency),
    v_service.deposit_required, v_deposit_amount, false, v_deposit_status,
    true,
    trim(p_customer_first_name || ' ' || COALESCE(p_customer_last_name, '')),
    trim(p_customer_phone), p_customer_email,
    p_notes, 'ONLINE'
  )
  RETURNING id INTO v_new_id;

  RETURN jsonb_build_object(
    'status', 'created',
    'appointment_id', v_new_id,
    'customer_id', v_customer_id
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_customer_appointment_safe(
  UUID, UUID, TIMESTAMPTZ, TEXT, TEXT, UUID, TEXT, TEXT, TEXT, TEXT, BOOLEAN
) TO anon, authenticated;
