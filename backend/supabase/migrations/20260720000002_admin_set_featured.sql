-- ================================================================
-- ShoriBooks -- admin approval for featured marketplace listings.
-- Vendors set businesses.featured_requested ("please feature us");
-- is_featured stays admin-only. This RPC lets the web admin dashboard
-- approve/deny a request and toggle is_featured. Admin-gated via
-- is_admin(). Additive + idempotent.
-- ================================================================

CREATE OR REPLACE FUNCTION public.admin_set_featured(
  p_business_id uuid,
  p_featured    boolean
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row public.businesses%ROWTYPE;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  UPDATE public.businesses
  SET is_featured = p_featured,
      -- Clear the pending request once acted on (approve or deny).
      featured_requested = false,
      updated_at = now()
  WHERE id = p_business_id
  RETURNING * INTO v_row;

  IF v_row.id IS NULL THEN
    RAISE EXCEPTION 'business not found';
  END IF;

  RETURN jsonb_build_object(
    'business_id', v_row.id,
    'is_featured', v_row.is_featured
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.admin_set_featured(uuid, boolean) TO authenticated;
