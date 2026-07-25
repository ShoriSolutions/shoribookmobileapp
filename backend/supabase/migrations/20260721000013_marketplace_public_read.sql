-- ================================================================
-- Shorivo -- marketplace readable by guests AND logged-in users.
--
-- 000012 gave the anon (guest) role read access, but logged-in customers
-- (authenticated) still saw nothing: the base businesses policy reads the
-- profiles table, which is locked down, so it returned 0 rows. This makes
-- the public marketplace tables readable by BOTH anon and authenticated via
-- a simple policy that does NOT depend on profiles -- so browsing works
-- regardless of the profiles lockdown, and customer emails can stay private
-- (no need to revert 000008 / run 000010).
--
-- Only SELECT visibility of public listing data changes; write policies and
-- sensitive column REVOKEs (from 000012) are untouched. Additive + idempotent.
-- ================================================================

DROP POLICY IF EXISTS businesses_anon_read ON public.businesses;
DROP POLICY IF EXISTS businesses_public_read ON public.businesses;
CREATE POLICY businesses_public_read ON public.businesses
  FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS services_anon_read ON public.services;
DROP POLICY IF EXISTS services_public_read ON public.services;
CREATE POLICY services_public_read ON public.services
  FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS staff_profiles_anon_read ON public.staff_profiles;
DROP POLICY IF EXISTS staff_profiles_public_read ON public.staff_profiles;
CREATE POLICY staff_profiles_public_read ON public.staff_profiles
  FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS business_hours_anon_read ON public.business_hours;
DROP POLICY IF EXISTS business_hours_public_read ON public.business_hours;
CREATE POLICY business_hours_public_read ON public.business_hours
  FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS special_days_anon_read ON public.special_business_days;
DROP POLICY IF EXISTS special_days_public_read ON public.special_business_days;
CREATE POLICY special_days_public_read ON public.special_business_days
  FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS staff_availability_anon_read ON public.staff_availability;
DROP POLICY IF EXISTS staff_availability_public_read ON public.staff_availability;
CREATE POLICY staff_availability_public_read ON public.staff_availability
  FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS staff_breaks_anon_read ON public.staff_breaks;
DROP POLICY IF EXISTS staff_breaks_public_read ON public.staff_breaks;
CREATE POLICY staff_breaks_public_read ON public.staff_breaks
  FOR SELECT TO anon, authenticated USING (true);

DROP POLICY IF EXISTS service_staff_anon_read ON public.service_staff;
DROP POLICY IF EXISTS service_staff_public_read ON public.service_staff;
CREATE POLICY service_staff_public_read ON public.service_staff
  FOR SELECT TO anon, authenticated USING (true);
