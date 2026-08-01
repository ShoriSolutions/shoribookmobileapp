-- ================================================================
-- Shorivo -- least-privilege RLS tightening (audit H3 + M1).
--
-- Addresses two over-broad SELECT policies added by
-- 20260721000014_marketplace_access_final.sql:
--
--   H3: profiles was `USING (true)` -- any authenticated user could read every
--       user's full_name / email / phone (PII enumeration). The mobile app
--       only ever reads its OWN profile (profile_repository + trust_repository,
--       both `.eq('id', auth.uid())`), so own-row is sufficient. Admin/web use
--       the service role, which bypasses RLS.
--
--   M1: businesses was `USING (true)` -- anyone (incl. guests) could read ALL
--       businesses, including is_published=false ones, with their phone/email/
--       address. Marketplace browsing only needs PUBLISHED businesses; the
--       owner/members still need their own (published or not).
--
-- NOTE (M2, staff seeing all appointments/prices) is intentionally NOT changed
-- here: restricting appointment rows could break the staff calendar and is a
-- product decision -- see docs/RELEASE_AUDIT.md.
--
-- Additive + idempotent. ASCII only. Run manually AND TEST (see bottom).
-- ================================================================

-- ── H3: profiles -> own row only ────────────────────────────────────────────
-- (anon has no table grant anyway; this closes the authenticated PII read.)
DROP POLICY IF EXISTS profiles_select_public ON public.profiles;
DROP POLICY IF EXISTS profiles_select_own    ON public.profiles;
CREATE POLICY profiles_select_own ON public.profiles
  FOR SELECT
  USING (id = (SELECT auth.uid()));

-- ── M1: businesses -> published (or your own) only ──────────────────────────
-- get_my_business_role() is SECURITY DEFINER, so it is safe to call as anon.
DROP POLICY IF EXISTS businesses_public_read ON public.businesses;
DROP POLICY IF EXISTS businesses_anon_read   ON public.businesses;
CREATE POLICY businesses_public_read ON public.businesses
  FOR SELECT TO anon, authenticated
  USING (
    is_published = true
    OR owner_id = (SELECT auth.uid())
    OR public.get_my_business_role(id) IS NOT NULL
  );

-- ================================================================
-- VERIFY after running (both are important):
--
--   1. No OTHER permissive SELECT policy re-opens these tables. Run:
--        SELECT tablename, policyname, qual FROM pg_policies
--        WHERE schemaname='public' AND tablename IN ('profiles','businesses')
--          AND cmd='SELECT';
--      There should be exactly one SELECT policy per table (the ones above).
--
--   2. In the app: (a) guest can still browse the marketplace + open a
--      published business + book; (b) an owner can still open their OWN
--      (even unpublished) business; (c) login + profile screen still load.
--
-- ROLLBACK (if browsing/login breaks): recreate the permissive versions --
--   CREATE POLICY profiles_select_public ON public.profiles
--     FOR SELECT USING (true);
--   CREATE POLICY businesses_public_read ON public.businesses
--     FOR SELECT TO anon, authenticated USING (true);
-- ================================================================
