-- ================================================================
-- Shorivo -- Payment profiles + deposit prerequisite (FirstPay).
--
-- A business must complete a payment profile (FirstPay) before it can require
-- deposits. Provider-agnostic: one row per (business, provider); provider
-- specifics live in `details` JSONB, with a per-provider readiness rule. Only
-- FirstPay is wired up now (WiPay / bank transfer / card are future).
--
-- Security: rows are readable/writable by the business OWNER/ADMIN only (RLS +
-- a SECURITY DEFINER save RPC). Account details are never exposed publicly.
-- Additive + idempotent. ASCII only. Run manually.
-- ================================================================

CREATE TABLE IF NOT EXISTS public.payment_profiles (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id          UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  provider             TEXT NOT NULL
    CHECK (provider IN ('firstpay', 'wipay', 'bank_transfer', 'card')),
  details              JSONB NOT NULL DEFAULT '{}'::jsonb,  -- provider-specific fields
  deposit_instructions TEXT,
  payment_notes        TEXT,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (business_id, provider)
);
ALTER TABLE public.payment_profiles ENABLE ROW LEVEL SECURITY;

-- Only the business OWNER/ADMIN (or an app admin) may read payment profiles;
-- writes go through save_payment_profile. Never exposed to anon / customers.
DROP POLICY IF EXISTS "payment_profiles_manage" ON public.payment_profiles;
CREATE POLICY "payment_profiles_manage" ON public.payment_profiles
  FOR SELECT TO authenticated
  USING (
    public.get_my_business_role(business_id) IN ('OWNER', 'ADMIN')
    OR public.is_admin()
  );
GRANT SELECT ON public.payment_profiles TO authenticated;

-- Per-provider readiness: are the required fields present? Only FirstPay is
-- supported for deposits today; other providers return false until built.
CREATE OR REPLACE FUNCTION public.payment_profile_ready(
  p_provider TEXT,
  p_details  JSONB
)
RETURNS BOOLEAN
LANGUAGE sql IMMUTABLE
AS $$
  SELECT CASE p_provider
    WHEN 'firstpay' THEN
      COALESCE(btrim(p_details->>'account_holder_name'), '') <> ''
      AND COALESCE(btrim(p_details->>'account_number'), '') <> ''
      AND COALESCE(btrim(p_details->>'email'), '') <> ''
    ELSE false
  END;
$$;

-- Does the business have at least one fully-configured payment method that can
-- back deposits? Used by the deposit trigger and readable by the app.
CREATE OR REPLACE FUNCTION public.business_has_ready_payment_method(
  p_business_id UUID
)
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.payment_profiles
    WHERE business_id = p_business_id
      AND public.payment_profile_ready(provider, details)
  );
$$;
GRANT EXECUTE ON FUNCTION public.business_has_ready_payment_method(UUID) TO authenticated;

-- Save (upsert) a payment profile. OWNER/ADMIN only. Returns the new status.
CREATE OR REPLACE FUNCTION public.save_payment_profile(
  p_business_id          UUID,
  p_provider             TEXT,
  p_details              JSONB,
  p_deposit_instructions TEXT DEFAULT NULL,
  p_payment_notes        TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_details JSONB := COALESCE(p_details, '{}'::jsonb);
BEGIN
  IF public.get_my_business_role(p_business_id) NOT IN ('OWNER', 'ADMIN')
     AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  IF p_provider NOT IN ('firstpay', 'wipay', 'bank_transfer', 'card') THEN
    RAISE EXCEPTION 'unknown payment provider';
  END IF;

  INSERT INTO public.payment_profiles(
    business_id, provider, details, deposit_instructions, payment_notes, updated_at)
  VALUES (p_business_id, p_provider, v_details,
          NULLIF(btrim(COALESCE(p_deposit_instructions, '')), ''),
          NULLIF(btrim(COALESCE(p_payment_notes, '')), ''),
          now())
  ON CONFLICT (business_id, provider) DO UPDATE SET
    details = EXCLUDED.details,
    deposit_instructions = EXCLUDED.deposit_instructions,
    payment_notes = EXCLUDED.payment_notes,
    updated_at = now();

  RETURN jsonb_build_object(
    'status',
    CASE WHEN public.payment_profile_ready(p_provider, v_details)
         THEN 'ready' ELSE 'setup_required' END);
END;
$$;
GRANT EXECUTE ON FUNCTION public.save_payment_profile(UUID, TEXT, JSONB, TEXT, TEXT)
  TO authenticated;

-- Enforce the prerequisite: a service can't be created with, or switched to,
-- deposit_required = true unless the business has a ready payment method.
-- (Turning a deposit OFF, or an unrelated edit, is always allowed.)
CREATE OR REPLACE FUNCTION public.enforce_deposit_requires_payment()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NEW.deposit_required IS TRUE
     AND (TG_OP = 'INSERT' OR OLD.deposit_required IS DISTINCT FROM TRUE) THEN
    IF NOT public.business_has_ready_payment_method(NEW.business_id) THEN
      RAISE EXCEPTION 'payment_setup_required'
        USING HINT = 'Complete your FirstPay setup before requiring deposits.';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enforce_deposit_requires_payment ON public.services;
CREATE TRIGGER trg_enforce_deposit_requires_payment
  BEFORE INSERT OR UPDATE ON public.services
  FOR EACH ROW EXECUTE FUNCTION public.enforce_deposit_requires_payment();
