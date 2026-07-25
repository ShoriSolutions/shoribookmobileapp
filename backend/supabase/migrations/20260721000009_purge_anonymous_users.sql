-- ================================================================
-- Shorivo -- housekeeping: purge stale anonymous (guest) users.
--
-- Anonymous sign-ins (guest messaging) create an auth.users row + a profiles
-- row per device. Over time these accumulate. This purges anonymous accounts
-- older than N days that have no recent conversation activity, cleaning up
-- their profile too, and removes abandoned guest ENQUIRY threads whose owner
-- is gone (booking chats are kept for the vendor's history).
--
-- Runs daily via pg_cron. Safe to re-run. Only touches anonymous users --
-- real accounts are never deleted.
-- ================================================================

CREATE OR REPLACE FUNCTION public.purge_stale_anonymous_users(p_days int DEFAULT 15)
RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, auth
AS $$
DECLARE
  v_count int;
BEGIN
  -- Delete anonymous accounts older than p_days with no recent conversation.
  WITH doomed AS (
    SELECT u.id
    FROM auth.users u
    WHERE u.is_anonymous = true
      AND u.created_at < now() - make_interval(days => GREATEST(p_days, 0))
      AND NOT EXISTS (
        SELECT 1 FROM public.conversations c
        WHERE c.customer_user_id = u.id
          AND c.last_message_at > now() - make_interval(days => GREATEST(p_days, 0))
      )
  ),
  del AS (
    DELETE FROM auth.users u USING doomed d WHERE u.id = d.id
    RETURNING u.id
  )
  SELECT count(*) INTO v_count FROM del;

  -- Belt-and-braces: remove any profile row whose auth user no longer exists
  -- (covers a profiles table without ON DELETE CASCADE).
  DELETE FROM public.profiles p
  WHERE NOT EXISTS (SELECT 1 FROM auth.users u WHERE u.id = p.id);

  -- Remove abandoned guest enquiry threads whose owner is gone. Booking
  -- conversations are kept so the vendor retains the appointment history.
  DELETE FROM public.conversations c
  WHERE c.type = 'enquiry'
    AND c.customer_user_id IS NOT NULL
    AND NOT EXISTS (SELECT 1 FROM auth.users u WHERE u.id = c.customer_user_id);

  RETURN v_count;
END;
$$;

-- Daily at 03:00 UTC. Guarded so the migration still succeeds if pg_cron
-- isn't available (schedule it manually then).
DO $$
BEGIN
  PERFORM cron.unschedule('purge-anon-users');
EXCEPTION WHEN OTHERS THEN NULL;
END $$;

DO $$
BEGIN
  PERFORM cron.schedule('purge-anon-users', '0 3 * * *',
    'SELECT public.purge_stale_anonymous_users(15);');
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'pg_cron not available - schedule purge-anon-users manually.';
END $$;
