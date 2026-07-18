-- ================================================================
-- ShoriBooks — subscription prices are stored in BBD ($10/$30/$50).
-- The app converts to the customer's currency for display based on the
-- country they pick; the store charges its own localized price at purchase.
-- (Ensures BBD base whether or not an earlier USD change was applied.)
-- ================================================================

ALTER TABLE public.subscription_packages ALTER COLUMN currency SET DEFAULT 'BBD';
UPDATE public.subscription_packages SET currency = 'BBD';
