-- ================================================================
-- ShoriBooks -- configurable app settings + annual billing discount.
-- A small key/value config table so values like the annual-billing
-- discount can change without app or migration churn. Annual pricing is
-- derived dynamically as monthly x 12 x (1 - percent/100); nothing about
-- the discount is hardcoded in the app. Anon-readable (display only).
-- Extension point for future promos / coupons / referral configs.
-- ================================================================

CREATE TABLE IF NOT EXISTS public.app_config (
  key        text PRIMARY KEY,
  num_value  numeric,
  text_value text,
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS app_config_read ON public.app_config;
CREATE POLICY app_config_read ON public.app_config
  FOR SELECT USING (true);

-- Default annual discount: 20% off. Change this row anytime (10 / 15 / 20…)
-- and the app picks it up — no deploy needed.
INSERT INTO public.app_config (key, num_value)
VALUES ('annual_discount_percent', 20)
ON CONFLICT (key) DO NOTHING;
