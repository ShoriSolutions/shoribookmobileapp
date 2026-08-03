-- ================================================================
-- Shorivo -- revert the businesses SELECT policy to permissive.
--
-- WHY: the M1 tightening (20260801000001) and its follow-up fix
-- (20260803000000) both made the businesses SELECT policy check membership,
-- which reads business_members. The business_members policy references
-- businesses back, producing:
--   ERROR 42P17: infinite recursion detected in policy for relation
--   "business_members"
-- ...which blocked business-owner login (getActiveMembership threw, so the
-- app wrongly showed "create a business"). A SECURITY DEFINER helper did NOT
-- clear it (business_members likely has FORCE ROW LEVEL SECURITY and/or its
-- own policy recurses via get_my_business_role).
--
-- This restores the exact pre-break behaviour: businesses are readable (as
-- before 20260801000001). The profiles tightening from 20260801000001 is
-- intentionally KEPT -- it never recursed and closes a real PII read.
--
-- Trade-off: unpublished businesses' contact fields are readable again, as
-- they were before the audit change. Revisit later with a recursion-safe
-- design (e.g. split read into a published-only view for guests).
--
-- Additive + idempotent. ASCII only. Run manually.
-- ================================================================

DROP POLICY IF EXISTS businesses_public_read ON public.businesses;
CREATE POLICY businesses_public_read ON public.businesses
  FOR SELECT TO anon, authenticated
  USING (true);

-- The helper added by 20260803000000 is now unused by any policy; drop it so
-- it can't be mistaken for an active access path. Safe if it doesn't exist.
DROP FUNCTION IF EXISTS public.mobile_can_read_business(uuid);
