-- ================================================================
-- ShoriBooks — set the subscription catalog to the real pricing tiers
-- (Side Hustle / Solo Pro / Squad), matching the web pricing page.
-- Idempotent: clears the catalog and re-inserts. Prices stay editable in
-- the DB, so the mobile modal reflects any future change automatically.
-- ================================================================

-- Detach any business from a package first so the delete can't hit the FK.
UPDATE public.businesses SET subscription_package_id = NULL
  WHERE subscription_package_id IS NOT NULL;

DELETE FROM public.subscription_packages;

INSERT INTO public.subscription_packages
  (name, tagline, features, price_amount, currency, billing_period,
   is_popular, sort_order, store_product_id_ios, store_product_id_android)
VALUES
  ('Side Hustle',
   'For part-timers who mostly need WhatsApp bookings to just work.',
   ARRAY['WhatsApp booking integration',
         'Business profile & booking link',
         'Up to 5 services with prices & durations',
         'Smart booking calendar',
         'Manual bookings from DMs, calls & walk-ins'],
   10.00, 'USD', 'monthly', false, 1,
   'com.shorisolutions.shoribook.sidehustle.monthly',
   'com.shorisolutions.shoribook.sidehustle.monthly'),

  ('Solo Pro',
   'For full-timers whose whole week runs on bookings.',
   ARRAY['Everything in Side Hustle, plus',
         'Unlimited services',
         'Deposits & no-show protection',
         'Client database with history & notes',
         'QR code & social booking links',
         'Marketplace listing',
         'Reports - bookings, revenue, top services'],
   30.00, 'USD', 'monthly', true, 2,
   'com.shorisolutions.shoribook.solopro.monthly',
   'com.shorisolutions.shoribook.solopro.monthly'),

  ('Squad',
   'For shops and teams with staff to schedule.',
   ARRAY['Everything in Solo Pro, plus',
         'Up to 5 staff members',
         'Per-staff schedules & availability',
         'Clients can book a specific staff member',
         'Top-staff reporting'],
   50.00, 'USD', 'monthly', false, 3,
   'com.shorisolutions.shoribook.squad.monthly',
   'com.shorisolutions.shoribook.squad.monthly');
