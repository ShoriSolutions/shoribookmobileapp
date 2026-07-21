-- ================================================================
-- ShoriBooks -- annual in-app-purchase product ids per plan.
-- Alongside the existing monthly store product ids, each plan can carry a
-- separate annual (yearly) auto-renewable product id. Populate these with
-- the product ids you create in App Store Connect / Play Console for the
-- yearly tier, e.g. com.shorisolutions.shoribook.solopro.annual
-- Additive + idempotent; leave blank until the annual products exist.
-- ================================================================

ALTER TABLE public.subscription_packages
  ADD COLUMN IF NOT EXISTS store_product_id_ios_annual text,
  ADD COLUMN IF NOT EXISTS store_product_id_android_annual text;
