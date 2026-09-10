-- ================================================================
-- Shorivo -- email outbox: send order + keep retries on provider limits.
--
-- dispatch-emails now caps sending to the Resend daily budget (free plan:
-- 100/day, 3,000/month, shared with the website and Supabase Auth emails).
-- When the budget is tight, the most important emails should go first, and
-- an email Resend refuses for quota / rate limit (HTTP 429) should wait for
-- the next run rather than burn one of its 5 retries.
--
--   * claim_outbox_emails: security alerts first, new-message notices last,
--     everything else (booking reminders, trial notices) in between; oldest
--     first within each group.
--   * release_outbox_email: returns a claimed ('sending') row to the queue
--     and refunds the attempt the claim spent.
--   * Outbox RPCs are service-role only (explicit, in case defaults drift).
--
-- Idempotent. ASCII only.
-- ================================================================

CREATE OR REPLACE FUNCTION public.claim_outbox_emails(p_limit int DEFAULT 50)
RETURNS SETOF public.email_outbox
LANGUAGE sql SECURITY DEFINER SET search_path = public
AS $$
  WITH c AS (
    SELECT id FROM public.email_outbox
    WHERE status = 'pending'
    ORDER BY CASE category
               WHEN 'security' THEN 0
               WHEN 'message'  THEN 2
               ELSE 1
             END,
             created_at
    LIMIT GREATEST(p_limit, 1)
    FOR UPDATE SKIP LOCKED
  )
  UPDATE public.email_outbox o
     SET status = 'sending', attempts = o.attempts + 1
    FROM c
   WHERE o.id = c.id
  RETURNING o.*;
$$;

CREATE OR REPLACE FUNCTION public.release_outbox_email(p_id uuid)
RETURNS void
LANGUAGE sql SECURITY DEFINER SET search_path = public
AS $$
  UPDATE public.email_outbox
     SET status = 'pending', attempts = GREATEST(attempts - 1, 0)
   WHERE id = p_id AND status = 'sending';
$$;

REVOKE EXECUTE ON FUNCTION public.claim_outbox_emails(int)      FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.release_outbox_email(uuid)    FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.mark_outbox_sent(uuid)        FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.mark_outbox_failed(uuid, text) FROM PUBLIC, anon, authenticated;
GRANT  EXECUTE ON FUNCTION public.claim_outbox_emails(int)      TO service_role;
GRANT  EXECUTE ON FUNCTION public.release_outbox_email(uuid)    TO service_role;
GRANT  EXECUTE ON FUNCTION public.mark_outbox_sent(uuid)        TO service_role;
GRANT  EXECUTE ON FUNCTION public.mark_outbox_failed(uuid, text) TO service_role;
