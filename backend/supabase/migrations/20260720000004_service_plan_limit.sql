-- ================================================================
-- ShoriBooks -- per‑tier service limit (authoritative, server‑side).
-- Adds subscription_packages.max_services (null = unlimited) so caps are
-- data‑driven/configurable, seeds the current tiers, and enforces the
-- limit with a BEFORE INSERT trigger on services. During the free trial
-- (or with no cap) there is no limit — the trial grants full access.
-- The app also enforces this client‑side for UX; this is the backstop.
-- Additive + idempotent.
-- ================================================================

ALTER TABLE public.subscription_packages
  ADD COLUMN IF NOT EXISTS max_services int;  -- null = unlimited

-- Seed to match the app's PlanCaps (Side Hustle = 5; Solo Pro / Squad = ∞).
UPDATE public.subscription_packages SET max_services = 5   WHERE name = 'Side Hustle';
UPDATE public.subscription_packages SET max_services = NULL WHERE name IN ('Solo Pro', 'Squad');

CREATE OR REPLACE FUNCTION public.enforce_service_plan_limit()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_status text;
  v_max    int;
  v_count  int;
BEGIN
  SELECT b.subscription_status, p.max_services
    INTO v_status, v_max
  FROM public.businesses b
  LEFT JOIN public.subscription_packages p ON p.id = b.subscription_package_id
  WHERE b.id = NEW.business_id;

  -- Full access on trial, or no cap on this plan → allow.
  IF v_status = 'trialing' OR v_max IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.services WHERE business_id = NEW.business_id;

  IF v_count >= v_max THEN
    RAISE EXCEPTION 'service_limit_reached'
      USING HINT = 'Upgrade your plan to add more services.';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_service_plan_limit ON public.services;
CREATE TRIGGER trg_enforce_service_plan_limit
  BEFORE INSERT ON public.services
  FOR EACH ROW EXECUTE FUNCTION public.enforce_service_plan_limit();
