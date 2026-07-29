-- ================================================================
-- Shorivo -- per-tier staff limit (authoritative, server-side).
-- Mirrors the service limit (20260720000004): adds
-- subscription_packages.max_staff (null = unlimited), seeds the tiers, and
-- enforces the cap with a BEFORE INSERT trigger on staff_profiles. During the
-- free trial (or with no cap) there is no limit. The app already enforces this
-- client-side (PlanCaps) for UX; this is the backstop.
--
-- Counts ALL staff_profiles for the business (the staff list the app counts is
-- unfiltered), so the owner's own bookable profile counts toward the cap --
-- matching the "solo" tiers (1) and Squad (5). Additive + idempotent.
-- ================================================================

ALTER TABLE public.subscription_packages
  ADD COLUMN IF NOT EXISTS max_staff int;  -- null = unlimited

-- Seed to match the app's PlanCaps (Side Hustle / Solo Pro = 1; Squad = 5).
UPDATE public.subscription_packages SET max_staff = 1 WHERE name IN ('Side Hustle', 'Solo Pro');
UPDATE public.subscription_packages SET max_staff = 5 WHERE name = 'Squad';

CREATE OR REPLACE FUNCTION public.enforce_staff_plan_limit()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_status text;
  v_max    int;
  v_count  int;
BEGIN
  SELECT b.subscription_status, p.max_staff
    INTO v_status, v_max
  FROM public.businesses b
  LEFT JOIN public.subscription_packages p ON p.id = b.subscription_package_id
  WHERE b.id = NEW.business_id;

  -- Full access on trial, or no cap on this plan → allow.
  IF v_status = 'trialing' OR v_max IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT count(*) INTO v_count
  FROM public.staff_profiles WHERE business_id = NEW.business_id;

  IF v_count >= v_max THEN
    RAISE EXCEPTION 'staff_limit_reached'
      USING HINT = 'Upgrade your plan to add more staff.';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_staff_plan_limit ON public.staff_profiles;
CREATE TRIGGER trg_enforce_staff_plan_limit
  BEFORE INSERT ON public.staff_profiles
  FOR EACH ROW EXECUTE FUNCTION public.enforce_staff_plan_limit();
