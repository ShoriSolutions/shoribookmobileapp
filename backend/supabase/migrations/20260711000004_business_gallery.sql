-- ================================================================
-- BetterBooking — Business photo gallery (mobile)
-- Additive. Adds businesses.gallery_urls (up to 10 public image URLs,
-- shown on the marketplace profile). Images are uploaded to the existing
-- public 'business-images' bucket under <business_id>/gallery/..., which
-- the storage policies from 20260711000001 already allow OWNER/ADMIN to
-- write. The 10-image cap is enforced in the app.
-- ================================================================

ALTER TABLE public.businesses
  ADD COLUMN IF NOT EXISTS gallery_urls TEXT[] NOT NULL DEFAULT '{}';
