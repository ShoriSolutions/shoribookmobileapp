-- ================================================================
-- Shorivo -- Waitlist (Phase 2).
--
-- Customers can join a waitlist for a business / service (+ optional staff,
-- date, time or range). When a slot frees up -- confirmation expiry, customer
-- cancellation, vendor cancellation, or a no-show -- matching waitlisted
-- customers are notified via the existing reminder pipeline. Vendors can turn
-- waitlist notifications on/off.
--
-- Depends on Phase 1 (20260726000001/2: reminder_queue.kind/payload,
-- effective_reminder_channels, waitlist_enabled column). Additive + idempotent.
-- ASCII only. Run manually in the SQL editor.
-- ================================================================

-- 1. Waitlist entries --------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.waitlist_entries (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id          UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  service_id           UUID REFERENCES public.services(id) ON DELETE CASCADE,       -- null = any service
  staff_profile_id     UUID REFERENCES public.staff_profiles(id) ON DELETE SET NULL, -- null = any pro
  user_id              UUID REFERENCES auth.users(id) ON DELETE CASCADE,            -- null for guests
  customer_name        TEXT NOT NULL,
  customer_phone       TEXT NOT NULL,
  customer_email       TEXT,
  preferred_date       DATE,   -- null = any date
  preferred_time       TEXT,   -- 'HH:MM' optional single preferred time
  preferred_time_start TEXT,   -- optional range start 'HH:MM'
  preferred_time_end   TEXT,   -- optional range end 'HH:MM'
  -- active | booked | cancelled | expired
  status               TEXT NOT NULL DEFAULT 'active',
  notified_at          TIMESTAMPTZ,
  notified_count       INT NOT NULL DEFAULT 0,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_waitlist_business_status
  ON public.waitlist_entries(business_id, status);
CREATE INDEX IF NOT EXISTS idx_waitlist_user
  ON public.waitlist_entries(user_id);
-- The notify query matches on business/service/date over active rows.
CREATE INDEX IF NOT EXISTS idx_waitlist_match
  ON public.waitlist_entries(business_id, service_id, preferred_date)
  WHERE status = 'active';
ALTER TABLE public.waitlist_entries ENABLE ROW LEVEL SECURITY;

-- Read: the customer sees their own; business OWNER/ADMIN/staff see theirs;
-- admins see all. Writes go through the SECURITY DEFINER RPCs below (so guests
-- work too), so there are no client INSERT/UPDATE/DELETE policies.
DROP POLICY IF EXISTS "waitlist_read" ON public.waitlist_entries;
CREATE POLICY "waitlist_read" ON public.waitlist_entries
  FOR SELECT TO authenticated
  USING (
    user_id = (SELECT auth.uid())
    OR public.get_my_business_role(business_id) IS NOT NULL
    OR public.is_admin()
  );
GRANT SELECT ON public.waitlist_entries TO authenticated;

-- 2. Reminder queue can also carry a waitlist notification -------------------
-- These rows aren't tied to an appointment, so booking_id becomes nullable and
-- a waitlist_entry_id is added. process-reminders branches on kind.
ALTER TABLE public.reminder_queue ALTER COLUMN booking_id DROP NOT NULL;
ALTER TABLE public.reminder_queue
  ADD COLUMN IF NOT EXISTS waitlist_entry_id UUID
    REFERENCES public.waitlist_entries(id) ON DELETE CASCADE;

-- 3. Extend save_booking_rules with the waitlist toggle ----------------------
-- Supersedes the 7-arg version from Phase 1; the new arg defaults to NULL =
-- "leave unchanged", so existing callers keep working.
DROP FUNCTION IF EXISTS public.save_booking_rules(UUID, INT, INT, INT, INT, BOOLEAN, INT);
CREATE OR REPLACE FUNCTION public.save_booking_rules(
  p_business_id          UUID,
  p_buffer_minutes       INT,
  p_max_per_day          INT,
  p_max_per_hour         INT,
  p_max_simultaneous     INT,
  p_require_confirmation BOOLEAN DEFAULT NULL,
  p_confirmation_window  INT     DEFAULT NULL,
  p_waitlist_enabled     BOOLEAN DEFAULT NULL
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
    require_confirmation      = COALESCE(p_require_confirmation, require_confirmation),
    confirmation_window_minutes = CASE
      WHEN p_confirmation_window IS NULL THEN confirmation_window_minutes
      ELSE LEAST(10080, GREATEST(5, p_confirmation_window))
    END,
    waitlist_enabled          = COALESCE(p_waitlist_enabled, waitlist_enabled),
    updated_at                = now()
  WHERE id = p_business_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.save_booking_rules(UUID, INT, INT, INT, INT, BOOLEAN, INT, BOOLEAN) TO authenticated;

-- 4. Join / leave the waitlist ----------------------------------------------
-- Customer (authed) or guest (no account). Dedups an identical active request.
CREATE OR REPLACE FUNCTION public.join_waitlist(
  p_business_id      UUID,
  p_service_id       UUID    DEFAULT NULL,
  p_staff_profile_id UUID    DEFAULT NULL,
  p_first_name       TEXT    DEFAULT NULL,
  p_phone            TEXT    DEFAULT NULL,
  p_email            TEXT    DEFAULT NULL,
  p_preferred_date   DATE    DEFAULT NULL,
  p_preferred_time   TEXT    DEFAULT NULL,
  p_time_start       TEXT    DEFAULT NULL,
  p_time_end         TEXT    DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_uid     UUID := (SELECT auth.uid());
  v_enabled BOOLEAN;
  v_id      UUID;
BEGIN
  IF p_first_name IS NULL OR btrim(p_first_name) = '' THEN
    RAISE EXCEPTION 'name is required';
  END IF;
  IF p_phone IS NULL OR btrim(p_phone) = '' THEN
    RAISE EXCEPTION 'phone is required';
  END IF;

  SELECT waitlist_enabled INTO v_enabled FROM public.businesses WHERE id = p_business_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'business not found'; END IF;
  IF NOT COALESCE(v_enabled, false) THEN
    RETURN jsonb_build_object('status', 'disabled');
  END IF;

  -- Reuse an existing active entry for the same request instead of duplicating.
  SELECT id INTO v_id FROM public.waitlist_entries
   WHERE business_id = p_business_id
     AND status = 'active'
     AND service_id IS NOT DISTINCT FROM p_service_id
     AND staff_profile_id IS NOT DISTINCT FROM p_staff_profile_id
     AND preferred_date IS NOT DISTINCT FROM p_preferred_date
     AND ((v_uid IS NOT NULL AND user_id = v_uid)
          OR customer_phone = btrim(p_phone))
   LIMIT 1;
  IF v_id IS NOT NULL THEN
    RETURN jsonb_build_object('status', 'exists', 'entry_id', v_id);
  END IF;

  INSERT INTO public.waitlist_entries(
    business_id, service_id, staff_profile_id, user_id,
    customer_name, customer_phone, customer_email,
    preferred_date, preferred_time, preferred_time_start, preferred_time_end)
  VALUES (
    p_business_id, p_service_id, p_staff_profile_id, v_uid,
    btrim(p_first_name), btrim(p_phone), p_email,
    p_preferred_date, p_preferred_time, p_time_start, p_time_end)
  RETURNING id INTO v_id;

  RETURN jsonb_build_object('status', 'joined', 'entry_id', v_id);
END;
$$;
GRANT EXECUTE ON FUNCTION public.join_waitlist(UUID, UUID, UUID, TEXT, TEXT, TEXT, DATE, TEXT, TEXT, TEXT)
  TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.leave_waitlist(
  p_entry_id UUID,
  p_phone    TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_uid UUID := (SELECT auth.uid()); v_rows INT;
BEGIN
  UPDATE public.waitlist_entries
     SET status = 'cancelled', updated_at = now()
   WHERE id = p_entry_id
     AND status = 'active'
     AND ((v_uid IS NOT NULL AND user_id = v_uid)
          OR (p_phone IS NOT NULL AND btrim(p_phone) <> ''
              AND customer_phone = btrim(p_phone)));
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  RETURN jsonb_build_object('status', CASE WHEN v_rows > 0 THEN 'left' ELSE 'unchanged' END);
END;
$$;
GRANT EXECUTE ON FUNCTION public.leave_waitlist(UUID, TEXT) TO anon, authenticated;

-- Guest waitlist lookup: same trust model as get_guest_appointments
-- (device-remembered ids + matching phone). Returns a fixed JSON shape.
CREATE OR REPLACE FUNCTION public.get_guest_waitlist(
  p_ids   UUID[],
  p_phone TEXT
)
RETURNS JSONB
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT COALESCE(jsonb_agg(t.row ORDER BY t.created_at DESC), '[]'::jsonb)
  FROM (
    SELECT
      w.created_at,
      jsonb_build_object(
        'id', w.id,
        'business_id', w.business_id,
        'service_id', w.service_id,
        'staff_profile_id', w.staff_profile_id,
        'customer_name', w.customer_name,
        'customer_phone', w.customer_phone,
        'customer_email', w.customer_email,
        'preferred_date', w.preferred_date,
        'preferred_time', w.preferred_time,
        'preferred_time_start', w.preferred_time_start,
        'preferred_time_end', w.preferred_time_end,
        'status', w.status,
        'notified_at', w.notified_at,
        'created_at', w.created_at,
        'services', CASE WHEN s.id IS NULL THEN NULL
                    ELSE jsonb_build_object('name', s.name) END,
        'staff_profiles', CASE WHEN sp.id IS NULL THEN NULL
                    ELSE jsonb_build_object('name', sp.name, 'role', sp.role) END,
        'businesses', jsonb_build_object(
          'name', b.name, 'logo_url', b.logo_url, 'slug', b.slug,
          'timezone', b.timezone, 'category', b.category)
      ) AS row
    FROM public.waitlist_entries w
    JOIN public.businesses b ON b.id = w.business_id
    LEFT JOIN public.services s ON s.id = w.service_id
    LEFT JOIN public.staff_profiles sp ON sp.id = w.staff_profile_id
    WHERE btrim(COALESCE(p_phone, '')) <> ''
      AND w.customer_phone = btrim(p_phone)
      AND w.id = ANY(p_ids)
  ) t;
$$;
GRANT EXECUTE ON FUNCTION public.get_guest_waitlist(UUID[], TEXT) TO anon, authenticated;

-- 5. Notify matching waitlisted customers when a slot frees up --------------
-- Respects the vendor toggle and a 30-minute per-entry cooldown (so a run of
-- cancellations can't spam). Entries stay 'active' so they keep their place
-- until they book (marked 'booked' by the trigger) or leave.
CREATE OR REPLACE FUNCTION public.notify_waitlist_for_slot(
  p_business_id      UUID,
  p_service_id       UUID,
  p_staff_profile_id UUID,
  p_start_time       TIMESTAMPTZ
)
RETURNS INT
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_enabled  BOOLEAN;
  v_tz       TEXT;
  v_date     DATE;
  v_entry    RECORD;
  v_channels TEXT[];
  v_ch       TEXT;
  v_count    INT := 0;
BEGIN
  SELECT waitlist_enabled, COALESCE(timezone, 'America/Barbados')
    INTO v_enabled, v_tz FROM public.businesses WHERE id = p_business_id;
  IF NOT COALESCE(v_enabled, false) THEN RETURN 0; END IF;
  v_date := (p_start_time AT TIME ZONE v_tz)::date;

  FOR v_entry IN
    SELECT * FROM public.waitlist_entries w
     WHERE w.business_id = p_business_id
       AND w.status = 'active'
       AND (w.service_id IS NULL OR w.service_id = p_service_id)
       AND (w.staff_profile_id IS NULL OR p_staff_profile_id IS NULL
            OR w.staff_profile_id = p_staff_profile_id)
       AND (w.preferred_date IS NULL OR w.preferred_date = v_date)
       AND (w.notified_at IS NULL OR w.notified_at < now() - interval '30 minutes')
     ORDER BY w.created_at
     LIMIT 25
  LOOP
    v_channels := public.effective_reminder_channels(p_business_id, v_entry.user_id);
    IF v_channels IS NULL OR array_length(v_channels, 1) IS NULL THEN
      v_channels := ARRAY['email'];  -- guaranteed delivery path today
    END IF;
    FOREACH v_ch IN ARRAY v_channels LOOP
      INSERT INTO public.reminder_queue(
        business_id, user_id, channel, scheduled_for, kind, waitlist_entry_id, payload)
      VALUES (
        p_business_id, v_entry.user_id, v_ch, now(), 'waitlist_open', v_entry.id,
        jsonb_build_object('slot_date', v_date, 'start_time', p_start_time));
    END LOOP;
    UPDATE public.waitlist_entries
       SET notified_at = now(), notified_count = notified_count + 1, updated_at = now()
     WHERE id = v_entry.id;
    v_count := v_count + 1;
  END LOOP;
  RETURN v_count;
END;
$$;

-- 6. Trigger: react to bookings freeing / filling slots ----------------------
-- On a booking cancelled / no-show (from any active state), notify the
-- waitlist. On a new active booking, mark the booker's matching entries
-- 'booked' so they stop being notified. Catches every path (customer / guest /
-- vendor / auto-expiry) uniformly.
CREATE OR REPLACE FUNCTION public.appointments_waitlist_sync()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_tz   TEXT;
  v_date DATE;
  v_user UUID;
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.status IN ('cancelled', 'no_show') THEN RETURN NEW; END IF;
    SELECT COALESCE(timezone, 'America/Barbados') INTO v_tz
      FROM public.businesses WHERE id = NEW.business_id;
    v_date := (NEW.start_time AT TIME ZONE v_tz)::date;
    SELECT user_id INTO v_user FROM public.customers WHERE id = NEW.customer_id;
    UPDATE public.waitlist_entries w
       SET status = 'booked', updated_at = now()
     WHERE w.business_id = NEW.business_id
       AND w.status = 'active'
       AND (w.service_id IS NULL OR w.service_id = NEW.service_id)
       AND (w.preferred_date IS NULL OR w.preferred_date = v_date)
       AND ((v_user IS NOT NULL AND w.user_id = v_user)
            OR (NEW.customer_phone IS NOT NULL
                AND w.customer_phone = NEW.customer_phone));
    RETURN NEW;
  ELSIF TG_OP = 'UPDATE' THEN
    IF NEW.status IN ('cancelled', 'no_show')
       AND OLD.status NOT IN ('cancelled', 'no_show', 'completed') THEN
      PERFORM public.notify_waitlist_for_slot(
        NEW.business_id, NEW.service_id, NEW.staff_profile_id, NEW.start_time);
    END IF;
    RETURN NEW;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_appointments_waitlist ON public.appointments;
CREATE TRIGGER trg_appointments_waitlist
  AFTER INSERT OR UPDATE ON public.appointments
  FOR EACH ROW EXECUTE FUNCTION public.appointments_waitlist_sync();

-- 7. Expire stale waitlist entries (past preferred date) ---------------------
CREATE OR REPLACE FUNCTION public.expire_stale_waitlist_entries()
RETURNS INT
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_count INT;
BEGIN
  UPDATE public.waitlist_entries
     SET status = 'expired', updated_at = now()
   WHERE status = 'active'
     AND preferred_date IS NOT NULL
     AND preferred_date < (current_date - 1);  -- a day of grace across zones
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

-- Daily cleanup at 04:00 UTC. Guarded so the migration still succeeds without
-- pg_cron; schedule 'expire-stale-waitlist' manually then.
DO $$
BEGIN
  PERFORM cron.schedule(
    'expire-stale-waitlist', '0 4 * * *',
    $cron$ SELECT public.expire_stale_waitlist_entries(); $cron$);
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'pg_cron not available - schedule expire-stale-waitlist manually.';
END $$;
