-- ================================================================
-- Shorivo -- fix guest-facing reviews read.
--
-- The reviews_read_mobile SELECT policy inlined a subquery over
-- appointments + customers to check authorship. RLS policy expressions run
-- as the CALLING role, and the anon (guest) role has no SELECT on
-- appointments/customers -- so for guests the whole SELECT raised
-- "permission denied for table appointments" instead of returning the
-- publicly-visible reviews. Result: guests browsing the marketplace could
-- see the star average (rating rollup) but the review LIST failed to load.
--
-- Fix: use the existing owns_appointment() helper, which is SECURITY DEFINER
-- and so evaluates the authorship check as the definer (no anon table grant
-- needed). Logic is otherwise identical.
--
-- Additive + idempotent. ASCII only. Run manually.
-- ================================================================

DROP POLICY IF EXISTS "reviews_read_mobile" ON public.reviews;
CREATE POLICY "reviews_read_mobile" ON public.reviews
  FOR SELECT TO anon, authenticated
  USING (
    (is_published AND COALESCE(status, 'published') = 'published')
    OR public.get_my_business_role(business_id) IS NOT NULL
    OR public.is_admin()
    OR public.owns_appointment(appointment_id)
  );
