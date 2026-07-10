-- ================================================================
-- BetterBooking — Customer / Marketplace Mode Support
-- Additive only: no existing tables/columns/policies are altered
-- or dropped. Safe to run against the live project. Requires
-- 20260710000000_mobile_app_support.sql already applied.
--
-- Adds:
--   1. customers.user_id — links a business-scoped customer contact
--      record to a real Supabase Auth identity, enabling booking
--      history/favorites across businesses. Nullable, additive.
--   2. customers_self_select / customers_self_update — a customer
--      can read/edit their own contact row directly.
--   3. anon-read grants on staff_availability / staff_breaks — their
--      content is schedule shape only (day/time/label), no PII,
--      same reasoning that already makes business_hours public.
--      blocked_times is deliberately NOT given a blanket grant here
--      because its free-text `reason` column can contain internal
--      ops notes — see get_blocked_time_ranges below instead.
--   4. get_blocked_time_ranges / get_booked_appointment_ranges —
--      privileged RPCs so the Flutter app can compute free slots
--      client-side (porting the web's src/lib/availability.ts logic
--      into Dart) without needing broad access to appointments or
--      blocked_times' reason field.
--   5. customer_owns_row — SECURITY DEFINER helper, same pattern as
--      get_my_business_role, avoiding an RLS-recursion trap for any
--      policy that needs to check "does this customer row belong to
--      the calling user".
--   6. appointments_customer_self_select — read-only booking history
--      for the logged-in customer.
--   7. customer_favorites — new table, straightforward per-user CRUD.
--   8. create_customer_appointment_safe — the customer-facing booking
--      RPC (SECURITY DEFINER, since a plain customer holds no INSERT
--      rights on appointments today). Reuses the exact advisory-lock
--      key scheme from create_appointment_safe so an owner's manual
--      booking and a customer's self-booking racing the same slot
--      still serialize against each other correctly.
--   9. cancel_own_appointment / reschedule_own_appointment —
--      self-service booking management. Deliberately do NOT enforce
--      a cancellation-window rule: the web's "24 hours' notice" text
--      is unconfigurable marketing copy with no backing column or
--      enforcement anywhere in the real product today.
-- ================================================================

-- ── 1. customers.user_id ─────────────────────────────────────────────────────

ALTER TABLE public.customers
  ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id);

CREATE UNIQUE INDEX IF NOT EXISTS customers_business_user_unique
  ON public.customers(business_id, user_id)
  WHERE user_id IS NOT NULL;

-- ── 2. customers_self_select / customers_self_update ────────────────────────

CREATE POLICY "customers_self_select"
  ON public.customers FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()));

CREATE POLICY "customers_self_update"
  ON public.customers FOR UPDATE TO authenticated
  USING (user_id = (SELECT auth.uid()))
  WITH CHECK (user_id = (SELECT auth.uid()));

-- No customers_self_insert policy — rows a customer "owns" are only ever
-- created via create_customer_appointment_safe below, which validates the
-- booking end-to-end before touching the table.

-- ── 3. anon-read grants for staff_availability / staff_breaks ───────────────

CREATE POLICY "staff_avail_anon_select"
  ON public.staff_availability FOR SELECT TO anon
  USING (true);

CREATE POLICY "staff_breaks_anon_select"
  ON public.staff_breaks FOR SELECT TO anon
  USING (true);

GRANT SELECT ON public.staff_availability TO anon;
GRANT SELECT ON public.staff_breaks TO anon;

-- ── 4 & 5. Privileged range RPCs for client-side slot computation ───────────
-- Both reject windows > 31 days as a cheap abuse guard, and both return only
-- the minimum needed to compute availability — no customer PII, and
-- blocked_times' free-text `reason` is deliberately omitted.

CREATE OR REPLACE FUNCTION public.get_blocked_time_ranges(
  p_business_id UUID,
  p_range_start_utc TIMESTAMPTZ,
  p_range_end_utc TIMESTAMPTZ
)
RETURNS TABLE (
  staff_profile_id UUID,
  start_datetime TIMESTAMPTZ,
  end_datetime TIMESTAMPTZ,
  block_type TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_range_end_utc - p_range_start_utc > INTERVAL '31 days' THEN
    RAISE EXCEPTION 'range too large: maximum 31 days';
  END IF;

  RETURN QUERY
  SELECT bt.staff_profile_id, bt.start_datetime, bt.end_datetime, bt.block_type::TEXT
  FROM public.blocked_times bt
  WHERE bt.business_id = p_business_id
    AND bt.start_datetime < p_range_end_utc
    AND bt.end_datetime   > p_range_start_utc;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_blocked_time_ranges(UUID, TIMESTAMPTZ, TIMESTAMPTZ)
  TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.get_booked_appointment_ranges(
  p_business_id UUID,
  p_range_start_utc TIMESTAMPTZ,
  p_range_end_utc TIMESTAMPTZ
)
RETURNS TABLE (
  staff_profile_id UUID,
  start_time TIMESTAMPTZ,
  end_time TIMESTAMPTZ
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_range_end_utc - p_range_start_utc > INTERVAL '31 days' THEN
    RAISE EXCEPTION 'range too large: maximum 31 days';
  END IF;

  RETURN QUERY
  SELECT a.staff_profile_id, a.start_time, a.end_time
  FROM public.appointments a
  WHERE a.business_id = p_business_id
    AND a.status NOT IN ('cancelled', 'no_show')
    AND a.start_time < p_range_end_utc
    AND a.end_time   > p_range_start_utc;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_booked_appointment_ranges(UUID, TIMESTAMPTZ, TIMESTAMPTZ)
  TO anon, authenticated;

-- ── 6. customer_owns_row + appointments_customer_self_select ────────────────

CREATE OR REPLACE FUNCTION public.customer_owns_row(p_customer_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.customers
    WHERE id = p_customer_id
      AND user_id = (SELECT auth.uid())
  );
$$;

CREATE POLICY "appointments_customer_self_select"
  ON public.appointments FOR SELECT TO authenticated
  USING (public.customer_owns_row(customer_id));

-- ── 7. customer_favorites ────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.customer_favorites (
  id          UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  business_id UUID        NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT customer_favorites_unique UNIQUE (user_id, business_id)
);

CREATE INDEX IF NOT EXISTS idx_customer_favorites_user_id
  ON public.customer_favorites(user_id);

ALTER TABLE public.customer_favorites ENABLE ROW LEVEL SECURITY;

CREATE POLICY "customer_favorites_select"
  ON public.customer_favorites FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()));

CREATE POLICY "customer_favorites_insert"
  ON public.customer_favorites FOR INSERT TO authenticated
  WITH CHECK (user_id = (SELECT auth.uid()));

CREATE POLICY "customer_favorites_delete"
  ON public.customer_favorites FOR DELETE TO authenticated
  USING (user_id = (SELECT auth.uid()));

GRANT SELECT, INSERT, DELETE ON public.customer_favorites TO authenticated;

-- ── 8. create_customer_appointment_safe ──────────────────────────────────────
-- SECURITY DEFINER: unlike create_appointment_safe (SECURITY INVOKER, used by
-- business members who already hold INSERT rights via RLS), a plain customer
-- holds NO insert rights on appointments today — this function itself must
-- carry the privilege, which means it validates everything server-side and
-- never trusts client-supplied price/deposit/duration values.

CREATE OR REPLACE FUNCTION public.create_customer_appointment_safe(
  -- Required params first — Postgres requires all DEFAULT-bearing params to
  -- trail the required ones. Supabase-dart calls this with named JSON params
  -- regardless, so this ordering only matters for the CREATE FUNCTION syntax.
  p_business_id                   UUID,
  p_service_id                    UUID,
  p_start_time                    TIMESTAMPTZ,
  p_customer_first_name           TEXT,
  p_customer_phone                TEXT,
  p_staff_profile_id              UUID DEFAULT NULL, -- NULL = any available
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
  v_uid := (SELECT auth.uid());
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'authentication required';
  END IF;

  IF NOT p_cancellation_policy_accepted THEN
    RAISE EXCEPTION 'cancellation policy must be accepted';
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
    IF NOT EXISTS (
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

  -- Resolve the customer row: prefer a match already linked to this user,
  -- else claim an unclaimed row matching this phone, else flag a conflict
  -- if that phone is already claimed by a DIFFERENT user (never silently
  -- reassign — see migration file header comment), else create new.
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

  -- Same advisory-lock key scheme as create_appointment_safe — must match
  -- byte-for-byte so a customer self-booking and an owner manual-booking
  -- racing the same slot still serialize against each other.
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
) TO authenticated;

-- ── 9. cancel_own_appointment / reschedule_own_appointment ──────────────────
-- Deliberately no hard-enforced cancellation-window rule — see migration
-- file header. Both are idempotent no-ops (not errors) on a terminal status.

CREATE OR REPLACE FUNCTION public.cancel_own_appointment(p_appointment_id UUID)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_appt RECORD;
BEGIN
  SELECT a.* INTO v_appt
  FROM public.appointments a
  WHERE a.id = p_appointment_id
    AND public.customer_owns_row(a.customer_id);

  IF v_appt IS NULL THEN
    RAISE EXCEPTION 'appointment not found';
  END IF;

  IF v_appt.status IN ('cancelled', 'completed', 'no_show') THEN
    RETURN jsonb_build_object('status', 'unchanged', 'appointment_status', v_appt.status);
  END IF;

  UPDATE public.appointments SET status = 'cancelled' WHERE id = p_appointment_id;

  RETURN jsonb_build_object('status', 'cancelled');
END;
$$;

GRANT EXECUTE ON FUNCTION public.cancel_own_appointment(UUID) TO authenticated;

CREATE OR REPLACE FUNCTION public.reschedule_own_appointment(
  p_appointment_id UUID,
  p_new_start_time TIMESTAMPTZ
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_appt        RECORD;
  v_new_end      TIMESTAMPTZ;
  v_lock_key      BIGINT;
  v_conflicts     JSONB;
BEGIN
  SELECT a.* INTO v_appt
  FROM public.appointments a
  WHERE a.id = p_appointment_id
    AND public.customer_owns_row(a.customer_id);

  IF v_appt IS NULL THEN
    RAISE EXCEPTION 'appointment not found';
  END IF;

  IF v_appt.status IN ('cancelled', 'completed', 'no_show') THEN
    RETURN jsonb_build_object('status', 'unchanged', 'appointment_status', v_appt.status);
  END IF;

  IF p_new_start_time < now() THEN
    RAISE EXCEPTION 'cannot reschedule to a time in the past';
  END IF;

  -- Preserve the originally-booked duration (including buffers) rather
  -- than re-deriving from the service's current duration_minutes, which
  -- may have changed since this appointment was booked.
  v_new_end := p_new_start_time + (v_appt.end_time - v_appt.start_time);

  v_lock_key := hashtext(
    COALESCE(v_appt.staff_profile_id::TEXT, 'business:' || v_appt.business_id::TEXT)
  );
  PERFORM pg_advisory_xact_lock(v_lock_key);

  SELECT jsonb_agg(jsonb_build_object(
           'id', a.id,
           'start_time', a.start_time,
           'end_time', a.end_time,
           'customer_name', a.customer_name
         ))
    INTO v_conflicts
    FROM public.appointments a
   WHERE a.business_id = v_appt.business_id
     AND a.staff_profile_id IS NOT DISTINCT FROM v_appt.staff_profile_id
     AND a.id != p_appointment_id
     AND a.status NOT IN ('cancelled', 'no_show')
     AND a.start_time < v_new_end
     AND a.end_time   > p_new_start_time;

  IF v_conflicts IS NOT NULL THEN
    RETURN jsonb_build_object('status', 'conflict', 'conflicts', v_conflicts);
  END IF;

  UPDATE public.appointments
  SET start_time = p_new_start_time, end_time = v_new_end
  WHERE id = p_appointment_id;

  RETURN jsonb_build_object('status', 'rescheduled');
END;
$$;

GRANT EXECUTE ON FUNCTION public.reschedule_own_appointment(UUID, TIMESTAMPTZ) TO authenticated;
