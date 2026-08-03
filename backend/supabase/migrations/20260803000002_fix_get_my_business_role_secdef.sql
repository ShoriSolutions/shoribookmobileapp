-- ================================================================
-- Shorivo -- stop RLS recursion on business_members by making
-- get_my_business_role() run as SECURITY DEFINER.
--
-- SYMPTOM (blocks business-owner login even after reverting businesses RLS):
--   ERROR 42P17: infinite recursion detected in policy for relation
--   "business_members"
--   ...raised just by reading business_members (the app's getActiveMembership
--   read), so the app shows "No business yet / Create a business".
--
-- ROOT CAUSE:
--   The business_members SELECT policy calls public.get_my_business_role(),
--   which itself queries business_members. Because the function is
--   SECURITY INVOKER, its body is evaluated under the caller's RLS, so the
--   business_members policy calls into a function that re-reads
--   business_members -> the policy is part of its own plan -> recursion.
--   (Reverting the businesses policy did NOT help, which proves the loop is
--   inside business_members, not between businesses and business_members.)
--
-- FIX:
--   Flip get_my_business_role (all overloads) to SECURITY DEFINER with a
--   pinned search_path. As DEFINER it runs with the owner's rights and
--   bypasses RLS inside its body, so it becomes opaque to the planner and is
--   no longer part of the recursive plan. Access is unchanged: the function
--   still filters by auth.uid() internally, so a user only ever learns their
--   OWN role. This is the correct definition for an RLS helper and fixes every
--   policy that uses it (businesses and business_members) at once.
--
-- Signature-agnostic (handles any overloads). Idempotent. ASCII only. Run
-- manually.
-- ================================================================

DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT p.oid::regprocedure AS sig
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'get_my_business_role'
  LOOP
    EXECUTE format('ALTER FUNCTION %s SECURITY DEFINER', r.sig);
    EXECUTE format('ALTER FUNCTION %s SET search_path = public, pg_temp', r.sig);
    RAISE NOTICE 'Flipped % to SECURITY DEFINER', r.sig;
  END LOOP;
END $$;

-- ================================================================
-- VERIFY: re-run the membership read under an authenticated JWT -- it must now
-- return the row(s) instead of the 42P17 recursion error:
--
--   begin;
--   select set_config('request.jwt.claims',
--     json_build_object(
--       'sub', (select id::text from auth.users where lower(email)='mcdn2112@gmail.com'),
--       'role','authenticated'
--     )::text, true);
--   set local role authenticated;
--   select m.id, m.role, m.status, b.id, b.name, b.subscription_status
--   from public.business_members m
--   left join public.businesses b on b.id = m.business_id
--   where m.user_id = (select auth.uid()) and m.status = 'ACTIVE';
--   rollback;
--
-- If it STILL recurses, the business_members policy uses an INLINE self-query
-- (not get_my_business_role) and the policy itself must be rewritten -- capture
-- it with:
--   select policyname, cmd, qual from pg_policies
--   where schemaname='public' and tablename='business_members';
-- ================================================================
