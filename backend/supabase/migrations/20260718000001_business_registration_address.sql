-- ================================================================
-- ShoriBooks — apply a business address captured during registration.
-- Business signup has no session (email confirmation), so the address is
-- stashed in signup metadata ('pending_business_address') and applied here
-- when register_business() creates the business on first login. Reproduces
-- register_business with the address step + drains the extra metadata key.
-- ================================================================

CREATE OR REPLACE FUNCTION public.register_business(
  p_name     TEXT DEFAULT NULL,
  p_category TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid          UUID;
  v_role         TEXT;
  v_meta         JSONB;
  v_name         TEXT;
  v_category     TEXT;
  v_existing_id  UUID;
  v_base_slug    TEXT;
  v_slug         TEXT;
  v_suffix       INT := 0;
  v_business_id  UUID;
  v_addr         JSONB;
BEGIN
  v_uid := (SELECT auth.uid());
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'authentication required';
  END IF;

  SELECT role INTO v_role FROM public.profiles WHERE id = v_uid;
  IF v_role IS DISTINCT FROM 'entrepreneur' THEN
    RETURN jsonb_build_object('status', 'not_entrepreneur');
  END IF;

  SELECT b.id INTO v_existing_id
  FROM public.business_members m
  JOIN public.businesses b ON b.id = m.business_id
  WHERE m.user_id = v_uid AND m.role = 'OWNER'
  LIMIT 1;
  IF v_existing_id IS NOT NULL THEN
    RETURN jsonb_build_object('status', 'exists', 'business_id', v_existing_id);
  END IF;

  SELECT raw_user_meta_data INTO v_meta FROM auth.users WHERE id = v_uid;
  v_name := COALESCE(
    NULLIF(btrim(COALESCE(p_name, '')), ''),
    NULLIF(btrim(COALESCE(v_meta ->> 'pending_business_name', '')), '')
  );
  v_category := COALESCE(
    NULLIF(btrim(COALESCE(p_category, '')), ''),
    NULLIF(btrim(COALESCE(v_meta ->> 'pending_business_category', '')), '')
  );
  IF v_name IS NULL THEN
    RETURN jsonb_build_object('status', 'no_pending_business');
  END IF;

  v_base_slug := btrim(regexp_replace(lower(v_name), '[^a-z0-9]+', '-', 'g'), '-');
  IF v_base_slug = '' THEN
    v_base_slug := 'business';
  END IF;
  v_slug := v_base_slug;
  WHILE EXISTS (SELECT 1 FROM public.businesses WHERE slug = v_slug) LOOP
    v_suffix := v_suffix + 1;
    v_slug := v_base_slug || '-' || v_suffix;
  END LOOP;

  INSERT INTO public.businesses (id, owner_id, name, slug, category)
  VALUES (gen_random_uuid(), v_uid, v_name, v_slug, v_category)
  RETURNING id INTO v_business_id;

  INSERT INTO public.business_members (id, business_id, user_id, role, status, created_at, updated_at)
  VALUES (gen_random_uuid(), v_business_id, v_uid, 'OWNER', 'ACTIVE', now(), now());

  -- Apply the address captured at signup, if any.
  v_addr := v_meta -> 'pending_business_address';
  IF v_addr IS NOT NULL AND jsonb_typeof(v_addr) = 'object' THEN
    UPDATE public.businesses SET
      country_code = NULLIF(btrim(COALESCE(v_addr ->> 'country_code', '')), ''),
      country_name = NULLIF(btrim(COALESCE(v_addr ->> 'country_name', '')), ''),
      admin_area   = NULLIF(btrim(COALESCE(v_addr ->> 'admin_area', '')), ''),
      city         = NULLIF(btrim(COALESCE(v_addr ->> 'city', '')), ''),
      postal_code  = NULLIF(btrim(COALESCE(v_addr ->> 'postal_code', '')), ''),
      address      = NULLIF(btrim(COALESCE(v_addr ->> 'address', '')), ''),
      latitude     = (NULLIF(v_addr ->> 'latitude', ''))::double precision,
      longitude    = (NULLIF(v_addr ->> 'longitude', ''))::double precision,
      updated_at   = now()
    WHERE id = v_business_id;
  END IF;

  -- Drain all pending signup metadata so a later login can't re-fire.
  UPDATE auth.users
  SET raw_user_meta_data =
        (((raw_user_meta_data - 'pending_business_name')
          - 'pending_business_category') - 'pending_business_address')
  WHERE id = v_uid;

  RETURN jsonb_build_object(
    'status', 'created',
    'business_id', v_business_id,
    'slug', v_slug
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.register_business(TEXT, TEXT) TO authenticated;
