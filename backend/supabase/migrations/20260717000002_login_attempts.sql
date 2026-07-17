-- ================================================================
-- ShoriBooks — login attempt limit (5) + owner security alert.
-- Failed logins are counted per email (server-side). After 5 within a
-- 15-minute window the account is locked for 15 minutes and — if the email
-- belongs to a real account — a "was this you?" alert is queued for an Edge
-- Function to email. A correct login clears the counter.
--
-- Note: the lock is checked by the app before it calls Supabase Auth; it is
-- an app-level guard (Supabase's own rate limits still apply to direct API
-- hits). The short window + owner alert is the standard mitigation for the
-- account-lockout tradeoff.
-- ================================================================

CREATE TABLE IF NOT EXISTS public.login_attempts (
  email        TEXT PRIMARY KEY,
  count        INT NOT NULL DEFAULT 0,
  window_start TIMESTAMPTZ NOT NULL DEFAULT now(),
  locked_until TIMESTAMPTZ,
  alerted_at   TIMESTAMPTZ,
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.login_attempts ENABLE ROW LEVEL SECURITY;
-- No policies: only the SECURITY DEFINER functions below touch it.

-- Queue of security alerts to email (drained by an Edge Function using the
-- service role). Never client-readable.
CREATE TABLE IF NOT EXISTS public.security_alerts (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID,
  email      TEXT NOT NULL,
  kind       TEXT NOT NULL DEFAULT 'login_limit',
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  sent_at    TIMESTAMPTZ
);
ALTER TABLE public.security_alerts ENABLE ROW LEVEL SECURITY;

-- Is this email currently locked out?
CREATE OR REPLACE FUNCTION public.check_login_lock(p_email TEXT)
RETURNS JSONB
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT jsonb_build_object(
    'locked', COALESCE(locked_until > now(), false),
    'locked_until', locked_until
  )
  FROM public.login_attempts
  WHERE email = lower(btrim(p_email));
$$;
GRANT EXECUTE ON FUNCTION public.check_login_lock(TEXT) TO anon, authenticated;

-- Record a failed attempt; lock + queue an alert on the 5th within the window.
CREATE OR REPLACE FUNCTION public.record_failed_login(p_email TEXT)
RETURNS JSONB
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_email  TEXT := lower(btrim(p_email));
  v_rec    public.login_attempts%ROWTYPE;
  v_count  INT;
  v_locked BOOLEAN := false;
  v_uid    UUID;
  v_fresh  BOOLEAN;
BEGIN
  IF v_email = '' THEN
    RETURN jsonb_build_object('locked', false, 'remaining', 5);
  END IF;

  SELECT * INTO v_rec FROM public.login_attempts WHERE email = v_email;
  v_fresh := v_rec.email IS NULL
             OR v_rec.window_start < now() - INTERVAL '15 minutes';

  IF v_fresh THEN
    v_count := 1;
    INSERT INTO public.login_attempts(email, count, window_start, updated_at)
      VALUES (v_email, 1, now(), now())
    ON CONFLICT (email) DO UPDATE SET
      count = 1, window_start = now(),
      locked_until = NULL, alerted_at = NULL, updated_at = now();
  ELSE
    v_count := v_rec.count + 1;
    UPDATE public.login_attempts
      SET count = v_count, updated_at = now()
      WHERE email = v_email;
  END IF;

  IF v_count >= 5 THEN
    v_locked := true;
    UPDATE public.login_attempts
      SET locked_until = now() + INTERVAL '15 minutes', updated_at = now()
      WHERE email = v_email;

    -- Alert the owner once per window, only if the email is a real account.
    IF v_fresh OR v_rec.alerted_at IS NULL THEN
      SELECT id INTO v_uid FROM auth.users
        WHERE lower(email) = v_email LIMIT 1;
      IF v_uid IS NOT NULL THEN
        INSERT INTO public.security_alerts(user_id, email, kind)
          VALUES (v_uid, v_email, 'login_limit');
        UPDATE public.login_attempts SET alerted_at = now() WHERE email = v_email;
      END IF;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'locked', v_locked,
    'remaining', GREATEST(0, 5 - v_count),
    'locked_until',
      (SELECT locked_until FROM public.login_attempts WHERE email = v_email)
  );
END;
$$;
GRANT EXECUTE ON FUNCTION public.record_failed_login(TEXT) TO anon, authenticated;

-- Clear the counter after a successful login.
CREATE OR REPLACE FUNCTION public.reset_login_attempts(p_email TEXT)
RETURNS VOID
LANGUAGE sql SECURITY DEFINER SET search_path = public
AS $$
  DELETE FROM public.login_attempts WHERE email = lower(btrim(p_email));
$$;
GRANT EXECUTE ON FUNCTION public.reset_login_attempts(TEXT) TO anon, authenticated;
