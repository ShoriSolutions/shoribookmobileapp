-- ================================================================
-- ShoriBooks — Subscriptions: a dynamic, web-manageable package catalog,
-- a 30-day trial, and store-IAP purchase recording. The mobile modal
-- reads the catalog live (nothing hardcoded), so pricing changes in the
-- DB reflect automatically. Subscriptions are per BUSINESS (the premium
-- features are all vendor-side).
-- ================================================================

-- ── Package catalog (managed via the web dashboard / SQL) ───────────────────
CREATE TABLE IF NOT EXISTS public.subscription_packages (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name                 TEXT NOT NULL,
  tagline              TEXT,                       -- short description
  features             TEXT[] NOT NULL DEFAULT '{}',
  price_amount         NUMERIC(10, 2),             -- display/fallback price
  currency             TEXT NOT NULL DEFAULT 'BBD',
  billing_period       TEXT NOT NULL DEFAULT 'monthly'
                         CHECK (billing_period IN ('monthly','annual','weekly','once','trial')),
  trial_days           INT NOT NULL DEFAULT 30,
  -- Store product identifiers — the app queries these for the real
  -- localized price and to start the purchase. Configure matching products
  -- in App Store Connect / Play Console.
  store_product_id_ios     TEXT,
  store_product_id_android TEXT,
  is_popular           BOOLEAN NOT NULL DEFAULT false,  -- "Most Popular" badge
  is_active            BOOLEAN NOT NULL DEFAULT true,
  sort_order           INT NOT NULL DEFAULT 0,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.subscription_packages ENABLE ROW LEVEL SECURITY;

-- Anyone signed in can read the active catalog; writes are admin/web/SQL
-- only (no write policy → service role or SQL editor).
DROP POLICY IF EXISTS "subscription_packages_read" ON public.subscription_packages;
CREATE POLICY "subscription_packages_read" ON public.subscription_packages
  FOR SELECT TO anon, authenticated
  USING (is_active = true);
GRANT SELECT ON public.subscription_packages TO anon, authenticated;

-- ── Subscription / trial state on the business ──────────────────────────────
ALTER TABLE public.businesses
  ADD COLUMN IF NOT EXISTS subscription_status TEXT NOT NULL DEFAULT 'none'
    CHECK (subscription_status IN ('none','trialing','trial_pending','active','past_due','canceled')),
  ADD COLUMN IF NOT EXISTS trial_started_at        TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS trial_ends_at           TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS trial_requires_review   BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS subscription_package_id UUID REFERENCES public.subscription_packages(id),
  ADD COLUMN IF NOT EXISTS subscription_period_end TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS subscription_store      TEXT,  -- 'apple' | 'google'
  ADD COLUMN IF NOT EXISTS subscription_token      TEXT;  -- for later server validation

-- ── Trial eligibility ───────────────────────────────────────────────────────
-- Returns { status: 'eligible' | 'pending' | 'ineligible', message, ... }.
--  • already subscribed / trial used  → ineligible
--  • flagged for manual review        → pending (show the review message)
--  • otherwise                        → eligible
CREATE OR REPLACE FUNCTION public.check_trial_eligibility(p_business_id UUID)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_biz RECORD;
BEGIN
  IF public.get_my_business_role(p_business_id) NOT IN ('OWNER','ADMIN') THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  SELECT subscription_status, trial_started_at, trial_ends_at, trial_requires_review
    INTO v_biz FROM public.businesses WHERE id = p_business_id;
  IF v_biz IS NULL THEN
    RETURN jsonb_build_object('status','ineligible','message','Business not found');
  END IF;
  IF v_biz.subscription_status = 'active' THEN
    RETURN jsonb_build_object('status','ineligible','message','You already have an active subscription.');
  END IF;
  IF v_biz.trial_started_at IS NOT NULL THEN
    RETURN jsonb_build_object('status','ineligible',
      'message','Your free trial has already been used.',
      'trial_ends_at', v_biz.trial_ends_at);
  END IF;
  IF v_biz.trial_requires_review THEN
    RETURN jsonb_build_object('status','pending',
      'message','Your trial request is under review. We''ll email you shortly.');
  END IF;
  RETURN jsonb_build_object('status','eligible','message','Eligible for a 30-day free trial.');
END;
$$;
GRANT EXECUTE ON FUNCTION public.check_trial_eligibility(UUID) TO authenticated;

-- ── Start the 30-day trial ──────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.start_trial(p_business_id UUID)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_elig JSONB; v_ends TIMESTAMPTZ;
BEGIN
  IF public.get_my_business_role(p_business_id) NOT IN ('OWNER','ADMIN') THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  v_elig := public.check_trial_eligibility(p_business_id);
  IF (v_elig ->> 'status') <> 'eligible' THEN
    RETURN v_elig;  -- pending / ineligible, unchanged
  END IF;
  v_ends := now() + INTERVAL '30 days';
  UPDATE public.businesses SET
    subscription_status = 'trialing',
    trial_started_at    = now(),
    trial_ends_at       = v_ends,
    updated_at          = now()
  WHERE id = p_business_id;
  RETURN jsonb_build_object('status','trialing','trial_ends_at', v_ends,
    'message','Your 30-day free trial is active.');
END;
$$;
GRANT EXECUTE ON FUNCTION public.start_trial(UUID) TO authenticated;

-- ── Record a store purchase (post-IAP) ──────────────────────────────────────
-- Called after the app completes an App Store / Play purchase. Grants the
-- entitlement and stores the token. NOTE: for production, receipt/token
-- verification should move to an Edge Function that validates with Apple /
-- Google before granting — this trusts the client for the MVP.
CREATE OR REPLACE FUNCTION public.record_subscription_purchase(
  p_business_id UUID,
  p_package_id  UUID,
  p_store       TEXT,
  p_token       TEXT,
  p_period_end  TIMESTAMPTZ
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF public.get_my_business_role(p_business_id) NOT IN ('OWNER','ADMIN') THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  UPDATE public.businesses SET
    subscription_status     = 'active',
    subscription_package_id = p_package_id,
    subscription_store      = p_store,
    subscription_token      = p_token,
    subscription_period_end = p_period_end,
    updated_at              = now()
  WHERE id = p_business_id;
  RETURN jsonb_build_object('status','active','period_end', p_period_end);
END;
$$;
GRANT EXECUTE ON FUNCTION public.record_subscription_purchase(UUID, UUID, TEXT, TEXT, TIMESTAMPTZ) TO authenticated;

-- ── Example packages (edit or replace via the web dashboard) ────────────────
-- Seeded only if the catalog is empty, so the modal has something to show.
-- Set real store_product_id_* values to match your App Store / Play products.
INSERT INTO public.subscription_packages
  (name, tagline, features, price_amount, currency, billing_period, is_popular, sort_order,
   store_product_id_ios, store_product_id_android)
SELECT * FROM (VALUES
  ('Side Hustle',
   'For part-timers who mostly need WhatsApp bookings to just work.',
   ARRAY['WhatsApp booking integration','Business profile & booking link',
         'Up to 5 services with prices & durations','Smart booking calendar',
         'Manual bookings from DMs, calls & walk-ins'],
   10.00::numeric, 'BBD', 'monthly', false, 1,
   'com.shorisolutions.shoribook.sidehustle.monthly',
   'com.shorisolutions.shoribook.sidehustle.monthly'),
  ('Solo Pro',
   'For full-timers whose whole week runs on bookings.',
   ARRAY['Everything in Side Hustle, plus','Unlimited services',
         'Deposits & no-show protection','Client database with history & notes',
         'QR code & social booking links','Marketplace listing',
         'Reports - bookings, revenue, top services'],
   30.00::numeric, 'BBD', 'monthly', true, 2,
   'com.shorisolutions.shoribook.solopro.monthly',
   'com.shorisolutions.shoribook.solopro.monthly'),
  ('Squad',
   'For shops and teams with staff to schedule.',
   ARRAY['Everything in Solo Pro, plus','Up to 5 staff members',
         'Per-staff schedules & availability','Clients can book a specific staff member',
         'Top-staff reporting'],
   50.00::numeric, 'BBD', 'monthly', false, 3,
   'com.shorisolutions.shoribook.squad.monthly',
   'com.shorisolutions.shoribook.squad.monthly')
) AS v(name, tagline, features, price_amount, currency, billing_period, is_popular, sort_order,
       store_product_id_ios, store_product_id_android)
WHERE NOT EXISTS (SELECT 1 FROM public.subscription_packages);

-- FUTURE (documented): coupons/promos and referral rewards as their own
-- tables applied at checkout; multi-currency via per-region price rows or
-- the store's localized pricing; upgrade/downgrade by swapping package_id.
