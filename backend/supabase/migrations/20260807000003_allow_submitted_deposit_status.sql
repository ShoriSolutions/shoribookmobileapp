-- ================================================================
-- Shorivo -- allow deposit_status = 'SUBMITTED' on appointments.
--
-- Migration 20260807000002 taught submit_deposit() to set
-- appointments.deposit_status = 'SUBMITTED', but the appointments table's
-- CHECK constraint (valid_deposit_status) predates that value, so submitting
-- deposit proof failed with:
--   new row for relation "appointments" violates check constraint
--   "valid_deposit_status"
--
-- Widen the constraint to the full set the app model uses (see
-- lib/models/appointment.dart -> DepositStatus): NOT_REQUIRED, PENDING,
-- SUBMITTED, PAID, FAILED, REFUNDED.
--
-- Idempotent. Run manually.
-- ================================================================

ALTER TABLE public.appointments
  DROP CONSTRAINT IF EXISTS valid_deposit_status;

ALTER TABLE public.appointments
  ADD CONSTRAINT valid_deposit_status
  CHECK (deposit_status IN (
    'NOT_REQUIRED', 'PENDING', 'SUBMITTED', 'PAID', 'FAILED', 'REFUNDED'
  ));
