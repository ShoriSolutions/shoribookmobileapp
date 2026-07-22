-- ================================================================
-- ShoriBooks -- let a guest cancel / reschedule their own booking without
-- an account. Same trust model as get_guest_appointments: the caller must
-- supply the unguessable appointment id AND the matching phone number, so
-- there's no enumeration exposure. Mirrors cancel_own_/reschedule_own_
-- appointment logic (status guards, conflict check, preserved duration).
-- Additive + idempotent.
-- ================================================================

CREATE OR REPLACE FUNCTION public.cancel_guest_appointment(
  p_appointment_id uuid,
  p_phone          text
)
RETURNS jsonb
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
    AND btrim(COALESCE(p_phone, '')) <> ''
    AND a.customer_phone = btrim(p_phone);

  IF v_appt IS NULL THEN
    RAISE EXCEPTION 'appointment not found';
  END IF;

  IF v_appt.status IN ('cancelled', 'completed', 'no_show') THEN
    RETURN jsonb_build_object('status', 'unchanged',
      'appointment_status', v_appt.status);
  END IF;

  UPDATE public.appointments SET status = 'cancelled' WHERE id = p_appointment_id;
  RETURN jsonb_build_object('status', 'cancelled');
END;
$$;

GRANT EXECUTE ON FUNCTION public.cancel_guest_appointment(uuid, text)
  TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.reschedule_guest_appointment(
  p_appointment_id uuid,
  p_phone          text,
  p_new_start_time timestamptz
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_appt      RECORD;
  v_new_end   timestamptz;
  v_lock_key  bigint;
  v_conflicts jsonb;
BEGIN
  SELECT a.* INTO v_appt
  FROM public.appointments a
  WHERE a.id = p_appointment_id
    AND btrim(COALESCE(p_phone, '')) <> ''
    AND a.customer_phone = btrim(p_phone);

  IF v_appt IS NULL THEN
    RAISE EXCEPTION 'appointment not found';
  END IF;

  IF v_appt.status IN ('cancelled', 'completed', 'no_show') THEN
    RETURN jsonb_build_object('status', 'unchanged',
      'appointment_status', v_appt.status);
  END IF;

  IF p_new_start_time < now() THEN
    RAISE EXCEPTION 'cannot reschedule to a time in the past';
  END IF;

  -- Preserve the originally-booked duration (incl. buffers).
  v_new_end := p_new_start_time + (v_appt.end_time - v_appt.start_time);

  v_lock_key := hashtext(
    COALESCE(v_appt.staff_profile_id::text,
             'business:' || v_appt.business_id::text)
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

GRANT EXECUTE ON FUNCTION public.reschedule_guest_appointment(uuid, text, timestamptz)
  TO anon, authenticated;
