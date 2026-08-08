-- ================================================================
-- Shorivo -- per-tier FEATURE gates (authoritative, server-side).
--
-- The service + staff COUNT caps are already enforced server-side
-- (20260720000004, 20260726000006). This migration finishes the roadmap item
-- by enforcing the three boolean features -- deposits, reports, marketplace
-- listing -- that until now were only gated client-side (PlanCaps / the More
-- screen). It is the backstop for a client that calls the API directly.
--
-- Model (mirrors lib/.../plan_caps.dart):
--   * Free trial            -> full access to everything.
--   * No package (legacy)   -> not blocked (the overall subscription-required
--                              gate handles lapsed accounts elsewhere).
--   * Side Hustle           -> deposits/reports/marketplace all OFF.
--   * Solo Pro / Squad / Empire -> all ON.
--
-- Data-driven: the flags live on subscription_packages so they stay
-- configurable. Additive + idempotent. ASCII only. Run manually.
-- ================================================================

-- 1. Feature flags on the catalog (null = allow, for legacy/unseeded rows) ----
ALTER TABLE public.subscription_packages
  ADD COLUMN IF NOT EXISTS deposits_enabled    BOOLEAN,
  ADD COLUMN IF NOT EXISTS reports_enabled     BOOLEAN,
  ADD COLUMN IF NOT EXISTS marketplace_enabled BOOLEAN;

UPDATE public.subscription_packages
   SET deposits_enabled = false, reports_enabled = false, marketplace_enabled = false
 WHERE name = 'Side Hustle';

UPDATE public.subscription_packages
   SET deposits_enabled = true, reports_enabled = true, marketplace_enabled = true
 WHERE name IN ('Solo Pro', 'Squad', 'Empire');

-- 2. Shared helper: does this business's plan allow a given feature? ----------
-- SECURITY DEFINER so triggers/RPCs can read businesses + subscription_packages
-- regardless of the caller's RLS. Returns TRUE on trial, no package, or an
-- unseeded flag so nothing is ever wrongly blocked.
CREATE OR REPLACE FUNCTION public.business_plan_allows(
  p_business_id UUID,
  p_feature     TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_status  TEXT;
  v_pkg     UUID;
  v_allowed BOOLEAN;
BEGIN
  SELECT b.subscription_status, b.subscription_package_id
    INTO v_status, v_pkg
  FROM public.businesses b
  WHERE b.id = p_business_id;

  IF NOT FOUND THEN RETURN true; END IF;      -- unknown business -> don't block
  IF v_status = 'trialing' THEN RETURN true; END IF;
  IF v_pkg IS NULL THEN RETURN true; END IF;  -- legacy / no package

  SELECT CASE p_feature
           WHEN 'deposits'    THEN deposits_enabled
           WHEN 'reports'     THEN reports_enabled
           WHEN 'marketplace' THEN marketplace_enabled
           ELSE NULL
         END
    INTO v_allowed
  FROM public.subscription_packages
  WHERE id = v_pkg;

  RETURN COALESCE(v_allowed, true);           -- unseeded flag -> allow
END;
$$;

-- 3. Deposits: block turning deposit_required on for a service --------------
CREATE OR REPLACE FUNCTION public.enforce_service_deposit_plan()
RETURNS trigger
LANGUAGE plpgsql SET search_path = public
AS $$
BEGIN
  IF NEW.deposit_required IS TRUE
     AND (TG_OP = 'INSERT' OR OLD.deposit_required IS DISTINCT FROM TRUE)
     AND NOT public.business_plan_allows(NEW.business_id, 'deposits') THEN
    RAISE EXCEPTION 'deposit_feature_unavailable'
      USING HINT = 'Upgrade your plan to require deposits.';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_service_deposit_plan ON public.services;
CREATE TRIGGER trg_enforce_service_deposit_plan
  BEFORE INSERT OR UPDATE ON public.services
  FOR EACH ROW EXECUTE FUNCTION public.enforce_service_deposit_plan();

-- 4. Deposits + marketplace: gate the business-level toggles ----------------
-- Only fires when a toggle is being turned ON (transition to true) so ordinary
-- edits to an already-published / deposit-on business never trip the check.
CREATE OR REPLACE FUNCTION public.enforce_business_feature_plan()
RETURNS trigger
LANGUAGE plpgsql SET search_path = public
AS $$
BEGIN
  IF NEW.is_published IS TRUE
     AND (TG_OP = 'INSERT' OR OLD.is_published IS DISTINCT FROM TRUE)
     AND NOT public.business_plan_allows(NEW.id, 'marketplace') THEN
    RAISE EXCEPTION 'marketplace_feature_unavailable'
      USING HINT = 'Upgrade your plan to list on the marketplace.';
  END IF;

  IF NEW.require_deposit_all_services IS TRUE
     AND (TG_OP = 'INSERT' OR OLD.require_deposit_all_services IS DISTINCT FROM TRUE)
     AND NOT public.business_plan_allows(NEW.id, 'deposits') THEN
    RAISE EXCEPTION 'deposit_feature_unavailable'
      USING HINT = 'Upgrade your plan to require deposits.';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_business_feature_plan ON public.businesses;
CREATE TRIGGER trg_enforce_business_feature_plan
  BEFORE INSERT OR UPDATE ON public.businesses
  FOR EACH ROW EXECUTE FUNCTION public.enforce_business_feature_plan();

-- 5. Reports: gate the two report RPCs on the plan --------------------------
-- Re-emitted verbatim from 20260711000003 / 20260726000005 with one added
-- plan check after the existing OWNER/ADMIN authorization.
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
  IF NOT public.business_plan_allows(p_business_id, 'reports') THEN
    RAISE EXCEPTION 'reports_feature_unavailable'
      USING HINT = 'Upgrade your plan to access reports.';
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
    'revenue_by_day', (
      SELECT COALESCE(jsonb_agg(jsonb_build_object('date', d, 'revenue', r) ORDER BY d), '[]'::jsonb)
      FROM (
        SELECT start_time::DATE AS d, SUM(price) AS r
        FROM range_appts
        WHERE status = 'completed'
        GROUP BY start_time::DATE
      ) daily_rev
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

CREATE OR REPLACE FUNCTION public.get_confirmation_waitlist_analytics(
  p_business_id UUID,
  p_start_date  DATE,
  p_end_date    DATE
)
RETURNS JSONB
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_required   INT;
  v_confirmed  INT;
  v_expired    INT;
  v_pending    INT;
  v_avg_min    NUMERIC;
  v_wl_total   INT;
  v_wl_notif   INT;
  v_wl_conv    INT;
  v_exp_cust   INT;
  v_rebooked   INT;
BEGIN
  IF public.get_my_business_role(p_business_id) NOT IN ('OWNER', 'ADMIN')
     AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'not authorized';
  END IF;
  IF NOT public.business_plan_allows(p_business_id, 'reports') THEN
    RAISE EXCEPTION 'reports_feature_unavailable'
      USING HINT = 'Upgrade your plan to access reports.';
  END IF;

  -- Confirmation metrics over bookings created in the range that required it.
  SELECT
    count(*) FILTER (WHERE confirmation_required),
    count(*) FILTER (WHERE confirmation_required AND confirmed_at IS NOT NULL),
    count(*) FILTER (WHERE cancellation_reason = 'confirmation_expired'),
    count(*) FILTER (WHERE confirmation_required AND status = 'pending_confirmation'),
    avg(EXTRACT(EPOCH FROM (confirmed_at - created_at)) / 60.0)
      FILTER (WHERE confirmation_required AND confirmed_at IS NOT NULL)
  INTO v_required, v_confirmed, v_expired, v_pending, v_avg_min
  FROM public.appointments
  WHERE business_id = p_business_id
    AND created_at::date BETWEEN p_start_date AND p_end_date;

  -- Waitlist metrics over entries created in the range.
  SELECT
    count(*),
    count(*) FILTER (WHERE notified_at IS NOT NULL),
    count(*) FILTER (WHERE notified_at IS NOT NULL AND status = 'booked')
  INTO v_wl_total, v_wl_notif, v_wl_conv
  FROM public.waitlist_entries
  WHERE business_id = p_business_id
    AND created_at::date BETWEEN p_start_date AND p_end_date;

  -- Rebook-after-expiry: distinct customers with an expired confirmation in the
  -- range, and how many of them later created another booking.
  WITH expired AS (
    SELECT customer_phone, min(updated_at) AS expired_at
    FROM public.appointments
    WHERE business_id = p_business_id
      AND cancellation_reason = 'confirmation_expired'
      AND created_at::date BETWEEN p_start_date AND p_end_date
      AND customer_phone IS NOT NULL
    GROUP BY customer_phone
  )
  SELECT
    count(*),
    count(*) FILTER (WHERE EXISTS (
      SELECT 1 FROM public.appointments a2
      WHERE a2.business_id = p_business_id
        AND a2.customer_phone = e.customer_phone
        AND a2.created_at > e.expired_at
    ))
  INTO v_exp_cust, v_rebooked
  FROM expired e;

  RETURN jsonb_build_object(
    'confirmation_required_total', COALESCE(v_required, 0),
    'confirmed_total',             COALESCE(v_confirmed, 0),
    'expired_total',               COALESCE(v_expired, 0),
    'pending_total',               COALESCE(v_pending, 0),
    'confirmation_rate',           CASE WHEN COALESCE(v_confirmed, 0) + COALESCE(v_expired, 0) = 0
                                        THEN NULL
                                        ELSE round(v_confirmed::numeric
                                             / (v_confirmed + v_expired), 4) END,
    'avg_confirmation_minutes',    CASE WHEN v_avg_min IS NULL THEN NULL
                                        ELSE round(v_avg_min, 1) END,
    'waitlist_total',              COALESCE(v_wl_total, 0),
    'waitlist_notified',           COALESCE(v_wl_notif, 0),
    'waitlist_converted',          COALESCE(v_wl_conv, 0),
    'waitlist_conversion_rate',    CASE WHEN COALESCE(v_wl_notif, 0) = 0 THEN NULL
                                        ELSE round(v_wl_conv::numeric / v_wl_notif, 4) END,
    'expired_customers',           COALESCE(v_exp_cust, 0),
    'rebooked_customers',          COALESCE(v_rebooked, 0),
    'rebook_rate',                 CASE WHEN COALESCE(v_exp_cust, 0) = 0 THEN NULL
                                        ELSE round(v_rebooked::numeric / v_exp_cust, 4) END
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_confirmation_waitlist_analytics(UUID, DATE, DATE)
  TO authenticated;
