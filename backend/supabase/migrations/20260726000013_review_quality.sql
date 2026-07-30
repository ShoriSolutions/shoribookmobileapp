-- ================================================================
-- Shorivo -- Review System Phase 3: quality monitoring + moderation + abuse.
--
-- Computes a Negative Review Ratio (NRR) once a business has enough reviews and
-- sets a quality_status (excellent / warning / under_review); crossing the
-- warning threshold notifies the business, crossing the investigation threshold
-- opens an admin moderation case. Businesses are NEVER auto-suspended -- only an
-- admin sets 'enforcement' (via record_moderation_action, used by the web
-- admin). New-account low-rating reviews are flagged out of public + metrics
-- for admin review. Additive + idempotent. ASCII only. Run manually.
-- ================================================================

INSERT INTO public.app_config (key, num_value) VALUES
  ('review_new_account_hours', 24)  -- accounts newer than this + a low rating = flagged
ON CONFLICT (key) DO NOTHING;

-- 1. Moderation case queue (admin) ------------------------------------------
CREATE TABLE IF NOT EXISTS public.business_review_cases (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id  UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  status       TEXT NOT NULL DEFAULT 'open',  -- open | dismissed | action_taken
  reason       TEXT,
  nrr          NUMERIC,
  rating_count INT,
  resolution   TEXT,
  opened_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  closed_at    TIMESTAMPTZ,
  closed_by    UUID
);
CREATE INDEX IF NOT EXISTS idx_review_cases_open
  ON public.business_review_cases(status, opened_at);
ALTER TABLE public.business_review_cases ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "review_cases_read" ON public.business_review_cases;
CREATE POLICY "review_cases_read" ON public.business_review_cases
  FOR SELECT TO authenticated
  USING (public.get_my_business_role(business_id) IS NOT NULL OR public.is_admin());
GRANT SELECT ON public.business_review_cases TO authenticated;

-- 2. Moderation audit log ----------------------------------------------------
CREATE TABLE IF NOT EXISTS public.business_moderation_log (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  case_id     UUID REFERENCES public.business_review_cases(id) ON DELETE SET NULL,
  action      TEXT NOT NULL,  -- advice|warning|request_improvements|hide|suspend|remove_suspension|dismiss|note
  notes       TEXT,
  actor_id    UUID,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.business_moderation_log ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "moderation_log_read" ON public.business_moderation_log;
CREATE POLICY "moderation_log_read" ON public.business_moderation_log
  FOR SELECT TO authenticated
  USING (public.get_my_business_role(business_id) IS NOT NULL OR public.is_admin());
GRANT SELECT ON public.business_moderation_log TO authenticated;

-- 3. Quality evaluation ------------------------------------------------------
CREATE OR REPLACE FUNCTION public.evaluate_business_quality(p_business_id UUID)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_min   INT;
  v_warn  NUMERIC;
  v_inv   NUMERIC;
  v_count INT;
  v_neg   INT;
  v_nrr   NUMERIC;
  v_old   TEXT;
  v_new   TEXT;
  v_owner UUID;
BEGIN
  SELECT rating_count, rating_negative_count, quality_status
    INTO v_count, v_neg, v_old
    FROM public.businesses WHERE id = p_business_id;

  -- Never overwrite an admin-applied enforcement.
  IF v_old = 'enforcement' THEN RETURN; END IF;

  v_min := public.config_int('review_min_for_evaluation', 20);
  IF v_count IS NULL OR v_count < v_min THEN
    IF v_old IS NOT NULL THEN
      UPDATE public.businesses SET quality_status = NULL WHERE id = p_business_id;
    END IF;
    RETURN;
  END IF;

  SELECT COALESCE(num_value, 0.30) INTO v_warn FROM public.app_config WHERE key = 'review_nrr_warning';
  SELECT COALESCE(num_value, 0.50) INTO v_inv  FROM public.app_config WHERE key = 'review_nrr_investigation';
  v_warn := COALESCE(v_warn, 0.30);
  v_inv  := COALESCE(v_inv, 0.50);
  v_nrr  := v_neg::numeric / v_count;

  v_new := CASE
    WHEN v_nrr >= v_inv  THEN 'under_review'
    WHEN v_nrr >= v_warn THEN 'warning'
    ELSE 'excellent'
  END;

  IF v_new IS NOT DISTINCT FROM v_old THEN RETURN; END IF;
  UPDATE public.businesses SET quality_status = v_new WHERE id = p_business_id;

  IF v_new IN ('warning', 'under_review') THEN
    SELECT owner_id INTO v_owner FROM public.businesses WHERE id = p_business_id;
    INSERT INTO public.reminder_queue(business_id, user_id, channel, scheduled_for, kind)
      VALUES (p_business_id, v_owner, 'email', now(), 'quality_warning');
  END IF;

  -- Investigation threshold: open an admin case (never auto-enforce).
  IF v_new = 'under_review'
     AND NOT EXISTS (
       SELECT 1 FROM public.business_review_cases
       WHERE business_id = p_business_id AND status = 'open') THEN
    INSERT INTO public.business_review_cases(business_id, reason, nrr, rating_count)
      VALUES (p_business_id, 'nrr_investigation', round(v_nrr, 4), v_count);
  END IF;
END;
$$;

-- Re-run the rollup + evaluation whenever reviews change.
CREATE OR REPLACE FUNCTION public.reviews_rollup_sync()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_biz UUID := COALESCE(NEW.business_id, OLD.business_id);
BEGIN
  PERFORM public.recalc_business_rating(v_biz);
  PERFORM public.evaluate_business_quality(v_biz);
  RETURN NULL;
END;
$$;

-- 4. Abuse flag on submit ----------------------------------------------------
-- A low rating from a very new account is flagged (kept out of public + the
-- rating rollup) for admin review. Returns a reason, or null.
CREATE OR REPLACE FUNCTION public.review_flag_reason(p_user_id UUID, p_rating INT)
RETURNS TEXT
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_created TIMESTAMPTZ; v_hours INT;
BEGIN
  IF p_rating > 2 THEN RETURN NULL; END IF;
  v_hours := public.config_int('review_new_account_hours', 24);
  SELECT created_at INTO v_created FROM auth.users WHERE id = p_user_id;
  IF v_created IS NOT NULL AND v_created > now() - (v_hours || ' hours')::interval THEN
    RETURN 'new_account_low_rating';
  END IF;
  RETURN NULL;
END;
$$;

-- Recreate submit_review to flag suspicious reviews. Matches the existing
-- reviews schema (no user_id; authorship via the appointment; is_published +
-- status govern visibility; denormalized customer_name).
CREATE OR REPLACE FUNCTION public.submit_review(
  p_appointment_id UUID,
  p_rating         INT,
  p_body           TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_uid    UUID := (SELECT auth.uid());
  v_appt   RECORD;
  v_min    INT;
  v_owner  UUID;
  v_id     UUID;
  v_flag   TEXT;
  v_status TEXT;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'authentication required'; END IF;
  IF p_rating IS NULL OR p_rating < 1 OR p_rating > 5 THEN
    RAISE EXCEPTION 'rating must be 1-5';
  END IF;

  SELECT a.id, a.business_id, a.status, a.customer_name, c.user_id AS cust_uid
    INTO v_appt
    FROM public.appointments a
    JOIN public.customers c ON c.id = a.customer_id
    WHERE a.id = p_appointment_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'appointment not found'; END IF;
  IF v_appt.cust_uid IS DISTINCT FROM v_uid THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF v_appt.status <> 'completed' THEN
    RETURN jsonb_build_object('status', 'not_completed');
  END IF;

  IF p_rating <= 2 THEN
    v_min := public.config_int('review_low_rating_min_words', 75);
    IF public.review_word_count(p_body) < v_min THEN
      RETURN jsonb_build_object('status', 'needs_detail', 'min_words', v_min);
    END IF;
  END IF;

  IF EXISTS (SELECT 1 FROM public.reviews WHERE appointment_id = p_appointment_id) THEN
    RETURN jsonb_build_object('status', 'already_reviewed');
  END IF;

  v_flag := public.review_flag_reason(v_uid, p_rating);
  v_status := CASE WHEN v_flag IS NULL THEN 'published' ELSE 'flagged' END;

  INSERT INTO public.reviews(business_id, appointment_id, rating, body,
    is_published, status, is_flagged, flag_reason, customer_name)
  VALUES (v_appt.business_id, p_appointment_id, p_rating,
          NULLIF(btrim(COALESCE(p_body, '')), ''),
          v_flag IS NULL, v_status, v_flag IS NOT NULL, v_flag,
          v_appt.customer_name)
  RETURNING id INTO v_id;

  -- Only alert the vendor about a live (published) review.
  IF v_status = 'published' THEN
    SELECT owner_id INTO v_owner FROM public.businesses WHERE id = v_appt.business_id;
    INSERT INTO public.reminder_queue(booking_id, business_id, user_id, channel, scheduled_for, kind, payload)
      VALUES (p_appointment_id, v_appt.business_id, v_owner, 'email', now(),
              'review_new', jsonb_build_object('rating', p_rating));
  END IF;

  RETURN jsonb_build_object('status', 'created', 'review_id', v_id,
    'flagged', v_status = 'flagged');
END;
$$;
GRANT EXECUTE ON FUNCTION public.submit_review(UUID, INT, TEXT) TO authenticated;

-- 5. Admin moderation action (web admin) ------------------------------------
-- Records the action in the audit log and applies the common state changes.
-- is_admin() only. Enforcement (suspend/hide) is applied ONLY here, never
-- automatically from ratings.
CREATE OR REPLACE FUNCTION public.record_moderation_action(
  p_business_id UUID,
  p_action      TEXT,
  p_case_id     UUID DEFAULT NULL,
  p_notes       TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_uid UUID := (SELECT auth.uid());
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'forbidden'; END IF;

  INSERT INTO public.business_moderation_log(business_id, case_id, action, notes, actor_id)
    VALUES (p_business_id, p_case_id, p_action, NULLIF(btrim(COALESCE(p_notes, '')), ''), v_uid);

  IF p_action IN ('suspend', 'hide') THEN
    UPDATE public.businesses
       SET quality_status = 'enforcement',
           is_published = CASE WHEN p_action = 'suspend' THEN false ELSE is_published END,
           is_marketplace_listed = false,
           updated_at = now()
     WHERE id = p_business_id;
  ELSIF p_action = 'remove_suspension' THEN
    UPDATE public.businesses
       SET quality_status = NULL, is_published = true, is_marketplace_listed = true,
           updated_at = now()
     WHERE id = p_business_id;
    PERFORM public.evaluate_business_quality(p_business_id);
  END IF;

  IF p_case_id IS NOT NULL THEN
    UPDATE public.business_review_cases
       SET status = CASE WHEN p_action = 'dismiss' THEN 'dismissed' ELSE 'action_taken' END,
           resolution = p_action, closed_at = now(), closed_by = v_uid
     WHERE id = p_case_id AND status = 'open';
  END IF;

  RETURN jsonb_build_object('status', 'ok');
END;
$$;
GRANT EXECUTE ON FUNCTION public.record_moderation_action(UUID, TEXT, UUID, TEXT)
  TO authenticated;

-- Admin removes a review that violates policy (web admin).
CREATE OR REPLACE FUNCTION public.admin_set_review_status(
  p_review_id UUID,
  p_status    TEXT
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'forbidden'; END IF;
  IF p_status NOT IN ('published', 'removed', 'flagged', 'hidden') THEN
    RAISE EXCEPTION 'invalid status';
  END IF;
  -- Keep is_published in sync so the web flag and mobile status agree.
  UPDATE public.reviews
     SET status = p_status, is_published = (p_status = 'published'),
         updated_at = now()
   WHERE id = p_review_id;  -- rollup + re-evaluation fire via the trigger
  RETURN jsonb_build_object('status', 'ok');
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_set_review_status(UUID, TEXT) TO authenticated;
