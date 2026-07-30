-- ================================================================
-- Shorivo -- Customer Review System (Phase 1: data + submission).
--
-- NOTE: a `reviews` table already exists (web app) with:
--   id, business_id, appointment_id, rating, body, is_published,
--   customer_name, created_at   (no user_id, no status).
-- So this migration ADDS the moderation/reply columns to that table rather
-- than recreating it, keys authorship off the appointment (there is no
-- user_id), reuses the denormalized customer_name, and treats a review as
-- publicly visible when is_published AND status = 'published' -- so the web
-- app's is_published flag keeps working alongside mobile moderation.
--
-- Thresholds live in app_config so moderation can be tuned without an app
-- update. Additive + idempotent. ASCII only. Run manually.
-- ================================================================

-- 1. Configurable thresholds -------------------------------------------------
INSERT INTO public.app_config (key, num_value) VALUES
  ('review_low_rating_min_words', 75),
  ('review_min_for_evaluation', 20),
  ('review_nrr_warning', 0.30),
  ('review_nrr_investigation', 0.50),
  ('review_edit_window_hours', 24)
ON CONFLICT (key) DO NOTHING;

-- 2. Extend the existing reviews table --------------------------------------
ALTER TABLE public.reviews
  ADD COLUMN IF NOT EXISTS status            TEXT NOT NULL DEFAULT 'published',
  ADD COLUMN IF NOT EXISTS business_reply    TEXT,
  ADD COLUMN IF NOT EXISTS business_reply_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS is_flagged        BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS flag_reason       TEXT,
  ADD COLUMN IF NOT EXISTS edited_at         TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS updated_at        TIMESTAMPTZ NOT NULL DEFAULT now();

CREATE INDEX IF NOT EXISTS idx_reviews_business_created
  ON public.reviews(business_id, created_at DESC);

-- One review per appointment (guarded: ignore if a constraint or dup data
-- already exists -- submit_review also guards against duplicates).
DO $$
BEGIN
  ALTER TABLE public.reviews ADD CONSTRAINT reviews_appointment_unique UNIQUE (appointment_id);
EXCEPTION WHEN duplicate_table OR duplicate_object OR unique_violation THEN NULL;
END $$;

ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

-- Read: publicly-visible reviews are public; the author (via the appointment),
-- the business, and admins see the rest. (Additive to any web-app policy.)
DROP POLICY IF EXISTS "reviews_read_mobile" ON public.reviews;
CREATE POLICY "reviews_read_mobile" ON public.reviews
  FOR SELECT TO anon, authenticated
  USING (
    (is_published AND COALESCE(status, 'published') = 'published')
    OR public.get_my_business_role(business_id) IS NOT NULL
    OR public.is_admin()
    OR EXISTS (
      SELECT 1 FROM public.appointments a
      JOIN public.customers c ON c.id = a.customer_id
      WHERE a.id = reviews.appointment_id AND c.user_id = (SELECT auth.uid())
    )
  );
GRANT SELECT ON public.reviews TO anon, authenticated;

-- 3. Rating rollup on businesses --------------------------------------------
ALTER TABLE public.businesses
  ADD COLUMN IF NOT EXISTS rating_avg            NUMERIC NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS rating_count          INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS rating_negative_count INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS quality_status        TEXT;  -- set by Phase 3 evaluation

GRANT SELECT (rating_avg, rating_count) ON public.businesses TO anon;

-- Counts only publicly-visible reviews (published by the web flag AND not
-- moderated out).
CREATE OR REPLACE FUNCTION public.recalc_business_rating(p_business_id UUID)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_avg NUMERIC; v_count INT; v_neg INT;
BEGIN
  SELECT COALESCE(round(avg(rating), 2), 0), count(*),
         count(*) FILTER (WHERE rating <= 2)
    INTO v_avg, v_count, v_neg
    FROM public.reviews
   WHERE business_id = p_business_id
     AND is_published AND COALESCE(status, 'published') = 'published';
  UPDATE public.businesses
     SET rating_avg = v_avg, rating_count = v_count,
         rating_negative_count = v_neg
   WHERE id = p_business_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.reviews_rollup_sync()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  PERFORM public.recalc_business_rating(COALESCE(NEW.business_id, OLD.business_id));
  RETURN NULL;
END;
$$;
DROP TRIGGER IF EXISTS trg_reviews_rollup ON public.reviews;
CREATE TRIGGER trg_reviews_rollup
  AFTER INSERT OR UPDATE OR DELETE ON public.reviews
  FOR EACH ROW EXECUTE FUNCTION public.reviews_rollup_sync();

-- 4. Helpers -----------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.review_word_count(p_body TEXT)
RETURNS INT
LANGUAGE sql IMMUTABLE
AS $$
  SELECT CASE
    WHEN btrim(COALESCE(p_body, '')) = '' THEN 0
    ELSE array_length(regexp_split_to_array(btrim(p_body), E'\\s+'), 1)
  END;
$$;

CREATE OR REPLACE FUNCTION public.config_int(p_key TEXT, p_default INT)
RETURNS INT
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT COALESCE((SELECT num_value::int FROM public.app_config WHERE key = p_key), p_default);
$$;

-- Whether auth.uid() owns the appointment behind a review.
CREATE OR REPLACE FUNCTION public.owns_appointment(p_appointment_id UUID)
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.appointments a
    JOIN public.customers c ON c.id = a.customer_id
    WHERE a.id = p_appointment_id AND c.user_id = (SELECT auth.uid())
  );
$$;

-- 5. Submit / edit / reply / report ------------------------------------------
CREATE OR REPLACE FUNCTION public.submit_review(
  p_appointment_id UUID,
  p_rating         INT,
  p_body           TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_uid   UUID := (SELECT auth.uid());
  v_appt  RECORD;
  v_min   INT;
  v_owner UUID;
  v_id    UUID;
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

  INSERT INTO public.reviews(business_id, appointment_id, rating, body,
    is_published, status, customer_name)
  VALUES (v_appt.business_id, p_appointment_id, p_rating,
          NULLIF(btrim(COALESCE(p_body, '')), ''),
          true, 'published', v_appt.customer_name)
  RETURNING id INTO v_id;

  SELECT owner_id INTO v_owner FROM public.businesses WHERE id = v_appt.business_id;
  INSERT INTO public.reminder_queue(booking_id, business_id, user_id, channel, scheduled_for, kind, payload)
    VALUES (p_appointment_id, v_appt.business_id, v_owner, 'email', now(),
            'review_new', jsonb_build_object('rating', p_rating));

  RETURN jsonb_build_object('status', 'created', 'review_id', v_id);
END;
$$;
GRANT EXECUTE ON FUNCTION public.submit_review(UUID, INT, TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.edit_review(
  p_review_id UUID,
  p_rating    INT,
  p_body      TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_rev RECORD; v_min INT; v_win INT;
BEGIN
  IF (SELECT auth.uid()) IS NULL THEN RAISE EXCEPTION 'authentication required'; END IF;
  IF p_rating IS NULL OR p_rating < 1 OR p_rating > 5 THEN
    RAISE EXCEPTION 'rating must be 1-5';
  END IF;
  SELECT * INTO v_rev FROM public.reviews WHERE id = p_review_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'review not found'; END IF;
  IF NOT public.owns_appointment(v_rev.appointment_id) THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  v_win := public.config_int('review_edit_window_hours', 24);
  IF v_rev.created_at < now() - (v_win || ' hours')::interval THEN
    RETURN jsonb_build_object('status', 'window_closed');
  END IF;

  IF p_rating <= 2 THEN
    v_min := public.config_int('review_low_rating_min_words', 75);
    IF public.review_word_count(p_body) < v_min THEN
      RETURN jsonb_build_object('status', 'needs_detail', 'min_words', v_min);
    END IF;
  END IF;

  UPDATE public.reviews
     SET rating = p_rating, body = NULLIF(btrim(COALESCE(p_body, '')), ''),
         edited_at = now(), updated_at = now()
   WHERE id = p_review_id;
  RETURN jsonb_build_object('status', 'updated');
END;
$$;
GRANT EXECUTE ON FUNCTION public.edit_review(UUID, INT, TEXT) TO authenticated;

-- Business replies publicly to a review (OWNER/ADMIN). Cannot edit/delete it.
CREATE OR REPLACE FUNCTION public.reply_to_review(
  p_review_id UUID,
  p_reply     TEXT
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_rev RECORD;
BEGIN
  SELECT * INTO v_rev FROM public.reviews WHERE id = p_review_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'review not found'; END IF;
  IF public.get_my_business_role(v_rev.business_id) NOT IN ('OWNER', 'ADMIN')
     AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  UPDATE public.reviews
     SET business_reply = NULLIF(btrim(COALESCE(p_reply, '')), ''),
         business_reply_at = now(), updated_at = now()
   WHERE id = p_review_id;
  RETURN jsonb_build_object('status', 'replied');
END;
$$;
GRANT EXECUTE ON FUNCTION public.reply_to_review(UUID, TEXT) TO authenticated;

-- Customer reports their own review (via appointment ownership).
CREATE OR REPLACE FUNCTION public.report_own_review(p_review_id UUID)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_rev RECORD;
BEGIN
  SELECT * INTO v_rev FROM public.reviews WHERE id = p_review_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'review not found'; END IF;
  IF NOT public.owns_appointment(v_rev.appointment_id) THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  UPDATE public.reviews SET status = 'reported', updated_at = now()
   WHERE id = p_review_id;
  RETURN jsonb_build_object('status', 'reported');
END;
$$;
GRANT EXECUTE ON FUNCTION public.report_own_review(UUID) TO authenticated;

-- 6. Review request when an appointment is completed -------------------------
CREATE OR REPLACE FUNCTION public.appointments_review_request()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_uid UUID;
BEGIN
  IF TG_OP = 'UPDATE' AND NEW.status = 'completed'
     AND OLD.status IS DISTINCT FROM 'completed' THEN
    IF NOT EXISTS (SELECT 1 FROM public.reviews WHERE appointment_id = NEW.id)
       AND NOT EXISTS (
         SELECT 1 FROM public.reminder_queue
         WHERE booking_id = NEW.id AND kind = 'review_request') THEN
      SELECT user_id INTO v_uid FROM public.customers WHERE id = NEW.customer_id;
      INSERT INTO public.reminder_queue(booking_id, business_id, user_id, channel, scheduled_for, kind)
        VALUES (NEW.id, NEW.business_id, v_uid, 'email', now(), 'review_request');
    END IF;
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS trg_appointments_review_request ON public.appointments;
CREATE TRIGGER trg_appointments_review_request
  AFTER UPDATE ON public.appointments
  FOR EACH ROW EXECUTE FUNCTION public.appointments_review_request();
