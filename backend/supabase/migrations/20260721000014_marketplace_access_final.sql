-- ================================================================
-- Shorivo -- FINAL consolidated marketplace-access fix.
--
-- Run this ONE migration to get browsing working for everyone. It's
-- idempotent and safe to run even if 000010/000012/000013 were partially
-- applied — it sets the correct end state:
--
--   1. profiles readable again (a base businesses policy depends on it, so
--      the lockdown left logged-in customers with 0 businesses).
--   2. Guests (anon role) get COLUMN-LEVEL read on the marketplace tables —
--      only safe columns, so business store tokens and staff email/phone are
--      never exposed to guests.
--   3. Public read policies (anon + authenticated) on the marketplace tables.
--
-- Sensitive columns are protected by GRANTing anon only the safe columns
-- (not GRANT-then-REVOKE, which a prior grant can defeat). The app already
-- selects exactly these columns. Additive + idempotent.
-- ================================================================

-- ── 1. Restore public profiles read (unbreaks authenticated browsing) ───────
DROP POLICY IF EXISTS profiles_select_own ON public.profiles;
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'profiles' AND cmd = 'SELECT'
  ) THEN
    CREATE POLICY profiles_select_public ON public.profiles
      FOR SELECT USING (true);
  END IF;
END $$;

-- ── 2. Column-safe anon grants (guests never see sensitive columns) ─────────
-- businesses: everything except subscription_token / subscription_store /
-- subscription_period_end.
REVOKE SELECT ON public.businesses FROM anon;
GRANT SELECT (
  id, owner_id, name, slug, category, description, logo_url, cover_image_url,
  phone, email, address, latitude, longitude, timezone, currency,
  whatsapp_number, google_maps_url, instagram_url, facebook_url, tiktok_url,
  booking_enabled, messaging_enabled, pre_booking_messaging_enabled,
  messaging_restrict_after_hours, is_published, is_marketplace_listed,
  featured_requested, buffer_minutes, max_bookings_per_day,
  max_bookings_per_hour, max_simultaneous_bookings, subscription_status,
  trial_ends_at, auto_renew, billing_period, current_period_end,
  subscription_package_id, country_code, name_category_locked_until, status,
  badges, gallery_urls, created_at, updated_at
) ON public.businesses TO anon;

-- staff_profiles: everything except email / phone.
REVOKE SELECT ON public.staff_profiles FROM anon;
GRANT SELECT (
  id, business_id, member_id, name, role, roles, bio, profile_image_url,
  instagram_url, is_active, is_bookable, display_order
) ON public.staff_profiles TO anon;

-- These have no sensitive columns — full read is fine.
GRANT SELECT ON public.services              TO anon;
GRANT SELECT ON public.business_hours        TO anon;
GRANT SELECT ON public.special_business_days TO anon;
GRANT SELECT ON public.staff_availability    TO anon;
GRANT SELECT ON public.staff_breaks          TO anon;
GRANT SELECT ON public.service_staff         TO anon;

-- ── 3. Public read policies (anon + authenticated), profiles-independent ─────
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'businesses','services','staff_profiles','business_hours',
    'special_business_days','staff_availability','staff_breaks','service_staff'
  ] LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', t || '_anon_read', t);
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I', t || '_public_read', t);
    EXECUTE format(
      'CREATE POLICY %I ON public.%I FOR SELECT TO anon, authenticated USING (true)',
      t || '_public_read', t);
  END LOOP;
END $$;
