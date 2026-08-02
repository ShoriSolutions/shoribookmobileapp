-- ================================================================
-- Shorivo -- pricing update to match the website (shorivo.com/pricing).
--
-- Website lineup:
--   * Side Hustle  -> RETIRED (no longer offered; existing subscribers keep it)
--   * Solo Pro     -> founding price BBD 25/mo (was 30); now the ENTRY tier,
--                     highlighted (popular). Unlimited services, deposits,
--                     reports, marketplace, 1 staff.
--   * Squad        -> BBD 50/mo (unchanged). Up to 5 staff + per-staff.
--   * Empire (NEW) -> BBD 100/mo. Everything in Squad, plus multi-business
--                     management, consolidated billing, cross-business
--                     reporting, priority support.
--
-- IMPORTANT:
--   * price_amount here is the DISPLAY / fallback price only. The actual
--     charge + shown price come from the App Store / Play product. Update the
--     store products too (Solo Pro 30->25; create the Empire product).
--   * Empire's differentiators (multiple businesses, consolidated billing,
--     cross-business reporting) are WEB features -- the mobile app is
--     single-business, so in-app Empire access == Squad. max_staff is set to
--     5 to match "everything in Squad". Change if Empire should differ in-app.
--
-- Additive + idempotent. ASCII only. Run manually.
-- ================================================================

-- 1. Retire Side Hustle (hidden from the catalog; existing subs keep the row).
UPDATE public.subscription_packages
   SET is_active = false, updated_at = now()
 WHERE name = 'Side Hustle';

-- 2. Solo Pro -> founding price 25, entry tier, highlighted.
UPDATE public.subscription_packages
   SET price_amount = 25.00,
       is_popular   = true,
       is_active    = true,
       sort_order   = 1,
       updated_at   = now()
 WHERE name = 'Solo Pro';

-- 3. Squad -> second tier (price/caps unchanged).
UPDATE public.subscription_packages
   SET is_popular = false,
       sort_order = 2,
       updated_at = now()
 WHERE name = 'Squad';

-- 4. Empire -> new top tier (insert once, then keep mutable fields in sync).
INSERT INTO public.subscription_packages
  (name, tagline, features, price_amount, currency, billing_period,
   store_product_id_ios, store_product_id_android,
   is_popular, is_active, sort_order, max_services, max_staff)
SELECT
  'Empire',
  'For entrepreneurs running more than one business.',
  ARRAY['Everything in Squad, plus',
        'Manage multiple businesses from one account',
        'Consolidated billing across all businesses',
        'Cross-business reporting',
        'Priority support'],
  100.00, 'BBD', 'monthly',
  'com.shorisolutions.shoribook.empire.monthly',
  'com.shorisolutions.shoribook.empire.monthly',
  false, true, 3, NULL, 5
WHERE NOT EXISTS (
  SELECT 1 FROM public.subscription_packages WHERE name = 'Empire'
);

UPDATE public.subscription_packages
   SET tagline = 'For entrepreneurs running more than one business.',
       features = ARRAY['Everything in Squad, plus',
        'Manage multiple businesses from one account',
        'Consolidated billing across all businesses',
        'Cross-business reporting',
        'Priority support'],
       price_amount = 100.00,
       currency = 'BBD',
       billing_period = 'monthly',
       store_product_id_ios = 'com.shorisolutions.shoribook.empire.monthly',
       store_product_id_android = 'com.shorisolutions.shoribook.empire.monthly',
       is_popular = false,
       is_active = true,
       sort_order = 3,
       max_services = NULL,
       max_staff = 5,
       updated_at = now()
 WHERE name = 'Empire';
