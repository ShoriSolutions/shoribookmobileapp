-- ================================================================
-- Shorivo -- email notifications for unread chat messages (no Firebase).
--
-- process-reminders (per-minute cron) calls claim_message_email_targets(),
-- which finds conversations with an unread inbound message that has sat for a
-- grace period (so we don't email during an active chat), honours the
-- recipient side's mute flag, de-dupes per (conversation, recipient) within a
-- cooldown, and CLAIMS them by writing message_email_log in the same call so
-- concurrent runs never double-send. Recipient = the business OWNER (vendor
-- side) or the customer's account (customer side).
-- Additive + idempotent.
-- ================================================================

CREATE TABLE IF NOT EXISTS public.message_email_log (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id uuid NOT NULL,
  user_id         uuid NOT NULL,
  emailed_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_message_email_log_lookup
  ON public.message_email_log(conversation_id, user_id, emailed_at DESC);

-- Service-role only (called by the Edge Function). No grant to authenticated.
CREATE OR REPLACE FUNCTION public.claim_message_email_targets(
  p_grace_minutes    int DEFAULT 3,
  p_cooldown_minutes int DEFAULT 60
)
RETURNS TABLE(
  recipient_email text,
  recipient_name  text,
  other_name      text,
  preview         text,
  unread          int
)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  WITH cand AS (
    SELECT
      c.id AS conversation_id,
      c.last_message_sender AS s,
      c.last_message_at,
      c.last_message_preview AS preview,
      CASE WHEN c.last_message_sender = 'customer'
           THEN b.owner_id ELSE c.customer_user_id END AS user_id,
      CASE WHEN c.last_message_sender = 'customer'
           THEN c.vendor_muted ELSE c.customer_muted END AS muted,
      CASE WHEN c.last_message_sender = 'customer'
           THEN c.vendor_last_read_at ELSE c.customer_last_read_at END AS last_read,
      CASE WHEN c.last_message_sender = 'customer'
           THEN c.customer_display_name ELSE b.name END AS other_name
    FROM public.conversations c
    JOIN public.businesses b ON b.id = c.business_id
    WHERE c.last_message_at IS NOT NULL
      AND c.last_message_sender IN ('vendor','customer')
      AND c.last_message_at < now() - make_interval(mins => p_grace_minutes)
      AND c.last_message_at > now() - interval '1 day'
  ),
  elig AS (
    SELECT cand.*, p.email, p.full_name
    FROM cand
    JOIN public.profiles p ON p.id = cand.user_id
    WHERE cand.user_id IS NOT NULL
      AND cand.muted = false
      AND p.email IS NOT NULL
      AND (cand.last_read IS NULL OR cand.last_message_at > cand.last_read)
      AND NOT EXISTS (
        SELECT 1 FROM public.message_email_log l
        WHERE l.conversation_id = cand.conversation_id
          AND l.user_id = cand.user_id
          AND l.emailed_at > now() - make_interval(mins => p_cooldown_minutes)
      )
  ),
  ins AS (
    INSERT INTO public.message_email_log (conversation_id, user_id)
    SELECT conversation_id, user_id FROM elig
    RETURNING conversation_id, user_id
  )
  SELECT
    e.email,
    COALESCE(e.full_name, 'there'),
    e.other_name,
    COALESCE(e.preview, ''),
    (SELECT count(*)::int FROM public.messages m
       WHERE m.conversation_id = e.conversation_id
         AND m.sender_role = e.s
         AND m.created_at > COALESCE(e.last_read, 'epoch'::timestamptz))
  FROM ins
  JOIN elig e ON e.conversation_id = ins.conversation_id AND e.user_id = ins.user_id;
END;
$$;
