-- ================================================================
-- ShoriBooks -- trial-ending reminder dedupe log.
-- The process-reminders Edge Function sends "your trial ends in N days"
-- notices at 7, 3 and 1 days out. This table guarantees each (business,
-- offset) notice fires exactly once. Written only by the function (service
-- role, which bypasses RLS); RLS is enabled with no policies so it is
-- otherwise locked.
-- ================================================================

CREATE TABLE IF NOT EXISTS public.trial_reminder_log (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  days_before int  NOT NULL,
  sent_at     timestamptz NOT NULL DEFAULT now(),
  UNIQUE (business_id, days_before)
);

ALTER TABLE public.trial_reminder_log ENABLE ROW LEVEL SECURITY;
