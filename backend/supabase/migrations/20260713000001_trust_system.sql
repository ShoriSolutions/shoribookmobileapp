-- ================================================================
-- BetterBooking — Customer Trust & No-Show Protection (MVP)
-- Additive. Extends the existing backend; does not refactor it.
--
-- All trust calculations live here (server-side). Flutter never writes
-- trust columns: a BEFORE UPDATE guard on profiles reverts any change to
-- trust columns unless a trust function has set the app.trust_write flag.
--
-- Compliance: trust uses ONLY booking behaviour (completed / no-show /
-- late-cancel) + admin actions. No device identifiers, advertising IDs,
-- fingerprinting, or location are used or stored for trust.
-- ================================================================

-- ── 1. Profile trust fields ─────────────────────────────────────────────────
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS trust_score      INT NOT NULL DEFAULT 100,
  ADD COLUMN IF NOT EXISTS no_show_count    INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS warning_count    INT NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS deposit_required BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS suspension_until TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS permanent_ban    BOOLEAN NOT NULL DEFAULT false,
  -- supporting field: how many suspensions so far (drives 7/30/90-day escalation)
  ADD COLUMN IF NOT EXISTS suspension_count INT NOT NULL DEFAULT 0;

-- ── 2. Trust events (audit history) ─────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.trust_events (
  id           UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  booking_id   UUID        REFERENCES public.appointments(id) ON DELETE SET NULL,
  event        TEXT        NOT NULL,
  score_change INT         NOT NULL DEFAULT 0,
  notes        TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_trust_events_user ON public.trust_events(user_id, created_at DESC);

ALTER TABLE public.trust_events ENABLE ROW LEVEL SECURITY;

-- ── 3. Admin helper ─────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles WHERE id = (SELECT auth.uid()) AND role = 'admin'
  );
$$;
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;

-- Customers read their own trust events; admins read all.
DROP POLICY IF EXISTS "trust_events_self_select" ON public.trust_events;
CREATE POLICY "trust_events_self_select" ON public.trust_events
  FOR SELECT TO authenticated
  USING (user_id = (SELECT auth.uid()) OR public.is_admin());
-- No INSERT/UPDATE/DELETE policies: only SECURITY DEFINER functions write.
GRANT SELECT ON public.trust_events TO authenticated;

-- ── 4. Guard: trust columns are server-only ─────────────────────────────────
-- A normal profile UPDATE (name/avatar) leaves trust columns untouched, so
-- this is a no-op for it. Any attempt to change trust columns from the client
-- is silently reverted unless a trust function set app.trust_write='on'.
CREATE OR REPLACE FUNCTION public.protect_trust_columns()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
  IF current_setting('app.trust_write', true) IS DISTINCT FROM 'on' THEN
    NEW.trust_score      := OLD.trust_score;
    NEW.no_show_count    := OLD.no_show_count;
    NEW.warning_count    := OLD.warning_count;
    NEW.deposit_required := OLD.deposit_required;
    NEW.suspension_until := OLD.suspension_until;
    NEW.permanent_ban    := OLD.permanent_ban;
    NEW.suspension_count := OLD.suspension_count;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_trust_columns ON public.profiles;
CREATE TRIGGER trg_protect_trust_columns
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.protect_trust_columns();

-- ── 5. Reputation label helper ──────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.trust_reputation(p_score INT)
RETURNS TEXT
LANGUAGE sql IMMUTABLE
AS $$
  SELECT CASE
    WHEN p_score >= 80 THEN 'Excellent'
    WHEN p_score >= 60 THEN 'Good'
    WHEN p_score >= 40 THEN 'Fair'
    WHEN p_score >= 20 THEN 'Poor'
    ELSE 'Restricted'
  END;
$$;

-- ── 6. Core: record a booking outcome and update trust ──────────────────────
-- outcome ∈ 'completed' | 'no_show' | 'late_cancellation' | 'early_cancellation'
-- Not granted to clients — called by the appointments trigger only.
CREATE OR REPLACE FUNCTION public.record_booking_outcome(
  p_user_id    UUID,
  p_booking_id UUID,
  p_outcome    TEXT
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_prof        RECORD;
  v_new_score   INT;
  v_change      INT := 0;
  v_last_event  TEXT;
  v_days        INT;
BEGIN
  SELECT trust_score, no_show_count, suspension_until, suspension_count
    INTO v_prof FROM public.profiles WHERE id = p_user_id;
  IF v_prof IS NULL THEN RETURN; END IF;

  PERFORM set_config('app.trust_write', 'on', true);

  IF p_outcome = 'completed' THEN
    v_change := 2;
    INSERT INTO public.trust_events(user_id, booking_id, event, score_change)
      VALUES (p_user_id, p_booking_id, 'Booking Completed', v_change);

  ELSIF p_outcome = 'late_cancellation' THEN
    v_change := -10;
    INSERT INTO public.trust_events(user_id, booking_id, event, score_change)
      VALUES (p_user_id, p_booking_id, 'Late Cancellation', v_change);

  ELSIF p_outcome = 'early_cancellation' THEN
    v_change := 0; -- within the allowed window: no penalty (fairness)
    INSERT INTO public.trust_events(user_id, booking_id, event, score_change)
      VALUES (p_user_id, p_booking_id, 'Early Cancellation', v_change);

  ELSIF p_outcome = 'no_show' THEN
    -- Was the previous booking outcome also a no-show? Check BEFORE recording
    -- this one so ordering is unambiguous.
    SELECT event INTO v_last_event
    FROM public.trust_events
    WHERE user_id = p_user_id
      AND event IN ('No Show', 'Booking Completed', 'Late Cancellation', 'Early Cancellation')
    ORDER BY created_at DESC LIMIT 1;

    v_change := -25;
    UPDATE public.profiles SET no_show_count = no_show_count + 1 WHERE id = p_user_id;
    INSERT INTO public.trust_events(user_id, booking_id, event, score_change)
      VALUES (p_user_id, p_booking_id, 'No Show', -25);

    IF v_last_event = 'No Show' THEN
      v_change := v_change - 15; -- second consecutive no-show
      INSERT INTO public.trust_events(user_id, booking_id, event, score_change, notes)
        VALUES (p_user_id, p_booking_id, 'Trust Score Adjusted', -15,
                'Second consecutive no-show');
    END IF;
  ELSE
    RETURN; -- unknown outcome
  END IF;

  -- Apply, clamped to [0,100].
  v_new_score := GREATEST(0, LEAST(100, v_prof.trust_score + v_change));
  UPDATE public.profiles SET trust_score = v_new_score WHERE id = p_user_id;

  -- Deposit band (40–59): auto-require; clear the auto-flag once recovered.
  IF v_new_score BETWEEN 40 AND 59 THEN
    UPDATE public.profiles SET deposit_required = true
      WHERE id = p_user_id AND deposit_required = false;
    INSERT INTO public.trust_events(user_id, booking_id, event, notes)
      SELECT p_user_id, p_booking_id, 'Deposit Required', 'Auto (trust 40–59)'
      WHERE NOT EXISTS (
        SELECT 1 FROM public.trust_events
        WHERE user_id = p_user_id AND event = 'Deposit Required'
        AND created_at > now() - interval '1 minute'
      );
  ELSIF v_new_score >= 60 THEN
    UPDATE public.profiles SET deposit_required = false WHERE id = p_user_id;
  END IF;

  -- Auto-suspend below 20 (escalating 7 / 30 / 90 days). Never a ban.
  IF v_new_score < 20
     AND (v_prof.suspension_until IS NULL OR v_prof.suspension_until < now()) THEN
    v_days := CASE v_prof.suspension_count + 1
                WHEN 1 THEN 7 WHEN 2 THEN 30 ELSE 90 END;
    UPDATE public.profiles
      SET suspension_until = now() + (v_days || ' days')::interval,
          suspension_count = suspension_count + 1
      WHERE id = p_user_id;
    INSERT INTO public.trust_events(user_id, booking_id, event, notes)
      VALUES (p_user_id, p_booking_id, 'Suspension Started', v_days || '-day suspension');
  END IF;
END;
$$;

-- ── 7. Trigger: booking status change → trust update ────────────────────────
-- Extends the existing booking flow rather than duplicating it. Only reacts
-- to transitions into completed/no_show/cancelled for account-linked customers.
CREATE OR REPLACE FUNCTION public.appointments_trust_on_status()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_uid UUID;
BEGIN
  IF NEW.status IS NOT DISTINCT FROM OLD.status THEN RETURN NEW; END IF;
  IF NEW.status NOT IN ('completed', 'no_show', 'cancelled') THEN RETURN NEW; END IF;

  SELECT user_id INTO v_uid FROM public.customers WHERE id = NEW.customer_id;
  IF v_uid IS NULL THEN RETURN NEW; END IF; -- walk-in / no account: not tracked

  IF NEW.status = 'completed' THEN
    PERFORM public.record_booking_outcome(v_uid, NEW.id, 'completed');
  ELSIF NEW.status = 'no_show' THEN
    PERFORM public.record_booking_outcome(v_uid, NEW.id, 'no_show');
  ELSIF NEW.status = 'cancelled' THEN
    -- No configurable window in the product yet; treat <24h before start as
    -- "late". FUTURE: read a per-business cancellation window here.
    IF NEW.start_time - now() < interval '24 hours' THEN
      PERFORM public.record_booking_outcome(v_uid, NEW.id, 'late_cancellation');
    ELSE
      PERFORM public.record_booking_outcome(v_uid, NEW.id, 'early_cancellation');
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_appointments_trust ON public.appointments;
CREATE TRIGGER trg_appointments_trust
  AFTER UPDATE OF status ON public.appointments
  FOR EACH ROW EXECUTE FUNCTION public.appointments_trust_on_status();

-- ── 8. Booking eligibility (server-side calculation) ────────────────────────
CREATE OR REPLACE FUNCTION public.check_booking_eligibility(
  p_user_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_uid    UUID;
  v_prof   RECORD;
  v_status TEXT;
BEGIN
  v_uid := COALESCE(p_user_id, (SELECT auth.uid()));
  IF v_uid IS NULL THEN RAISE EXCEPTION 'authentication required'; END IF;
  IF v_uid <> (SELECT auth.uid()) AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT trust_score, permanent_ban, suspension_until, deposit_required
    INTO v_prof FROM public.profiles WHERE id = v_uid;
  IF v_prof IS NULL THEN
    RETURN jsonb_build_object('status', 'ok', 'trust_score', 100);
  END IF;

  IF v_prof.permanent_ban THEN
    v_status := 'banned';
  ELSIF v_prof.suspension_until IS NOT NULL AND v_prof.suspension_until > now() THEN
    v_status := 'suspended';
  ELSIF v_prof.trust_score < 20 THEN
    v_status := 'suspended';
  ELSIF v_prof.trust_score < 40 THEN
    v_status := 'manual_approval';
  ELSIF v_prof.trust_score < 60 OR v_prof.deposit_required THEN
    v_status := 'deposit_required';
  ELSIF v_prof.trust_score < 80 THEN
    v_status := 'warn';
  ELSE
    v_status := 'ok';
  END IF;

  RETURN jsonb_build_object(
    'status', v_status,
    'trust_score', v_prof.trust_score,
    'reputation', public.trust_reputation(v_prof.trust_score),
    'suspension_until', v_prof.suspension_until,
    'deposit_required', v_prof.deposit_required
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.check_booking_eligibility(UUID) TO authenticated;

-- ── 9. Permanent-ban eligibility (admin review gate) ────────────────────────
CREATE OR REPLACE FUNCTION public.check_permanent_ban_eligibility(p_user_id UUID)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_prof RECORD; v_ok BOOLEAN;
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'forbidden'; END IF;
  SELECT trust_score, no_show_count, suspension_count, warning_count
    INTO v_prof FROM public.profiles WHERE id = p_user_id;
  v_ok := v_prof.trust_score < 10 AND v_prof.no_show_count >= 5
          AND v_prof.suspension_count >= 3 AND v_prof.warning_count >= 2;
  RETURN jsonb_build_object(
    'eligible', v_ok,
    'trust_score', v_prof.trust_score,
    'no_show_count', v_prof.no_show_count,
    'suspension_count', v_prof.suspension_count,
    'warning_count', v_prof.warning_count,
    'message', CASE WHEN v_ok THEN 'Customer is eligible for permanent review.'
                    ELSE 'Customer does not meet the permanent-ban criteria.' END
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.check_permanent_ban_eligibility(UUID) TO authenticated;

-- ── 10. Admin actions (each writes a trust_events audit row) ────────────────
-- One entry point keeps the web admin dashboard simple. Every branch checks
-- is_admin() and sets the trust-write guard.
CREATE OR REPLACE FUNCTION public.admin_trust_action(
  p_user_id UUID,
  p_action  TEXT,          -- see CASE below
  p_value   INT DEFAULT NULL,  -- days (suspend) or new score (adjust)
  p_notes   TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE v_prof RECORD; v_new INT;
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'forbidden'; END IF;
  PERFORM set_config('app.trust_write', 'on', true);
  SELECT * INTO v_prof FROM public.profiles WHERE id = p_user_id;
  IF v_prof IS NULL THEN RAISE EXCEPTION 'user not found'; END IF;

  IF p_action = 'issue_warning' THEN
    UPDATE public.profiles SET warning_count = warning_count + 1 WHERE id = p_user_id;
    INSERT INTO public.trust_events(user_id, event, notes) VALUES (p_user_id, 'Warning Issued', p_notes);

  ELSIF p_action = 'remove_warning' THEN
    UPDATE public.profiles SET warning_count = GREATEST(0, warning_count - 1) WHERE id = p_user_id;
    INSERT INTO public.trust_events(user_id, event, notes) VALUES (p_user_id, 'Admin Action', COALESCE(p_notes, 'Warning removed'));

  ELSIF p_action = 'require_deposit' THEN
    UPDATE public.profiles SET deposit_required = true WHERE id = p_user_id;
    INSERT INTO public.trust_events(user_id, event, notes) VALUES (p_user_id, 'Deposit Required', COALESCE(p_notes, 'Admin required deposit'));

  ELSIF p_action = 'remove_deposit' THEN
    UPDATE public.profiles SET deposit_required = false WHERE id = p_user_id;
    INSERT INTO public.trust_events(user_id, event, notes) VALUES (p_user_id, 'Admin Action', COALESCE(p_notes, 'Deposit requirement removed'));

  ELSIF p_action = 'suspend' THEN
    UPDATE public.profiles
      SET suspension_until = now() + (COALESCE(p_value, 7) || ' days')::interval,
          suspension_count = suspension_count + 1
      WHERE id = p_user_id;
    INSERT INTO public.trust_events(user_id, event, notes)
      VALUES (p_user_id, 'Suspension Started', COALESCE(p_notes, COALESCE(p_value, 7) || '-day suspension (admin)'));

  ELSIF p_action = 'lift_suspension' THEN
    UPDATE public.profiles SET suspension_until = NULL WHERE id = p_user_id;
    INSERT INTO public.trust_events(user_id, event, notes) VALUES (p_user_id, 'Suspension Removed', p_notes);

  ELSIF p_action = 'adjust_score' THEN
    v_new := GREATEST(0, LEAST(100, COALESCE(p_value, v_prof.trust_score)));
    UPDATE public.profiles SET trust_score = v_new WHERE id = p_user_id;
    INSERT INTO public.trust_events(user_id, event, score_change, notes)
      VALUES (p_user_id, 'Trust Score Adjusted', v_new - v_prof.trust_score, p_notes);

  ELSIF p_action = 'approve_appeal' THEN
    -- Fairness: restore trust after reviewing an appeal.
    v_new := GREATEST(0, LEAST(100, COALESCE(p_value, 80)));
    UPDATE public.profiles
      SET trust_score = v_new, suspension_until = NULL, deposit_required = false
      WHERE id = p_user_id;
    INSERT INTO public.trust_events(user_id, event, score_change, notes)
      VALUES (p_user_id, 'Appeal Approved', v_new - v_prof.trust_score, p_notes);

  ELSIF p_action = 'permanent_ban' THEN
    IF NOT (v_prof.trust_score < 10 AND v_prof.no_show_count >= 5
            AND v_prof.suspension_count >= 3 AND v_prof.warning_count >= 2) THEN
      RAISE EXCEPTION 'customer does not meet permanent-ban criteria';
    END IF;
    UPDATE public.profiles SET permanent_ban = true WHERE id = p_user_id;
    INSERT INTO public.trust_events(user_id, event, notes) VALUES (p_user_id, 'Admin Action', COALESCE(p_notes, 'Permanent ban'));

  ELSIF p_action = 'remove_permanent_ban' THEN
    UPDATE public.profiles SET permanent_ban = false WHERE id = p_user_id;
    INSERT INTO public.trust_events(user_id, event, notes) VALUES (p_user_id, 'Admin Action', COALESCE(p_notes, 'Permanent ban removed'));

  ELSE
    RAISE EXCEPTION 'unknown action: %', p_action;
  END IF;

  RETURN jsonb_build_object('status', 'ok', 'action', p_action);
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_trust_action(UUID, TEXT, INT, TEXT) TO authenticated;

-- FUTURE (post-MVP): more advanced fraud/reputation signals could be added as
-- additional trust_events + score rules here, and a decay job could slowly
-- restore trust for inactive-but-clean customers.
