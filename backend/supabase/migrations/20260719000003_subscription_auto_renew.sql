-- ================================================================
-- ShoriBooks -- auto-renew + billing period on the business subscription.
--
-- Vendor-facing controls: whether the subscription auto-renews, and on
-- which cadence. NOTE: the actual charge on renewal is performed by the
-- app store (auto-renewable IAP) or a payment-processor Edge Function --
-- this migration only stores the vendor's preference + the period end so
-- the app can display billing dates and gate features gracefully. Trial-
-- ending reminders (7/3/1 day) are sent by the process-reminders function.
-- Additive + idempotent.
-- ================================================================

ALTER TABLE public.businesses
  ADD COLUMN IF NOT EXISTS auto_renew boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS billing_period text NOT NULL DEFAULT 'monthly'
    CHECK (billing_period IN ('monthly', 'yearly')),
  ADD COLUMN IF NOT EXISTS current_period_end timestamptz;

-- OWNER/ADMIN can set their subscription's auto-renew + billing period.
CREATE OR REPLACE FUNCTION public.set_subscription_prefs(
  p_business_id    uuid,
  p_auto_renew     boolean DEFAULT NULL,
  p_billing_period text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid  uuid := auth.uid();
  v_role text;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'authentication required';
  END IF;
  SELECT role INTO v_role FROM public.business_members
  WHERE user_id = v_uid AND business_id = p_business_id AND status = 'ACTIVE';
  IF v_role IS DISTINCT FROM 'OWNER' AND v_role IS DISTINCT FROM 'ADMIN' THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  UPDATE public.businesses
  SET auto_renew     = COALESCE(p_auto_renew, auto_renew),
      billing_period = COALESCE(
        NULLIF(btrim(COALESCE(p_billing_period, '')), ''), billing_period),
      updated_at     = now()
  WHERE id = p_business_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.set_subscription_prefs(uuid, boolean, text)
  TO authenticated;
