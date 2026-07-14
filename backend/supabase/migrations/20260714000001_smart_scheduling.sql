-- ================================================================
-- BetterBooking — Smart Scheduling: buffer, booking limits, and a
-- server-side slot validator. Additive; extends booking validation
-- without replacing create_customer_appointment_safe.
--
-- Timezone/DST: this uses Postgres's native `AT TIME ZONE <iana>` on the
-- business's stored timezone (e.g. 'America/Barbados'), so business-hours
-- checks are correct and DST-aware server-side.
-- ================================================================

-- ── Business-level scheduling rules ─────────────────────────────────────────
ALTER TABLE public.businesses
  ADD COLUMN IF NOT EXISTS buffer_minutes            INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS max_bookings_per_day      INT,   -- null = no limit
  ADD COLUMN IF NOT EXISTS max_bookings_per_hour     INT,
  ADD COLUMN IF NOT EXISTS max_simultaneous_bookings INT;

-- Owner/admin save booking rules.
CREATE OR REPLACE FUNCTION public.save_booking_rules(
  p_business_id       UUID,
  p_buffer_minutes    INT,
  p_max_per_day       INT,
  p_max_per_hour      INT,
  p_max_simultaneous  INT
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF public.get_my_business_role(p_business_id) NOT IN ('OWNER', 'ADMIN') THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  UPDATE public.businesses SET
    buffer_minutes            = GREATEST(0, COALESCE(p_buffer_minutes, 0)),
    max_bookings_per_day      = p_max_per_day,
    max_bookings_per_hour     = p_max_per_hour,
    max_simultaneous_bookings = p_max_simultaneous,
    updated_at                = now()
  WHERE id = p_business_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.save_booking_rules(UUID, INT, INT, INT, INT) TO authenticated;

-- ── Smart scheduling validator ──────────────────────────────────────────────
-- Returns { available: bool, reason: text }. Runs all the checks the spec's
-- scheduling engine requires. SECURITY DEFINER so it can read appointments /
-- blocks / hours regardless of the caller (returns only a yes/no + reason,
-- no PII). Reuse this before confirming a booking; it can also be called at
-- the top of create_customer_appointment_safe for hard server-side enforcement.
CREATE OR REPLACE FUNCTION public.check_slot_available(
  p_business_id      UUID,
  p_service_id       UUID,
  p_staff_profile_id UUID,
  p_start_time       TIMESTAMPTZ
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_biz     RECORD;
  v_svc     RECORD;
  v_tz      TEXT;
  v_buf     INT;
  v_dur     INT;
  v_end     TIMESTAMPTZ;
  v_local   TIMESTAMP;
  v_dow     INT;
  v_date    DATE;
  v_start_m INT;
  v_end_m   INT;
  v_open    INT;
  v_close   INT;
  v_special RECORD;
  v_bh      RECORD;
  v_count   INT;
BEGIN
  SELECT * INTO v_biz FROM public.businesses WHERE id = p_business_id;
  IF v_biz IS NULL THEN
    RETURN jsonb_build_object('available', false, 'reason', 'Business not found');
  END IF;
  IF NOT v_biz.booking_enabled OR v_biz.status = 'not_accepting_bookings' THEN
    RETURN jsonb_build_object('available', false, 'reason', 'Not accepting bookings');
  END IF;

  SELECT * INTO v_svc FROM public.services
    WHERE id = p_service_id AND business_id = p_business_id AND is_active = true;
  IF v_svc IS NULL THEN
    RETURN jsonb_build_object('available', false, 'reason', 'Service unavailable');
  END IF;
  IF p_start_time < now() THEN
    RETURN jsonb_build_object('available', false, 'reason', 'Time is in the past');
  END IF;

  v_tz  := COALESCE(v_biz.timezone, 'America/Barbados');
  v_buf := COALESCE(v_biz.buffer_minutes, 0);
  v_dur := v_svc.buffer_before_minutes + v_svc.duration_minutes + v_svc.buffer_after_minutes;
  v_end := p_start_time + (v_dur || ' minutes')::interval;

  -- Business-local wall clock (DST-aware).
  v_local   := p_start_time AT TIME ZONE v_tz;
  v_dow     := EXTRACT(dow FROM v_local)::int;  -- 0=Sunday..6=Saturday
  v_date    := v_local::date;
  v_start_m := EXTRACT(hour FROM v_local)::int * 60 + EXTRACT(minute FROM v_local)::int;
  v_end_m   := v_start_m + v_dur;

  -- Open hours: a special-day override wins over the weekly hours.
  SELECT * INTO v_special FROM public.special_business_days
    WHERE business_id = p_business_id AND date = v_date;
  IF v_special IS NOT NULL THEN
    IF v_special.is_closed THEN
      RETURN jsonb_build_object('available', false, 'reason', 'Closed that day');
    END IF;
    IF v_special.custom_open_time IS NOT NULL AND v_special.custom_close_time IS NOT NULL THEN
      v_open  := split_part(v_special.custom_open_time::text, ':', 1)::int * 60 + split_part(v_special.custom_open_time::text, ':', 2)::int;
      v_close := split_part(v_special.custom_close_time::text, ':', 1)::int * 60 + split_part(v_special.custom_close_time::text, ':', 2)::int;
    END IF;
  END IF;
  IF v_open IS NULL THEN
    SELECT * INTO v_bh FROM public.business_hours
      WHERE business_id = p_business_id AND day_of_week = v_dow;
    IF v_bh IS NULL OR v_bh.is_closed OR v_bh.open_time IS NULL OR v_bh.close_time IS NULL THEN
      RETURN jsonb_build_object('available', false, 'reason', 'Closed that day');
    END IF;
    v_open  := split_part(v_bh.open_time::text, ':', 1)::int * 60 + split_part(v_bh.open_time::text, ':', 2)::int;
    v_close := split_part(v_bh.close_time::text, ':', 1)::int * 60 + split_part(v_bh.close_time::text, ':', 2)::int;
  END IF;
  IF v_start_m < v_open OR v_end_m > v_close THEN
    RETURN jsonb_build_object('available', false, 'reason', 'Outside business hours');
  END IF;

  -- Manual blocks (business-wide or this staff), padded by the buffer.
  IF EXISTS (
    SELECT 1 FROM public.blocked_times bt
    WHERE bt.business_id = p_business_id
      AND (bt.staff_profile_id IS NULL OR bt.staff_profile_id = p_staff_profile_id)
      AND bt.start_datetime < v_end + (v_buf || ' minutes')::interval
      AND bt.end_datetime   > p_start_time - (v_buf || ' minutes')::interval
  ) THEN
    RETURN jsonb_build_object('available', false, 'reason', 'Time is blocked');
  END IF;

  -- Overlap with an existing appointment for the same staff bucket, + buffer.
  IF EXISTS (
    SELECT 1 FROM public.appointments a
    WHERE a.business_id = p_business_id
      AND a.staff_profile_id IS NOT DISTINCT FROM p_staff_profile_id
      AND a.status NOT IN ('cancelled', 'no_show')
      AND a.start_time < v_end + (v_buf || ' minutes')::interval
      AND a.end_time   > p_start_time - (v_buf || ' minutes')::interval
  ) THEN
    RETURN jsonb_build_object('available', false, 'reason', 'Overlaps another booking');
  END IF;

  -- Booking limits (business-wide, active appointments only).
  IF v_biz.max_bookings_per_day IS NOT NULL THEN
    SELECT count(*) INTO v_count FROM public.appointments a
      WHERE a.business_id = p_business_id AND a.status NOT IN ('cancelled', 'no_show')
        AND (a.start_time AT TIME ZONE v_tz)::date = v_date;
    IF v_count >= v_biz.max_bookings_per_day THEN
      RETURN jsonb_build_object('available', false, 'reason', 'Daily booking limit reached');
    END IF;
  END IF;
  IF v_biz.max_bookings_per_hour IS NOT NULL THEN
    SELECT count(*) INTO v_count FROM public.appointments a
      WHERE a.business_id = p_business_id AND a.status NOT IN ('cancelled', 'no_show')
        AND date_trunc('hour', a.start_time AT TIME ZONE v_tz) = date_trunc('hour', v_local);
    IF v_count >= v_biz.max_bookings_per_hour THEN
      RETURN jsonb_build_object('available', false, 'reason', 'Hourly booking limit reached');
    END IF;
  END IF;
  IF v_biz.max_simultaneous_bookings IS NOT NULL THEN
    SELECT count(*) INTO v_count FROM public.appointments a
      WHERE a.business_id = p_business_id AND a.status NOT IN ('cancelled', 'no_show')
        AND a.start_time < v_end AND a.end_time > p_start_time;
    IF v_count >= v_biz.max_simultaneous_bookings THEN
      RETURN jsonb_build_object('available', false, 'reason', 'Too many simultaneous bookings');
    END IF;
  END IF;

  RETURN jsonb_build_object('available', true);
END;
$$;
GRANT EXECUTE ON FUNCTION public.check_slot_available(UUID, UUID, UUID, TIMESTAMPTZ) TO anon, authenticated;

-- FUTURE / extension points (documented, not built for the MVP):
--  • Multiple operating periods per day (split shifts): store multiple
--    business_hours rows per day_of_week (add a period index) and OR the
--    open-window check across them here.
--  • Recurring appointments, multi-location businesses, and multi-staff
--    parallel scheduling: extend the overlap/limit checks per resource.
--  • Waitlists: when check_slot_available returns false, offer to enqueue.
--  • Calendar sync (Google/Apple/Outlook): mirror appointments + blocks via
--    an Edge Function, and treat external busy blocks like blocked_times here.
