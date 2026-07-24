-- ================================================================
-- Shorivo -- unified email outbox (all email dispatched via Nodemailer).
--
-- Supabase Edge Functions run on Deno and can't run Nodemailer, so instead
-- of sending email from the Edge Function we ENQUEUE it here. The Node
-- backend (which has Nodemailer) drains this table: claim -> send -> mark.
-- This unifies every outbound email (booking reminders, trial notices, new
-- message notices) on one transport with one queue.
--
-- claim_outbox_emails uses FOR UPDATE SKIP LOCKED so multiple dispatcher
-- runs/workers never grab the same row. Additive + idempotent.
-- ================================================================

CREATE TABLE IF NOT EXISTS public.email_outbox (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  to_email    text NOT NULL,
  subject     text NOT NULL,
  html        text NOT NULL,
  category    text NOT NULL DEFAULT 'general',  -- 'booking_reminder' | 'trial' | 'message' | ...
  status      text NOT NULL DEFAULT 'pending'
                CHECK (status IN ('pending','sending','sent','failed')),
  attempts    int  NOT NULL DEFAULT 0,
  last_error  text,
  dedupe_key  text,                              -- optional; prevents double-enqueue
  created_at  timestamptz NOT NULL DEFAULT now(),
  sent_at     timestamptz
);
CREATE INDEX IF NOT EXISTS idx_email_outbox_pending
  ON public.email_outbox(created_at) WHERE status = 'pending';
CREATE UNIQUE INDEX IF NOT EXISTS uq_email_outbox_dedupe
  ON public.email_outbox(dedupe_key) WHERE dedupe_key IS NOT NULL;

ALTER TABLE public.email_outbox ENABLE ROW LEVEL SECURITY;
-- No public policies: only the service role (Edge Function producer + Node
-- dispatcher) touches this table.

-- Claim a batch to send. Atomically flips pending -> sending so concurrent
-- dispatchers never double-send. Service-role only.
CREATE OR REPLACE FUNCTION public.claim_outbox_emails(p_limit int DEFAULT 50)
RETURNS SETOF public.email_outbox
LANGUAGE sql SECURITY DEFINER SET search_path = public
AS $$
  WITH c AS (
    SELECT id FROM public.email_outbox
    WHERE status = 'pending'
    ORDER BY created_at
    LIMIT GREATEST(p_limit, 1)
    FOR UPDATE SKIP LOCKED
  )
  UPDATE public.email_outbox o
     SET status = 'sending', attempts = o.attempts + 1
    FROM c
   WHERE o.id = c.id
  RETURNING o.*;
$$;

CREATE OR REPLACE FUNCTION public.mark_outbox_sent(p_id uuid)
RETURNS void
LANGUAGE sql SECURITY DEFINER SET search_path = public
AS $$
  UPDATE public.email_outbox
     SET status = 'sent', sent_at = now(), last_error = NULL
   WHERE id = p_id;
$$;

-- Requeue for another attempt, or give up after 5 tries.
CREATE OR REPLACE FUNCTION public.mark_outbox_failed(p_id uuid, p_error text)
RETURNS void
LANGUAGE sql SECURITY DEFINER SET search_path = public
AS $$
  UPDATE public.email_outbox
     SET status = CASE WHEN attempts >= 5 THEN 'failed' ELSE 'pending' END,
         last_error = p_error
   WHERE id = p_id;
$$;
