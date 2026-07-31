-- ================================================================
-- Shorivo -- Region-based payment provider registry.
--
-- A configurable registry of payment providers (no hardcoding): each has
-- supported countries, a status, and its required config fields. A business's
-- country (businesses.country_code, defaulting to app_config
-- 'default_country_code' = 'BB' when unset) determines which providers are
-- configurable. Deposit readiness now also requires the configured provider to
-- be active AND supported in the business's country -- so changing country
-- auto-revalidates. Admin manages the registry (web) via save_payment_provider.
--
-- Additive + idempotent. ASCII only. Run manually.
-- ================================================================

INSERT INTO public.app_config (key, text_value) VALUES ('default_country_code', 'BB')
ON CONFLICT (key) DO NOTHING;

-- 1. Provider registry -------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.payment_providers (
  id                  TEXT PRIMARY KEY,   -- matches payment_profiles.provider
  name                TEXT NOT NULL,
  logo_asset          TEXT,               -- bundled asset path (or null)
  supported_countries TEXT[] NOT NULL DEFAULT '{}',  -- ISO 3166-1 alpha-2
  status              TEXT NOT NULL DEFAULT 'active'
    CHECK (status IN ('active', 'coming_soon', 'inactive')),
  required_fields     TEXT[] NOT NULL DEFAULT '{}',
  sort_order          INT NOT NULL DEFAULT 0,
  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.payment_providers ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "payment_providers_read" ON public.payment_providers;
CREATE POLICY "payment_providers_read" ON public.payment_providers
  FOR SELECT USING (true);  -- display-only; writes via save_payment_provider
GRANT SELECT ON public.payment_providers TO anon, authenticated;

INSERT INTO public.payment_providers
  (id, name, logo_asset, supported_countries, status, required_fields, sort_order)
VALUES
  ('firstpay', 'FirstPay', 'assets/branding/CIBC-Logo.png', ARRAY['BB'],
   'active', ARRAY['account_holder_name', 'account_number', 'email'], 1),
  ('wipay', 'WiPay', NULL, ARRAY['TT', 'JM', 'BB', 'GY'],
   'coming_soon', ARRAY['account_holder_name', 'account_number', 'email'], 2),
  ('stripe', 'Stripe', NULL, ARRAY['US', 'GB', 'CA', 'AU'],
   'active', ARRAY['account_holder_name', 'account_number', 'email'], 3),
  ('paypal', 'PayPal', NULL, ARRAY['US', 'GB', 'CA'],
   'coming_soon', ARRAY['email'], 4)
ON CONFLICT (id) DO NOTHING;

-- 2. Central region helpers --------------------------------------------------
-- The business's effective country (its own, else the platform default).
CREATE OR REPLACE FUNCTION public.business_country(p_business_id UUID)
RETURNS TEXT
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT COALESCE(
    (SELECT country_code FROM public.businesses WHERE id = p_business_id),
    (SELECT text_value FROM public.app_config WHERE key = 'default_country_code'),
    'BB'
  );
$$;

-- Is a provider configurable in a given country (active + supported)?
CREATE OR REPLACE FUNCTION public.provider_available_for_country(
  p_provider TEXT,
  p_country  TEXT
)
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.payment_providers
    WHERE id = p_provider AND status = 'active'
      AND p_country = ANY(supported_countries)
  );
$$;
GRANT EXECUTE ON FUNCTION public.provider_available_for_country(TEXT, TEXT) TO anon, authenticated;

-- 3. Region-aware deposit readiness -----------------------------------------
-- A ready profile only counts if its provider is active AND supported in the
-- business's country. So a country change that orphans the provider disables
-- deposits automatically (the saved profile is preserved).
CREATE OR REPLACE FUNCTION public.business_has_ready_payment_method(
  p_business_id UUID
)
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.payment_profiles pp
    JOIN public.payment_providers pv ON pv.id = pp.provider
    WHERE pp.business_id = p_business_id
      AND public.payment_profile_ready(pp.provider, pp.details)
      AND pv.status = 'active'
      AND public.business_country(p_business_id) = ANY(pv.supported_countries)
  );
$$;
GRANT EXECUTE ON FUNCTION public.business_has_ready_payment_method(UUID) TO authenticated;

-- 4. Provider is now registry-driven, not a hardcoded CHECK -----------------
ALTER TABLE public.payment_profiles DROP CONSTRAINT IF EXISTS payment_profiles_provider_check;

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
  -- Only a provider supported in this business's country is configurable.
  IF NOT public.provider_available_for_country(
       p_provider, public.business_country(p_business_id)) THEN
    RAISE EXCEPTION 'provider_not_available';
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

-- 5. Set the business country (OWNER/ADMIN) ---------------------------------
CREATE OR REPLACE FUNCTION public.set_business_country(
  p_business_id UUID,
  p_country     TEXT
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF public.get_my_business_role(p_business_id) NOT IN ('OWNER', 'ADMIN')
     AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  UPDATE public.businesses
     SET country_code = NULLIF(upper(btrim(COALESCE(p_country, ''))), ''),
         updated_at = now()
   WHERE id = p_business_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.set_business_country(UUID, TEXT) TO authenticated;

-- 6. Admin registry management (web admin) ----------------------------------
CREATE OR REPLACE FUNCTION public.save_payment_provider(
  p_id        TEXT,
  p_name      TEXT,
  p_logo      TEXT DEFAULT NULL,
  p_countries TEXT[] DEFAULT '{}',
  p_status    TEXT DEFAULT 'active',
  p_required  TEXT[] DEFAULT '{}',
  p_sort      INT DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_status NOT IN ('active', 'coming_soon', 'inactive') THEN
    RAISE EXCEPTION 'invalid status';
  END IF;
  INSERT INTO public.payment_providers(
    id, name, logo_asset, supported_countries, status, required_fields, sort_order, updated_at)
  VALUES (p_id, p_name, p_logo, COALESCE(p_countries, '{}'), p_status,
          COALESCE(p_required, '{}'), COALESCE(p_sort, 0), now())
  ON CONFLICT (id) DO UPDATE SET
    name = EXCLUDED.name,
    logo_asset = EXCLUDED.logo_asset,
    supported_countries = EXCLUDED.supported_countries,
    status = EXCLUDED.status,
    required_fields = EXCLUDED.required_fields,
    sort_order = EXCLUDED.sort_order,
    updated_at = now();
  RETURN jsonb_build_object('status', 'ok');
END;
$$;
GRANT EXECUTE ON FUNCTION public.save_payment_provider(TEXT, TEXT, TEXT, TEXT[], TEXT, TEXT[], INT)
  TO authenticated;
