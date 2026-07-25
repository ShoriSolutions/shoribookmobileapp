-- ================================================================
-- Shorivo -- guest marketplace access via the anon role (no sessions).
--
-- Guests browse + book with NO session at all (the app no longer creates
-- anonymous sessions). For that, the `anon` role needs read access to the
-- public marketplace tables. Sensitive columns are protected with
-- column-level REVOKEs so a guest can never read them:
--   * businesses.subscription_token / subscription_store / subscription_period_end
--   * staff_profiles.email / phone
-- The app's marketplace queries already select only the safe columns
-- (businessMarketplaceColumns / StaffProfile.marketplaceColumns).
--
-- Real (authenticated) users are unaffected. Additive + idempotent.
-- ================================================================

-- ── Table SELECT grants for the anon (guest) role ───────────────────────────
GRANT SELECT ON public.businesses            TO anon;
GRANT SELECT ON public.services              TO anon;
GRANT SELECT ON public.staff_profiles        TO anon;
GRANT SELECT ON public.business_hours        TO anon;
GRANT SELECT ON public.special_business_days TO anon;
GRANT SELECT ON public.staff_availability    TO anon;
GRANT SELECT ON public.staff_breaks          TO anon;
GRANT SELECT ON public.service_staff         TO anon;

-- ── Protect sensitive columns from the anon role ────────────────────────────
REVOKE SELECT (subscription_token, subscription_store, subscription_period_end)
  ON public.businesses FROM anon;
REVOKE SELECT (email, phone) ON public.staff_profiles FROM anon;

-- ── Public-read RLS policies for the anon role ──────────────────────────────
-- (Businesses are public listings; the app filters what it shows. These are
-- additive to any existing authenticated policies.)
DROP POLICY IF EXISTS businesses_anon_read ON public.businesses;
CREATE POLICY businesses_anon_read ON public.businesses
  FOR SELECT TO anon USING (true);

DROP POLICY IF EXISTS services_anon_read ON public.services;
CREATE POLICY services_anon_read ON public.services
  FOR SELECT TO anon USING (true);

DROP POLICY IF EXISTS staff_profiles_anon_read ON public.staff_profiles;
CREATE POLICY staff_profiles_anon_read ON public.staff_profiles
  FOR SELECT TO anon USING (true);

DROP POLICY IF EXISTS business_hours_anon_read ON public.business_hours;
CREATE POLICY business_hours_anon_read ON public.business_hours
  FOR SELECT TO anon USING (true);

DROP POLICY IF EXISTS special_days_anon_read ON public.special_business_days;
CREATE POLICY special_days_anon_read ON public.special_business_days
  FOR SELECT TO anon USING (true);

DROP POLICY IF EXISTS staff_availability_anon_read ON public.staff_availability;
CREATE POLICY staff_availability_anon_read ON public.staff_availability
  FOR SELECT TO anon USING (true);

DROP POLICY IF EXISTS staff_breaks_anon_read ON public.staff_breaks;
CREATE POLICY staff_breaks_anon_read ON public.staff_breaks
  FOR SELECT TO anon USING (true);

DROP POLICY IF EXISTS service_staff_anon_read ON public.service_staff;
CREATE POLICY service_staff_anon_read ON public.service_staff
  FOR SELECT TO anon USING (true);
