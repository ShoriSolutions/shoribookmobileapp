-- ================================================================
-- Shorivo -- fix "Could not load this business" on the marketplace.
--
-- The business profile screen loads business + services + hours + staff
-- together, so one failing read breaks the whole page. Live, public reads of
-- staff_profiles were broken:
--
--   * anon (signed-out visitor): no SELECT grant at all -> HTTP 401
--     "permission denied for table staff_profiles" -> the page errors.
--   * signed-in customer: the only SELECT policy is member-only
--     (staff_profiles_member_select), so they got ZERO staff rows -- no error,
--     but an empty "choose a pro" step.
--
-- Cause: 20260721000012 granted anon SELECT, then 20260721000014 revoked it
-- and was supposed to re-grant only the safe columns and add a public read
-- policy -- but 000014 never ran here (its profiles policy isn't live either),
-- and 000013's staff_profiles_public_read policy is gone too. The revoke stuck
-- without the re-grant.
--
-- Fix: restore public read of staff_profiles with the SAME safety rules the
-- staff_profiles_public view already uses (000013): only active staff at
-- published, non-suspended businesses, and only non-sensitive columns --
-- email and phone are never granted to anon. Vendors keep full access to
-- their own staff through the existing member policy.
--
-- The business check goes through a SECURITY DEFINER helper (the pattern used
-- by bm_is_member) so the policy can't fail on anon's column-level grants for
-- businesses.admin_status, and can't recurse.
--
-- Idempotent. ASCII only.
-- ================================================================

BEGIN;

-- Is this business visible to the public marketplace right now?
CREATE OR REPLACE FUNCTION public.business_is_public(p_business_id uuid)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.businesses b
    WHERE b.id = p_business_id
      AND b.is_published
      AND (b.admin_status IS NULL
           OR b.admin_status <> ALL (ARRAY['SUSPENDED', 'INACTIVE']::admin_business_status[]))
  );
$$;
GRANT EXECUTE ON FUNCTION public.business_is_public(uuid) TO anon, authenticated;

-- Safe columns only: email / phone are deliberately NOT granted to anon.
-- (Matches StaffProfile.marketplaceColumns, which is what the app selects.)
GRANT SELECT (
  id, business_id, member_id, name, role, roles, bio, profile_image_url,
  instagram_url, is_active, is_bookable, display_order
) ON public.staff_profiles TO anon;

-- Public read: active staff of a publicly visible business. Vendors still see
-- all of their own staff via staff_profiles_member_select (policies are OR'd).
DROP POLICY IF EXISTS staff_profiles_public_read ON public.staff_profiles;
DROP POLICY IF EXISTS staff_profiles_anon_read   ON public.staff_profiles;
CREATE POLICY staff_profiles_public_read ON public.staff_profiles
  FOR SELECT TO anon, authenticated
  USING (is_active AND public.business_is_public(business_id));

COMMIT;
