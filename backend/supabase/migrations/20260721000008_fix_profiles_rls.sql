-- ================================================================
-- Shorivo -- SECURITY FIX: lock down profiles SELECT.
--
-- Audit finding: a broad SELECT policy on public.profiles (a leftover
-- "viewable by everyone"-style policy from the base schema) let ANY
-- authenticated user read every profile row -- including email + full_name.
-- With anonymous sign-ins enabled, "authenticated" now includes guests, so
-- this was effectively public. The app only ever reads a user's OWN profile
-- (profile_repository / trust_repository both filter by id = auth.uid()),
-- so scoping SELECT to the owner (plus admins) breaks nothing.
--
-- Drops every existing SELECT policy on profiles and replaces it with an
-- owner-only one. UPDATE/INSERT policies are left untouched. Idempotent.
-- ================================================================

DO $$
DECLARE
  p record;
BEGIN
  FOR p IN
    SELECT policyname
    FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'profiles' AND cmd = 'SELECT'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.profiles', p.policyname);
  END LOOP;
END $$;

DROP POLICY IF EXISTS profiles_select_own ON public.profiles;
CREATE POLICY profiles_select_own ON public.profiles
  FOR SELECT TO authenticated
  USING (id = (SELECT auth.uid()) OR public.is_admin());
