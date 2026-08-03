-- ================================================================
-- Shorivo -- fix infinite recursion in the businesses SELECT policy.
--
-- SYMPTOM (blocks business-owner login):
--   ERROR 42P17: infinite recursion detected in policy for relation
--   "business_members"
--   ...raised whenever the app reads a membership with its embedded business:
--     from('business_members').select('id, role, status, businesses(*)')
--   getActiveMembership() then throws -> the app shows "create a business"
--   even though the user IS an ACTIVE OWNER of a business.
--
-- ROOT CAUSE (introduced by 20260801000001_rls_least_privilege.sql):
--   The businesses SELECT policy calls public.get_my_business_role(id), which
--   queries business_members. The business_members SELECT policy in turn
--   references businesses. So the two policies call into each other:
--     read business_members -> business_members policy -> businesses policy
--       -> get_my_business_role() -> read business_members -> ... (loop)
--   get_my_business_role() is NOT actually SECURITY DEFINER (the earlier
--   comment assumed it was), so it does not bypass RLS and the loop never ends.
--
-- FIX:
--   Check membership through a SECURITY DEFINER helper owned by the migration
--   role. Because it runs as its owner (which bypasses RLS on business_members),
--   evaluating the businesses policy never re-enters the business_members
--   policy -- the cycle is broken. Behaviour is otherwise identical to the
--   intended M1 tightening:
--     - guests/anon: only is_published = true
--     - owners:      their own business (published or not)
--     - members:     any business where they have an ACTIVE membership
--
-- Additive + idempotent. ASCII only. Run manually AND re-test (see bottom).
-- ================================================================

-- SECURITY DEFINER membership check -- bypasses business_members RLS so it can
-- be called from the businesses policy without recursing.
CREATE OR REPLACE FUNCTION public.mobile_can_read_business(p_business_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.business_members m
    WHERE m.business_id = p_business_id
      AND m.user_id = (SELECT auth.uid())
      AND m.status = 'ACTIVE'
  );
$$;

REVOKE ALL ON FUNCTION public.mobile_can_read_business(uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.mobile_can_read_business(uuid) TO anon, authenticated;

-- Recreate the businesses SELECT policy using the non-recursive helper.
DROP POLICY IF EXISTS businesses_public_read ON public.businesses;
CREATE POLICY businesses_public_read ON public.businesses
  FOR SELECT TO anon, authenticated
  USING (
    is_published = true
    OR owner_id = (SELECT auth.uid())
    OR public.mobile_can_read_business(id)
  );

-- ================================================================
-- VERIFY after running -- re-run the impersonation test; it must now return
-- ONE row (previously it errored with 42P17):
--
--   begin;
--   select set_config('request.jwt.claims',
--     json_build_object(
--       'sub', (select id::text from auth.users where lower(email)='mcdn2112@gmail.com'),
--       'role','authenticated'
--     )::text, true);
--   set local role authenticated;
--   select id, is_published, owner_id
--   from public.businesses
--   where id = '9b6ae5fc-4cd2-48fe-b7cf-1dfb0fb1697a';
--   rollback;
--
-- Then in the app: fully quit + relaunch, log in as the business owner --
-- it should now open the dashboard instead of "create a business".
--
-- ROLLBACK (only if something else breaks): restore the permissive read --
--   DROP POLICY IF EXISTS businesses_public_read ON public.businesses;
--   CREATE POLICY businesses_public_read ON public.businesses
--     FOR SELECT TO anon, authenticated USING (true);
-- ================================================================
