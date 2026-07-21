-- ================================================================
-- ShoriBooks -- let a vendor set their business IANA time zone.
-- Small dedicated RPC (OWNER/ADMIN) so the large update_business_profile
-- function is left untouched. The value is an IANA identifier (e.g.
-- America/Barbados); the app converts DST automatically. Additive.
-- ================================================================

CREATE OR REPLACE FUNCTION public.set_business_timezone(
  p_business_id uuid,
  p_timezone    text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role text;
BEGIN
  SELECT role INTO v_role FROM public.business_members
  WHERE user_id = auth.uid() AND business_id = p_business_id AND status = 'ACTIVE';
  IF v_role IS DISTINCT FROM 'OWNER' AND v_role IS DISTINCT FROM 'ADMIN' THEN
    RAISE EXCEPTION 'not authorized';
  END IF;
  IF NULLIF(btrim(p_timezone), '') IS NULL THEN
    RAISE EXCEPTION 'timezone required';
  END IF;
  UPDATE public.businesses
  SET timezone = btrim(p_timezone), updated_at = now()
  WHERE id = p_business_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.set_business_timezone(uuid, text) TO authenticated;
