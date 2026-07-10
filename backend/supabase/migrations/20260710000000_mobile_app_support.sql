-- ================================================================
-- BetterBooking — Mobile App Support
-- Additive only: no existing tables/columns/policies are altered
-- or dropped. Safe to run against the live project.
--
-- Adds:
--   1. business_members.status (ACTIVE | INVITED) — backs the new
--      staff-invite flow (supabase/functions/invite-staff).
--   2. mark_membership_active() — flips INVITED -> ACTIVE on first
--      login. Idempotent, callable by the invited user themself.
--   3. create_appointment_safe(...) — atomic, race-free booking
--      creation (advisory lock + re-check + insert in one call).
--      Fixes a real TOCTOU gap: today's web app does a plain
--      SELECT-then-INSERT in a Next.js server action
--      (src/app/(dashboard)/dashboard/appointments/actions.ts and
--      calendar/actions.ts), which is not safe once a second
--      client (mobile) exists.
--   4. appointments_no_overlap EXCLUDE constraint — defense-in-depth
--      DB-level guarantee, catches any insert path that bypasses
--      the RPC (including the existing web insert path).
--   5. get_business_report_summary(...) — lightweight aggregation
--      RPC for the mobile Reports screen. OWNER/ADMIN only (see
--      comment on the function for why this check is necessary).
--
-- Requires: 20260702000009_customer_notes_tags.sql (i.e. the full
-- existing migration set) already applied.
-- ================================================================

-- ── 1. business_members.status ──────────────────────────────────────────────

ALTER TABLE public.business_members
  ADD COLUMN IF NOT EXISTS status TEXT NOT NULL DEFAULT 'ACTIVE';

ALTER TABLE public.business_members
  DROP CONSTRAINT IF EXISTS valid_member_status;
ALTER TABLE public.business_members
  ADD CONSTRAINT valid_member_status
  CHECK (status IN ('ACTIVE', 'INVITED'));

-- ── 2. mark_membership_active() ─────────────────────────────────────────────
-- SECURITY DEFINER so it can update a row the caller owns even though the
-- general business_members UPDATE policy is scoped to OWNER/ADMIN acting on
-- others — this is the one case where a user updates their own row. Scoped
-- tightly to auth.uid() + status='INVITED' so it can't be used for anything
-- else. Safe to call on every login: the WHERE clause makes repeat calls a
-- no-op, so the client never needs to track "is this the first login".

CREATE OR REPLACE FUNCTION public.mark_membership_active()
RETURNS VOID
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  UPDATE public.business_members
  SET status = 'ACTIVE', updated_at = now()
  WHERE user_id = (SELECT auth.uid())
    AND status = 'INVITED';
$$;

GRANT EXECUTE ON FUNCTION public.mark_membership_active() TO authenticated;

-- ── 3. create_appointment_safe(...) ─────────────────────────────────────────
-- SECURITY INVOKER (deliberately NOT DEFINER): the caller already has INSERT
-- rights via the existing appointments_member_insert policy
-- (public.get_my_business_role(business_id) IS NOT NULL). This function adds
-- atomicity on top of that, not privilege escalation.
--
-- pg_advisory_xact_lock is transaction-scoped: it is acquired here and
-- automatically released when the transaction (i.e. this single function
-- call, since Postgres functions run in an implicit transaction unless
-- already inside one) commits or rolls back — no manual unlock needed, and
-- it can never be "leaked" by an early return, since every RETURN inside a
-- plpgsql function still passes through the same commit/rollback path.
--
-- Returns jsonb rather than a composite/OUT-param type so supabase-dart's
-- .rpc() can decode it directly with no client-side type registration, and
-- so the response shape can grow additive keys later without an ALTER
-- FUNCTION signature break.

CREATE OR REPLACE FUNCTION public.create_appointment_safe(
  p_business_id                  UUID,
  p_service_id                   UUID,
  p_staff_profile_id             UUID,
  p_customer_id                  UUID,
  p_start_time                   TIMESTAMPTZ,
  p_end_time                     TIMESTAMPTZ,
  p_price                        NUMERIC DEFAULT NULL,
  p_currency                     TEXT DEFAULT 'BBD',
  p_deposit_required              BOOLEAN DEFAULT false,
  p_deposit_amount                NUMERIC DEFAULT NULL,
  p_deposit_status                TEXT DEFAULT 'NOT_REQUIRED',
  p_payment_method                TEXT DEFAULT NULL,
  p_payment_reference             TEXT DEFAULT NULL,
  p_status                        TEXT DEFAULT 'confirmed',
  p_booking_source                TEXT DEFAULT 'WALK_IN',
  p_customer_name                 TEXT DEFAULT NULL,
  p_customer_phone                TEXT DEFAULT NULL,
  p_customer_email                TEXT DEFAULT NULL,
  p_notes                         TEXT DEFAULT NULL,
  p_internal_notes                TEXT DEFAULT NULL,
  p_cancellation_policy_accepted  BOOLEAN DEFAULT false,
  p_force_override                BOOLEAN DEFAULT false
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  v_lock_key   BIGINT;
  v_conflicts  JSONB;
  v_is_paid    BOOLEAN;
  v_new_id     UUID;
BEGIN
  IF p_end_time <= p_start_time THEN
    RAISE EXCEPTION 'end_time must be after start_time';
  END IF;

  -- Serialize concurrent attempts for the same staff member (or, if
  -- unassigned, the whole business's "unassigned" bucket) so two callers
  -- racing on the same slot can never both pass the overlap check below.
  v_lock_key := hashtext(
    COALESCE(p_staff_profile_id::TEXT, 'business:' || p_business_id::TEXT)
  );
  PERFORM pg_advisory_xact_lock(v_lock_key);

  IF NOT p_force_override THEN
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
       AND a.start_time < p_end_time
       AND a.end_time   > p_start_time;

    IF v_conflicts IS NOT NULL THEN
      RETURN jsonb_build_object('status', 'conflict', 'conflicts', v_conflicts);
    END IF;
  END IF;

  v_is_paid := (p_deposit_status = 'PAID');

  INSERT INTO public.appointments (
    business_id, service_id, staff_profile_id, customer_id,
    start_time, end_time, status, price, currency,
    deposit_required, deposit_amount, deposit_paid, deposit_status,
    payment_method, payment_reference, deposit_paid_at,
    cancellation_policy_accepted,
    customer_name, customer_phone, customer_email,
    notes, booking_source, internal_notes
  ) VALUES (
    p_business_id, p_service_id, p_staff_profile_id, p_customer_id,
    p_start_time, p_end_time, p_status, p_price, p_currency,
    p_deposit_required, p_deposit_amount, v_is_paid, p_deposit_status,
    CASE WHEN v_is_paid THEN p_payment_method ELSE NULL END,
    CASE WHEN v_is_paid THEN p_payment_reference ELSE NULL END,
    CASE WHEN v_is_paid THEN now() ELSE NULL END,
    p_cancellation_policy_accepted,
    p_customer_name, p_customer_phone, p_customer_email,
    p_notes, p_booking_source, p_internal_notes
  )
  RETURNING id INTO v_new_id;

  RETURN jsonb_build_object('status', 'created', 'appointment_id', v_new_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_appointment_safe(
  UUID, UUID, UUID, UUID, TIMESTAMPTZ, TIMESTAMPTZ,
  NUMERIC, TEXT, BOOLEAN, NUMERIC, TEXT, TEXT, TEXT, TEXT, TEXT,
  TEXT, TEXT, TEXT, TEXT, TEXT, BOOLEAN, BOOLEAN
) TO authenticated;

-- ── 4. DB-level double-booking guarantee (defense-in-depth) ─────────────────
-- Complements, does not replace, the RPC above: this also silently protects
-- the existing web app's non-atomic insert path without touching web code.
-- Caveat (documented, not fixed here): Postgres EXCLUDE constraints treat
-- NULL staff_profile_id values as pairwise-distinct, so two overlapping
-- unassigned-staff appointments would NOT be caught by this constraint —
-- the RPC's advisory lock (keyed by business_id when staff is null) remains
-- the only guard for that case, so both pieces are needed together.

CREATE EXTENSION IF NOT EXISTS btree_gist;

ALTER TABLE public.appointments
  DROP CONSTRAINT IF EXISTS appointments_no_overlap;

ALTER TABLE public.appointments
  ADD CONSTRAINT appointments_no_overlap
  EXCLUDE USING gist (
    staff_profile_id WITH =,
    tstzrange(start_time, end_time) WITH &&
  )
  WHERE (status NOT IN ('cancelled', 'no_show'));

-- ── 5. get_business_report_summary(...) ──────────────────────────────────────
-- SECURITY INVOKER, but with an EXPLICIT role check inside the body. This is
-- necessary (not just defensive) because the existing appointments_member_select
-- RLS policy allows ANY business member — including STAFF — to read every
-- other staff member's appointments and the business's full revenue data; the
-- web app only hides this in the UI. A reporting RPC must not reproduce that
-- gap for a feature explicitly meant to be OWNER/ADMIN-only, so the check is
-- enforced here in SQL rather than trusted to the Flutter UI layer alone.
-- Revenue definition matches the web app's existing
-- src/app/(dashboard)/dashboard/clients/actions.ts `computeStats`:
-- revenue = sum(price) where status = 'completed'.

CREATE OR REPLACE FUNCTION public.get_business_report_summary(
  p_business_id UUID,
  p_start_date  DATE,
  p_end_date    DATE
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
DECLARE
  v_role   TEXT;
  v_result JSONB;
BEGIN
  v_role := public.get_my_business_role(p_business_id);
  IF v_role NOT IN ('OWNER', 'ADMIN') THEN
    RAISE EXCEPTION 'forbidden: reports are limited to OWNER/ADMIN';
  END IF;

  WITH range_appts AS (
    SELECT *
    FROM public.appointments
    WHERE business_id = p_business_id
      AND start_time >= p_start_date::TIMESTAMPTZ
      AND start_time <  (p_end_date + 1)::TIMESTAMPTZ
  )
  SELECT jsonb_build_object(
    'total_appointments',      COUNT(*),
    'completed_count',         COUNT(*) FILTER (WHERE status = 'completed'),
    'cancelled_count',         COUNT(*) FILTER (WHERE status = 'cancelled'),
    'no_show_count',           COUNT(*) FILTER (WHERE status = 'no_show'),
    'pending_count',           COUNT(*) FILTER (WHERE status = 'pending'),
    'confirmed_count',         COUNT(*) FILTER (WHERE status = 'confirmed'),
    'total_revenue',           COALESCE(SUM(price) FILTER (WHERE status = 'completed'), 0),
    'deposits_collected',      COALESCE(SUM(deposit_amount) FILTER (WHERE deposit_status = 'PAID'), 0),
    'pending_deposits_count',  COUNT(*) FILTER (WHERE deposit_status = 'PENDING'),
    'appointments_by_day', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object('date', d, 'count', c) ORDER BY d), '[]'::jsonb)
      FROM (
        SELECT start_time::DATE AS d, COUNT(*) AS c
        FROM range_appts
        GROUP BY start_time::DATE
      ) daily
    ),
    'status_breakdown', (
      SELECT COALESCE(jsonb_object_agg(status, c), '{}'::jsonb)
      FROM (
        SELECT status, COUNT(*) AS c
        FROM range_appts
        GROUP BY status
      ) by_status
    ),
    'booking_source_breakdown', (
      SELECT COALESCE(jsonb_object_agg(booking_source, c), '{}'::jsonb)
      FROM (
        SELECT booking_source, COUNT(*) AS c
        FROM range_appts
        GROUP BY booking_source
      ) by_source
    ),
    'top_services', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object('service_id', service_id, 'name', name, 'count', c) ORDER BY c DESC), '[]'::jsonb)
      FROM (
        SELECT ra.service_id, s.name, COUNT(*) AS c
        FROM range_appts ra
        JOIN public.services s ON s.id = ra.service_id
        GROUP BY ra.service_id, s.name
        ORDER BY c DESC
        LIMIT 5
      ) top
    )
  )
  INTO v_result
  FROM range_appts;

  RETURN v_result;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_business_report_summary(UUID, DATE, DATE) TO authenticated;
