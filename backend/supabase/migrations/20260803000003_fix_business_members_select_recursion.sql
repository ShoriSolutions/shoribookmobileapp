-- ================================================================
-- Shorivo -- fix the self-recursive business_members SELECT policy.
--
-- SYMPTOM: ERROR 42P17: infinite recursion detected in policy for relation
-- "business_members" on every membership read -> business-owner login lands on
-- "No business yet / Create a business".
--
-- ROOT CAUSE (pre-existing, in the web app's policies -- NOT the audit
-- migrations): the SELECT policy bm_select_by_member decides read access with an
-- inline subquery that reads business_members itself:
--
--   USING ( EXISTS ( SELECT 1 FROM business_members bm
--                    WHERE bm.business_id = business_members.business_id
--                      AND bm.user_id = (SELECT auth.uid()) ) )
--
-- The subquery is subject to the very policy being evaluated, so the policy is
-- part of its own plan -> Postgres aborts with 42P17. (Flipping
-- get_my_business_role to DEFINER did not help because this policy does not use
-- it -- the recursion is inline.)
--
-- FIX: put the "is the caller a member of this business" test in a
-- SECURITY DEFINER helper. As DEFINER it runs with the owner's rights and
-- bypasses RLS inside its body, so evaluating the policy no longer re-enters the
-- policy. Access is unchanged: a user still sees members of any business they
-- belong to (the function still filters by auth.uid()).
--
-- NOTE: bm_delete_owner / bm_update_owner_admin / bm_insert_owner_or_admin have
-- the same self-reference and will recurse on staff writes; they are handled
-- separately (they do not block login). See docs / follow-up migration.
--
-- Idempotent. ASCII only. Run manually.
-- ================================================================

CREATE OR REPLACE FUNCTION public.bm_is_member(p_business_id uuid)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
STABLE
SET search_path = public, pg_temp
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.business_members bm
    WHERE bm.business_id = p_business_id
      AND bm.user_id = (SELECT auth.uid())
  );
$$;

REVOKE ALL ON FUNCTION public.bm_is_member(uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.bm_is_member(uuid) TO authenticated;

DROP POLICY IF EXISTS bm_select_by_member ON public.business_members;
CREATE POLICY bm_select_by_member ON public.business_members
  FOR SELECT TO authenticated
  USING (public.bm_is_member(business_id));

-- ================================================================
-- VERIFY: re-run the membership read under an authenticated JWT -- it must now
-- return the row(s) instead of 42P17:
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
-- ================================================================
