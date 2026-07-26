-- ================================================================
-- Shorivo -- Booking Confirmation Window (Phase 1): schema + settings.
--
-- Lets a vendor require customers to confirm an online booking within a
-- configurable window; unconfirmed bookings are auto-cancelled later
-- (see 20260726000002). This migration is schema-only + the settings RPC;
-- the creation/confirm/expiry logic lives in the next migration.
--
-- Additive + idempotent. ASCII only. Run manually in the SQL editor.
-- ================================================================

-- 1. Business-level confirmation + waitlist settings ------------------------
-- confirmation_window_minutes: how long a customer has to confirm (default 2h).
-- waitlist_enabled: reserved for Phase 2 (waitlist notifications); added now so
-- the settings surface and future logic don't need another schema change.
ALTER TABLE public.businesses
  ADD COLUMN IF NOT EXISTS require_confirmation        BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS confirmation_window_minutes INT     NOT NULL DEFAULT 120,
  ADD COLUMN IF NOT EXISTS waitlist_enabled            BOOLEAN NOT NULL DEFAULT false;

-- 2. Per-appointment confirmation state ------------------------------------
-- confirmation_required: snapshot of the rule at booking time (so changing the
--   business setting never retroactively affects existing bookings).
-- confirmation_deadline: when an unconfirmed booking is auto-cancelled.
-- confirmed_at: when the customer (or vendor) confirmed.
-- cancellation_reason: free-text reason; 'confirmation_expired' for auto-cancel.
ALTER TABLE public.appointments
  ADD COLUMN IF NOT EXISTS confirmation_required BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS confirmation_deadline TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS confirmed_at          TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS cancellation_reason   TEXT;

-- The cron sweep for expired confirmations scans by (status, deadline);
-- keep it cheap with a partial index over just the pending-confirmation rows.
CREATE INDEX IF NOT EXISTS idx_appointments_pending_confirmation
  ON public.appointments (confirmation_deadline)
  WHERE status = 'pending_confirmation';

-- 3. Allow the new 'pending_confirmation' status ----------------------------
-- The appointments status CHECK was created in the web-era schema under an
-- unknown name, so find any status CHECK by its definition, drop it, and
-- re-add a comprehensive one. Idempotent: the constraint we add matches the
-- same filter, so a re-run drops and recreates it cleanly.
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN
    SELECT conname FROM pg_constraint
    WHERE conrelid = 'public.appointments'::regclass
      AND contype = 'c'
      AND pg_get_constraintdef(oid) ILIKE '%status%'
      AND pg_get_constraintdef(oid) ILIKE '%confirmed%'
  LOOP
    EXECUTE format('ALTER TABLE public.appointments DROP CONSTRAINT %I', r.conname);
  END LOOP;
  ALTER TABLE public.appointments
    ADD CONSTRAINT appointments_status_check
    CHECK (status IN (
      'pending', 'confirmed', 'completed', 'cancelled', 'no_show',
      'pending_confirmation'
    ));
END $$;

-- 4. Reminder queue: a kind discriminator + a payload ------------------------
-- The existing reminder_queue only carried pre-appointment reminders. Reuse it
-- for confirmation reminders and the auto-cancel / (future) waitlist notices
-- by tagging each row with a kind and an optional JSONB payload (e.g. the
-- confirmation deadline). process-reminders branches on kind to render text.
ALTER TABLE public.reminder_queue
  ADD COLUMN IF NOT EXISTS kind    TEXT NOT NULL DEFAULT 'appointment',
  ADD COLUMN IF NOT EXISTS payload JSONB;

-- 5. Extend save_booking_rules with the confirmation settings ----------------
-- Old 5-arg signature is dropped and replaced with a superset whose two new
-- args default to NULL = "leave unchanged", so any existing caller still works.
DROP FUNCTION IF EXISTS public.save_booking_rules(UUID, INT, INT, INT, INT);
CREATE OR REPLACE FUNCTION public.save_booking_rules(
  p_business_id          UUID,
  p_buffer_minutes       INT,
  p_max_per_day          INT,
  p_max_per_hour         INT,
  p_max_simultaneous     INT,
  p_require_confirmation BOOLEAN DEFAULT NULL,
  p_confirmation_window  INT     DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF public.get_my_business_role(p_business_id) NOT IN ('OWNER', 'ADMIN') THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  UPDATE public.businesses SET
    buffer_minutes            = GREATEST(0, COALESCE(p_buffer_minutes, 0)),
    max_bookings_per_day      = p_max_per_day,
    max_bookings_per_hour     = p_max_per_hour,
    max_simultaneous_bookings = p_max_simultaneous,
    require_confirmation      = COALESCE(p_require_confirmation, require_confirmation),
    -- Clamp the window to a sane 5 min .. 7 day range when provided.
    confirmation_window_minutes = CASE
      WHEN p_confirmation_window IS NULL THEN confirmation_window_minutes
      ELSE LEAST(10080, GREATEST(5, p_confirmation_window))
    END,
    updated_at                = now()
  WHERE id = p_business_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.save_booking_rules(UUID, INT, INT, INT, INT, BOOLEAN, INT) TO authenticated;
