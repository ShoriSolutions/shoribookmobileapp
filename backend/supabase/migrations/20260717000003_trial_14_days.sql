-- ================================================================
-- ShoriBooks — reduce the free trial from 30 days to 14 days.
-- Updates the package default, existing rows, and the trial RPCs.
-- ================================================================

ALTER TABLE public.subscription_packages ALTER COLUMN trial_days SET DEFAULT 14;
UPDATE public.subscription_packages SET trial_days = 14 WHERE trial_days = 30;

-- Eligibility message → 14 days.
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
  RETURN jsonb_build_object('status','eligible','message','Eligible for a 14-day free trial.');
END;
$$;
GRANT EXECUTE ON FUNCTION public.check_trial_eligibility(UUID) TO authenticated;

-- Start the 14-day trial.
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
    RETURN v_elig;
  END IF;
  v_ends := now() + INTERVAL '14 days';
  UPDATE public.businesses SET
    subscription_status = 'trialing',
    trial_started_at    = now(),
    trial_ends_at       = v_ends,
    updated_at          = now()
  WHERE id = p_business_id;
  RETURN jsonb_build_object('status','trialing','trial_ends_at', v_ends,
    'message','Your 14-day free trial is active.');
END;
$$;
GRANT EXECUTE ON FUNCTION public.start_trial(UUID) TO authenticated;
