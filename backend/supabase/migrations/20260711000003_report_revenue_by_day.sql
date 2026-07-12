-- ================================================================
-- BetterBooking — Reports: per-day revenue for the trend line
-- Additive. Re-creates get_business_report_summary with an extra
-- 'revenue_by_day' key (daily completed-appointment revenue) so the
-- Reports screen can draw a revenue trend line. Everything else is
-- unchanged from 20260710000000_mobile_app_support.sql.
-- ================================================================

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
