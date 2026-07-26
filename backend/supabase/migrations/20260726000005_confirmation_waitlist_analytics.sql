-- ================================================================
-- Shorivo -- Confirmation + Waitlist analytics (Phase 3).
--
-- A single OWNER/ADMIN-only RPC that aggregates the confirmation-window and
-- waitlist metrics for a business over a date range (by created_at), for the
-- Reports screen:
--   * confirmation rate, expired count, average confirmation time
--   * waitlist total / notified / conversion rate
--   * rebook rate after an expired confirmation
--
-- Depends on Phase 1/2 columns. Additive + idempotent. ASCII only. Run manually.
-- ================================================================

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
