-- ================================================================
-- ShoriBooks -- fix: "malformed array literal: push" when saving a booking.
--
-- generate_reminders built the channel list with `v_channels || 'push'`.
-- With an unknown-typed string literal, Postgres can resolve `||` to the
-- array||array operator and try to parse "push" as an array literal, raising
--   malformed array literal: "push"
-- (newer Postgres versions prefer that resolution). Every appointment insert
-- fires the reminder trigger, so this blocked ALL bookings on Save.
--
-- Fix: append with array_append(..., <value>::text), which is unambiguous.
-- Nothing else about the function changes. Additive + idempotent.
-- ================================================================

CREATE OR REPLACE FUNCTION public.generate_reminders(p_booking_id UUID)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_appt        RECORD;
  v_push        BOOLEAN; v_email BOOLEAN; v_wa BOOLEAN; v_sms BOOLEAN;
  v_wa_conn     BOOLEAN;
  v_offsets     INT[];
  v_uid         UUID;
  v_cust_push   BOOLEAN := true;
  v_cust_wa     BOOLEAN := true;
  v_cust_email  BOOLEAN := true;
  v_channels    TEXT[] := ARRAY[]::TEXT[];
  v_offset      INT;
  v_ch          TEXT;
  v_when        TIMESTAMPTZ;
BEGIN
  SELECT id, business_id, customer_id, start_time, status
    INTO v_appt FROM public.appointments WHERE id = p_booking_id;
  IF NOT FOUND THEN RETURN; END IF;
  -- Smart logic: never schedule for terminal or past appointments.
  IF v_appt.status IN ('cancelled', 'completed', 'no_show') THEN RETURN; END IF;
  IF v_appt.start_time <= now() THEN RETURN; END IF;

  -- Vendor settings (defaults if the business hasn't configured any).
  SELECT push_enabled, email_enabled, whatsapp_enabled, sms_enabled,
         whatsapp_connected, reminder_offsets
    INTO v_push, v_email, v_wa, v_sms, v_wa_conn, v_offsets
    FROM public.notification_settings WHERE business_id = v_appt.business_id;
  IF NOT FOUND THEN
    v_push := true; v_email := true; v_wa := false; v_sms := false;
    v_wa_conn := false; v_offsets := ARRAY[1440, 120];
  END IF;

  -- Customer preferences (only when the booking is linked to an account).
  SELECT user_id INTO v_uid FROM public.customers WHERE id = v_appt.customer_id;
  IF v_uid IS NOT NULL THEN
    SELECT push_enabled, whatsapp_enabled, email_enabled
      INTO v_cust_push, v_cust_wa, v_cust_email
      FROM public.customer_notification_preferences WHERE user_id = v_uid;
    -- If no prefs row, defaults above (all channels allowed) apply.
  END IF;

  -- Effective channels = vendor enabled AND customer opted-in.
  IF v_push  AND (v_uid IS NULL OR v_cust_push)  THEN v_channels := array_append(v_channels, 'push'::text);  END IF;
  IF v_email AND (v_uid IS NULL OR v_cust_email) THEN v_channels := array_append(v_channels, 'email'::text); END IF;
  -- WhatsApp only when the vendor has connected an official Business account.
  IF v_wa AND v_wa_conn AND (v_uid IS NULL OR v_cust_wa) THEN v_channels := array_append(v_channels, 'whatsapp'::text); END IF;
  -- SMS: architecture only for the MVP -- intentionally not enqueued yet.

  IF array_length(v_channels, 1) IS NULL OR v_offsets IS NULL THEN RETURN; END IF;

  FOREACH v_offset IN ARRAY v_offsets LOOP
    v_when := v_appt.start_time - (v_offset || ' minutes')::interval;
    CONTINUE WHEN v_when <= now();  -- don't schedule reminders in the past
    FOREACH v_ch IN ARRAY v_channels LOOP
      INSERT INTO public.reminder_queue(booking_id, business_id, user_id, channel, scheduled_for)
      SELECT p_booking_id, v_appt.business_id, v_uid, v_ch, v_when
      WHERE NOT EXISTS (           -- no duplicate pending reminders
        SELECT 1 FROM public.reminder_queue
        WHERE booking_id = p_booking_id AND channel = v_ch
          AND scheduled_for = v_when AND status = 'pending'
      );
    END LOOP;
  END LOOP;
END;
$$;
