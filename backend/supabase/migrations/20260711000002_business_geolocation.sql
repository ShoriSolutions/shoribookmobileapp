-- ================================================================
-- BetterBooking — Business geolocation (mobile)
-- Additive. Requires 20260711000001_business_profile_editing.sql.
--
-- Adds businesses.latitude / longitude and extends update_business_profile
-- to save them, so customers can see the business location and get
-- directions. Public read of these coordinates is fine (they are the
-- shop's location, shown on the public listing).
-- ================================================================

ALTER TABLE public.businesses
  ADD COLUMN IF NOT EXISTS latitude  DOUBLE PRECISION,
  ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;

-- Replace the profile RPC with a version that also accepts coordinates.
DROP FUNCTION IF EXISTS public.update_business_profile(
  UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT,
  TEXT[], BOOLEAN
);

CREATE OR REPLACE FUNCTION public.update_business_profile(
  p_business_id        UUID,
  p_name               TEXT,
  p_category           TEXT,
  p_description        TEXT,
  p_phone              TEXT,
  p_email              TEXT,
  p_address            TEXT,
  p_whatsapp_number    TEXT,
  p_instagram_url      TEXT,
  p_facebook_url       TEXT,
  p_tiktok_url         TEXT,
  p_google_maps_url    TEXT,
  p_badges             TEXT[],
  p_featured_requested BOOLEAN,
  p_latitude           DOUBLE PRECISION DEFAULT NULL,
  p_longitude          DOUBLE PRECISION DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_role     TEXT;
  v_biz      RECORD;
  v_now      TIMESTAMPTZ := now();
  v_changed  BOOLEAN;
  v_new_lock TIMESTAMPTZ;
BEGIN
  v_role := public.get_my_business_role(p_business_id);
  IF v_role IS NULL OR v_role NOT IN ('OWNER', 'ADMIN') THEN
    RAISE EXCEPTION 'forbidden: only an owner or admin can edit the business';
  END IF;

  SELECT * INTO v_biz FROM public.businesses WHERE id = p_business_id;
  IF v_biz IS NULL THEN
    RAISE EXCEPTION 'business not found';
  END IF;

  v_changed :=
    (btrim(COALESCE(p_name, '')) <> '' AND p_name IS DISTINCT FROM v_biz.name)
    OR (p_category IS DISTINCT FROM v_biz.category);

  IF v_changed
     AND v_biz.name_category_locked_until IS NOT NULL
     AND v_now < v_biz.name_category_locked_until THEN
    RETURN jsonb_build_object(
      'status', 'locked',
      'locked_until', v_biz.name_category_locked_until
    );
  END IF;

  v_new_lock := CASE
    WHEN v_changed THEN v_now + INTERVAL '90 days'
    ELSE v_biz.name_category_locked_until
  END;

  UPDATE public.businesses SET
    name = CASE WHEN btrim(COALESCE(p_name, '')) <> '' THEN p_name ELSE name END,
    category = p_category,
    description = p_description,
    phone = p_phone,
    email = p_email,
    address = p_address,
    whatsapp_number = p_whatsapp_number,
    instagram_url = p_instagram_url,
    facebook_url = p_facebook_url,
    tiktok_url = p_tiktok_url,
    google_maps_url = p_google_maps_url,
    badges = COALESCE(p_badges, badges),
    featured_requested = COALESCE(p_featured_requested, featured_requested),
    latitude = p_latitude,
    longitude = p_longitude,
    name_category_locked_until = v_new_lock,
    updated_at = v_now
  WHERE id = p_business_id;

  RETURN jsonb_build_object('status', 'ok', 'locked_until', v_new_lock);
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_business_profile(
  UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT,
  TEXT[], BOOLEAN, DOUBLE PRECISION, DOUBLE PRECISION
) TO authenticated;
