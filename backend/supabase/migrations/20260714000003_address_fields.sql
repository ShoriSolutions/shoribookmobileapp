-- ================================================================
-- BetterBooking — Structured address + coordinates for customers and
-- vendors, plus a registration-time "pending address" drain and admin
-- registration analytics. Additive; reuses existing lat/lng on businesses.
-- ================================================================

-- ── Address columns ─────────────────────────────────────────────────────────
-- Customers (profiles) had no address at all.
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS country_code   TEXT,
  ADD COLUMN IF NOT EXISTS country_name   TEXT,
  ADD COLUMN IF NOT EXISTS admin_area     TEXT,  -- parish/state/province/region
  ADD COLUMN IF NOT EXISTS city           TEXT,
  ADD COLUMN IF NOT EXISTS postal_code    TEXT,
  ADD COLUMN IF NOT EXISTS street_address TEXT,
  ADD COLUMN IF NOT EXISTS latitude       DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS longitude      DOUBLE PRECISION;

-- Businesses already have address / latitude / longitude; add the
-- structured components so vendor discovery can filter by region.
ALTER TABLE public.businesses
  ADD COLUMN IF NOT EXISTS country_code TEXT,
  ADD COLUMN IF NOT EXISTS country_name TEXT,
  ADD COLUMN IF NOT EXISTS admin_area   TEXT,
  ADD COLUMN IF NOT EXISTS city         TEXT,
  ADD COLUMN IF NOT EXISTS postal_code  TEXT;

-- ── Customer self-service address save ──────────────────────────────────────
CREATE OR REPLACE FUNCTION public.save_my_address(
  p_country_code TEXT,
  p_country_name TEXT,
  p_admin_area   TEXT,
  p_city         TEXT,
  p_postal_code  TEXT,
  p_street       TEXT,
  p_lat          DOUBLE PRECISION,
  p_lng          DOUBLE PRECISION
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'authentication required';
  END IF;
  UPDATE public.profiles SET
    country_code   = NULLIF(btrim(COALESCE(p_country_code, '')), ''),
    country_name   = NULLIF(btrim(COALESCE(p_country_name, '')), ''),
    admin_area     = NULLIF(btrim(COALESCE(p_admin_area, '')), ''),
    city           = NULLIF(btrim(COALESCE(p_city, '')), ''),
    postal_code    = NULLIF(btrim(COALESCE(p_postal_code, '')), ''),
    street_address = NULLIF(btrim(COALESCE(p_street, '')), ''),
    latitude       = p_lat,
    longitude      = p_lng,
    updated_at     = now()
  WHERE id = v_uid;
END;
$$;
GRANT EXECUTE ON FUNCTION public.save_my_address(
  TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION
) TO authenticated;

-- ── Vendor business address save (OWNER/ADMIN) ──────────────────────────────
CREATE OR REPLACE FUNCTION public.save_business_address(
  p_business_id  UUID,
  p_country_code TEXT,
  p_country_name TEXT,
  p_admin_area   TEXT,
  p_city         TEXT,
  p_postal_code  TEXT,
  p_address      TEXT,
  p_lat          DOUBLE PRECISION,
  p_lng          DOUBLE PRECISION
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF public.get_my_business_role(p_business_id) NOT IN ('OWNER', 'ADMIN') THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  UPDATE public.businesses SET
    country_code = NULLIF(btrim(COALESCE(p_country_code, '')), ''),
    country_name = NULLIF(btrim(COALESCE(p_country_name, '')), ''),
    admin_area   = NULLIF(btrim(COALESCE(p_admin_area, '')), ''),
    city         = NULLIF(btrim(COALESCE(p_city, '')), ''),
    postal_code  = NULLIF(btrim(COALESCE(p_postal_code, '')), ''),
    address      = NULLIF(btrim(COALESCE(p_address, '')), ''),
    latitude     = p_lat,
    longitude    = p_lng,
    updated_at   = now()
  WHERE id = p_business_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.save_business_address(
  UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, DOUBLE PRECISION, DOUBLE PRECISION
) TO authenticated;

-- ── Registration-time address drain ─────────────────────────────────────────
-- A customer/vendor may enter their address during sign-up, before email
-- confirmation grants a session. Like register_business(), we stash it in
-- signup metadata ('pending_address') and drain it into the profile on the
-- first authenticated login. Idempotent and cheap — safe to call every login.
CREATE OR REPLACE FUNCTION public.drain_pending_address()
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_uid  UUID := auth.uid();
  v_addr JSONB;
BEGIN
  IF v_uid IS NULL THEN
    RETURN;
  END IF;
  SELECT raw_user_meta_data -> 'pending_address' INTO v_addr
    FROM auth.users WHERE id = v_uid;
  IF v_addr IS NULL OR jsonb_typeof(v_addr) <> 'object' THEN
    RETURN;
  END IF;

  UPDATE public.profiles SET
    country_code   = COALESCE(NULLIF(v_addr ->> 'country_code', ''), country_code),
    country_name   = COALESCE(NULLIF(v_addr ->> 'country_name', ''), country_name),
    admin_area     = COALESCE(NULLIF(v_addr ->> 'admin_area', ''), admin_area),
    city           = COALESCE(NULLIF(v_addr ->> 'city', ''), city),
    postal_code    = COALESCE(NULLIF(v_addr ->> 'postal_code', ''), postal_code),
    street_address = COALESCE(NULLIF(v_addr ->> 'street_address', ''), street_address),
    latitude       = COALESCE((NULLIF(v_addr ->> 'latitude', ''))::double precision, latitude),
    longitude      = COALESCE((NULLIF(v_addr ->> 'longitude', ''))::double precision, longitude),
    updated_at     = now()
  WHERE id = v_uid;

  -- Clear so a later login can't re-drain.
  UPDATE auth.users
    SET raw_user_meta_data = raw_user_meta_data - 'pending_address'
    WHERE id = v_uid;
END;
$$;
GRANT EXECUTE ON FUNCTION public.drain_pending_address() TO authenticated;

-- ── Admin registration analytics ────────────────────────────────────────────
-- Aggregated counts only — never individual addresses. Web-dashboard use
-- (mobile treats 'admin' as unsupported); guarded by is_admin().
CREATE OR REPLACE FUNCTION public.get_registration_analytics()
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN jsonb_build_object(
    'by_country', COALESCE((
      SELECT jsonb_agg(row_to_json(t))
      FROM (
        SELECT country_code, country_name, count(*) AS total
        FROM public.profiles
        WHERE country_code IS NOT NULL
        GROUP BY country_code, country_name
        ORDER BY total DESC
      ) t
    ), '[]'::jsonb),
    'by_region', COALESCE((
      SELECT jsonb_agg(row_to_json(t))
      FROM (
        SELECT country_code, admin_area, count(*) AS total
        FROM public.profiles
        WHERE admin_area IS NOT NULL
        GROUP BY country_code, admin_area
        ORDER BY total DESC
      ) t
    ), '[]'::jsonb),
    'by_role', COALESCE((
      SELECT jsonb_object_agg(role, total)
      FROM (
        SELECT role, count(*) AS total FROM public.profiles GROUP BY role
      ) r
    ), '{}'::jsonb)
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_registration_analytics() TO authenticated;

-- FUTURE / extension points (documented, not built here):
--  • Reuse save_business_address in the vendor profile editor's map picker.
--  • Multiple business locations / delivery / saved customer addresses:
--    promote these columns into their own addresses table keyed by owner.
--  • Regional tax / service-area rules: index businesses(country_code, admin_area).
