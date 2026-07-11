-- ================================================================
-- BetterBooking — Business profile editing (mobile)
-- Additive only. Requires 20260711000000_business_self_registration.sql.
--
-- Adds:
--   1. businesses.name_category_locked_until — enforces a 90-day cooldown
--      on changing the business name or category.
--   2. businesses.featured_requested — owner-set "please feature us" flag
--      an admin reviews (admin approval / is_featured stays admin-only).
--   3. A public 'business-images' Storage bucket + policies so an
--      OWNER/ADMIN can upload their logo/cover (path = <business_id>/...).
--   4. update_business_profile(...) — SECURITY DEFINER RPC that updates
--      all editable profile fields and enforces the name/category lock
--      server-side (a plain UPDATE could bypass it).
-- ================================================================

ALTER TABLE public.businesses
  ADD COLUMN IF NOT EXISTS name_category_locked_until TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS featured_requested BOOLEAN NOT NULL DEFAULT false;

-- ── Storage bucket for logos / covers ───────────────────────────────────────

INSERT INTO storage.buckets (id, name, public)
VALUES ('business-images', 'business-images', true)
ON CONFLICT (id) DO NOTHING;

-- Public read (marketplace/profile images are public by nature).
DROP POLICY IF EXISTS "business_images_read" ON storage.objects;
CREATE POLICY "business_images_read" ON storage.objects
  FOR SELECT USING (bucket_id = 'business-images');

-- Owner/admin may write within their own business's folder. The first
-- path segment is the business id: e.g. "<business_id>/cover.jpg".
DROP POLICY IF EXISTS "business_images_insert" ON storage.objects;
CREATE POLICY "business_images_insert" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'business-images'
    AND public.get_my_business_role(((storage.foldername(name))[1])::uuid)
        IN ('OWNER', 'ADMIN')
  );

DROP POLICY IF EXISTS "business_images_update" ON storage.objects;
CREATE POLICY "business_images_update" ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id = 'business-images'
    AND public.get_my_business_role(((storage.foldername(name))[1])::uuid)
        IN ('OWNER', 'ADMIN')
  );

DROP POLICY IF EXISTS "business_images_delete" ON storage.objects;
CREATE POLICY "business_images_delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'business-images'
    AND public.get_my_business_role(((storage.foldername(name))[1])::uuid)
        IN ('OWNER', 'ADMIN')
  );

-- ── Profile update RPC (enforces the 90-day name/category lock) ──────────────

CREATE OR REPLACE FUNCTION public.update_business_profile(
  p_business_id       UUID,
  p_name              TEXT,
  p_category          TEXT,
  p_description       TEXT,
  p_phone             TEXT,
  p_email             TEXT,
  p_address           TEXT,
  p_whatsapp_number   TEXT,
  p_instagram_url     TEXT,
  p_facebook_url      TEXT,
  p_tiktok_url        TEXT,
  p_google_maps_url   TEXT,
  p_badges            TEXT[],
  p_featured_requested BOOLEAN
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

  -- Is the caller trying to change the name (non-blank) or the category?
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
    name_category_locked_until = v_new_lock,
    updated_at = v_now
  WHERE id = p_business_id;

  RETURN jsonb_build_object('status', 'ok', 'locked_until', v_new_lock);
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_business_profile(
  UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT,
  TEXT[], BOOLEAN
) TO authenticated;
