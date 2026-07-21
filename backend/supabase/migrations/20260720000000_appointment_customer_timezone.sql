-- ================================================================
-- ShoriBooks -- record the customer's IANA time zone on each booking.
-- Appointments already store start/end in UTC; this adds the customer's
-- zone (e.g. America/New_York) so reminders and the vendor dashboard can
-- show the customer's local time alongside the business's. Set write-once
-- right after booking via a small RPC, so the large booking function is
-- left untouched. Additive + idempotent.
-- ================================================================

ALTER TABLE public.appointments
  ADD COLUMN IF NOT EXISTS customer_timezone text;

-- Write-once setter (guests included). Only fills the field when still null,
-- so it can't be used to rewrite an existing value.
CREATE OR REPLACE FUNCTION public.set_appointment_customer_timezone(
  p_appointment_id uuid,
  p_timezone       text
)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  UPDATE public.appointments
  SET customer_timezone = btrim(p_timezone)
  WHERE id = p_appointment_id
    AND customer_timezone IS NULL
    AND NULLIF(btrim(p_timezone), '') IS NOT NULL;
$$;

GRANT EXECUTE ON FUNCTION public.set_appointment_customer_timezone(uuid, text)
  TO anon, authenticated;
