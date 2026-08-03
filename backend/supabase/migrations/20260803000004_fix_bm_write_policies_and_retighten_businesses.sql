-- ================================================================
-- Shorivo -- de-recurse the business_members WRITE policies and re-tighten
-- the businesses read policy (safe now that helpers are SECURITY DEFINER).
--
-- CONTEXT: 20260803000003 fixed the SELECT policy (login). The INSERT/UPDATE/
-- DELETE policies on business_members carry the same self-referential subquery
--   EXISTS (SELECT 1 FROM business_members bm WHERE ... AND bm.user_id = auth.uid() ...)
-- so any staff add/edit/remove would fail with 42P17. And 20260803000001 left
-- the businesses read wide open (USING(true)) as an emergency measure.
--
-- FIX: add a SECURITY DEFINER helper bm_has_role() that answers "does the
-- caller hold one of these roles in this business?" without re-entering RLS,
-- and rewrite each policy to use it. Access semantics are preserved verbatim
-- (see per-policy notes). Then restore the businesses M1 tightening using the
-- SECURITY DEFINER bm_is_member() from 20260803000003 -- it cannot recurse.
--
-- Idempotent. ASCII only. Run manually.
-- ================================================================

-- Caller-role check that bypasses RLS (no recursion).
CREATE OR REPLACE FUNCTION public.bm_has_role(p_business_id uuid, p_roles business_role[])
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
      AND bm.role = ANY (p_roles)
  );
$$;

REVOKE ALL ON FUNCTION public.bm_has_role(uuid, business_role[]) FROM public;
GRANT EXECUTE ON FUNCTION public.bm_has_role(uuid, business_role[]) TO authenticated;

-- DELETE: an OWNER may remove members other than themselves.
DROP POLICY IF EXISTS bm_delete_owner ON public.business_members;
CREATE POLICY bm_delete_owner ON public.business_members
  FOR DELETE TO authenticated
  USING (
    user_id <> (SELECT auth.uid())
    AND public.bm_has_role(business_id, ARRAY['OWNER']::business_role[])
  );

-- UPDATE: an OWNER/ADMIN may edit non-owner rows; may not set a role to OWNER.
DROP POLICY IF EXISTS bm_update_owner_admin ON public.business_members;
CREATE POLICY bm_update_owner_admin ON public.business_members
  FOR UPDATE TO authenticated
  USING (
    role <> 'OWNER'::business_role
    AND public.bm_has_role(business_id, ARRAY['OWNER','ADMIN']::business_role[])
  )
  WITH CHECK (
    role <> 'OWNER'::business_role
  );

-- INSERT: (a) register yourself as OWNER of a business you own, OR
--         (b) you are already an OWNER/ADMIN of the business (adding staff).
DROP POLICY IF EXISTS bm_insert_owner_or_admin ON public.business_members;
CREATE POLICY bm_insert_owner_or_admin ON public.business_members
  FOR INSERT TO authenticated
  WITH CHECK (
    (
      user_id = (SELECT auth.uid())
      AND role = 'OWNER'::business_role
      AND EXISTS (
        SELECT 1 FROM public.businesses b
        WHERE b.id = business_members.business_id
          AND b.owner_id = (SELECT auth.uid())
      )
    )
    OR public.bm_has_role(business_id, ARRAY['OWNER','ADMIN']::business_role[])
  );

-- Re-tighten businesses read (undo the emergency USING(true) from ...0001).
-- bm_is_member() is SECURITY DEFINER, so this cannot recurse.
--   guests/anon -> published only; owners -> own; members -> their business.
DROP POLICY IF EXISTS businesses_public_read ON public.businesses;
CREATE POLICY businesses_public_read ON public.businesses
  FOR SELECT TO anon, authenticated
  USING (
    is_published = true
    OR owner_id = (SELECT auth.uid())
    OR public.bm_is_member(id)
  );

-- ================================================================
-- VERIFY in the app after running:
--   1. Owner still reaches the dashboard (login unaffected).
--   2. Guest can still browse the marketplace (published businesses) + book.
--   3. Add / edit / remove a staff member works (no 42P17).
-- ================================================================
