-- ================================================================
-- Shorivo -- REVERT the profiles SELECT lockdown from 20260721000008.
--
-- Locking profiles to owner-only broke marketplace browsing: a base-schema
-- businesses/marketplace RLS policy reads profiles, so hiding other users'
-- profile rows made that policy return no businesses. Restore the prior
-- public read to get browsing working again.
--
-- NOTE: this re-opens the pre-existing "profiles readable by everyone"
-- exposure (emails/names). That needs a proper fix that doesn't break the
-- businesses RLS dependency (e.g. a SECURITY DEFINER owner-status check, or
-- column-scoped access) -- tracked as a follow-up. Idempotent.
-- ================================================================

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
