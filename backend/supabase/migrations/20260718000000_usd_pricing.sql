-- ================================================================
-- ShoriBooks — make USD the base/default currency for subscription
-- packages. Prices are stored in USD; the app converts to a chosen
-- country's currency for display, and the App Store / Play charge in
-- their own localized currency at purchase.
-- ================================================================

ALTER TABLE public.subscription_packages ALTER COLUMN currency SET DEFAULT 'USD';
UPDATE public.subscription_packages SET currency = 'USD';
