-- ================================================================
-- BetterBooking — Business Self-Registration (mobile)
-- Additive only: no existing tables/columns/policies are altered
-- or dropped. Safe to run against the live project. Requires
-- 20260710000000_mobile_app_support.sql already applied.
--
-- Adds:
--   1. register_business(p_name, p_category) — SECURITY DEFINER RPC that
--      turns a signed-in entrepreneur account into a real business:
--      creates the businesses row + the OWNER business_members row
--      atomically, and generates a unique slug.
--
-- Why an RPC (same reasoning as mark_membership_active / the customer
-- booking RPCs in the earlier migrations): a brand-new user holds no
-- INSERT rights on businesses/business_members under the base RLS, and
-- the two inserts must happen together. A DEFINER function carries the
-- privilege, validates server-side, and stays idempotent so it can be
-- called safely on every login.
--
-- Two ways to call it, both supported:
--   • With explicit p_name / p_category — the in-app "Create your
--     business" form (CreateBusinessScreen), for a logged-in owner.
--   • With no args — the mobile business-register signup flow. This
--     project has email confirmation ON (auth.mailer_autoconfirm =
--     false), so there is NO session at signup; the register screen
--     stashes the details in signup metadata (pending_business_name /
--     _category) and the login hook drains them on first login.
-- ================================================================

-- Drop any earlier no-arg version so re-running this migration is clean.
DROP FUNCTION IF EXISTS public.register_business();

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
BEGIN
  v_uid := (SELECT auth.uid());
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'authentication required';
  END IF;

  -- Only entrepreneur-role accounts own businesses. Customers (role
  -- 'user') and anything else get a cheap no-op — this lets the client
  -- call register_business() unconditionally after every login.
  SELECT role INTO v_role FROM public.profiles WHERE id = v_uid;
  IF v_role IS DISTINCT FROM 'entrepreneur' THEN
    RETURN jsonb_build_object('status', 'not_entrepreneur');
  END IF;

  -- Idempotent: if this owner already has a business, do nothing. This
  -- is the primary safety guard (metadata is also cleared below, but this
  -- check stands even if that ever fails).
  SELECT b.id INTO v_existing_id
  FROM public.business_members m
  JOIN public.businesses b ON b.id = m.business_id
  WHERE m.user_id = v_uid AND m.role = 'OWNER'
  LIMIT 1;
  IF v_existing_id IS NOT NULL THEN
    RETURN jsonb_build_object('status', 'exists', 'business_id', v_existing_id);
  END IF;

  -- Prefer explicit args (in-app create form); fall back to the pending
  -- details captured at signup (mobile register flow).
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

  -- Slug: lowercased, non-alphanumerics collapsed to single dashes,
  -- trimmed, then suffixed -1, -2, ... until unique.
  v_base_slug := btrim(regexp_replace(lower(v_name), '[^a-z0-9]+', '-', 'g'), '-');
  IF v_base_slug = '' THEN
    v_base_slug := 'business';
  END IF;
  v_slug := v_base_slug;
  WHILE EXISTS (SELECT 1 FROM public.businesses WHERE slug = v_slug) LOOP
    v_suffix := v_suffix + 1;
    v_slug := v_base_slug || '-' || v_suffix;
  END LOOP;

  -- Create the business. Only the columns without a usable default are
  -- set; timezone/currency/status/booking flags/admin_status all take
  -- their table defaults so a mobile-created business matches a
  -- web-created one.
  INSERT INTO public.businesses (id, owner_id, name, slug, category)
  VALUES (gen_random_uuid(), v_uid, v_name, v_slug, v_category)
  RETURNING id INTO v_business_id;

  -- OWNER membership, ACTIVE immediately (no invite step for an owner).
  INSERT INTO public.business_members (id, business_id, user_id, role, status, created_at, updated_at)
  VALUES (gen_random_uuid(), v_business_id, v_uid, 'OWNER', 'ACTIVE', now(), now());

  -- Drain the pending metadata so a later login can't re-fire (belt-and-
  -- braces alongside the OWNER-membership check above).
  UPDATE auth.users
  SET raw_user_meta_data =
        (raw_user_meta_data - 'pending_business_name') - 'pending_business_category'
  WHERE id = v_uid;

  RETURN jsonb_build_object(
    'status', 'created',
    'business_id', v_business_id,
    'slug', v_slug
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.register_business(TEXT, TEXT) TO authenticated;
