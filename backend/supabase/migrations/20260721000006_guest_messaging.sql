-- ================================================================
-- Shorivo -- guest messaging.
--
-- Guests (no real account) can now message too. The app signs them in
-- ANONYMOUSLY (Supabase anonymous auth), which gives them a real auth.uid()
-- so the existing RLS + Realtime + storage policies work unchanged. The app
-- still treats anonymous users as "guests" everywhere else.
--
-- Pre-booking enquiries just work (get_or_create_conversation stamps the
-- anon uid). For a guest's *booking* conversation (auto-created with
-- customer_user_id = NULL because the booking had no account), the guest
-- proves ownership with the phone they booked with, and we link the anon uid
-- so they can read/send. Verified by phone match, like the guest cancel /
-- reschedule RPCs. Additive + idempotent.
-- ================================================================

CREATE OR REPLACE FUNCTION public.claim_guest_booking_conversation(
  p_appointment_id uuid,
  p_phone          text
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_uid     uuid := (SELECT auth.uid());
  v_appt    RECORD;
  v_enabled boolean;
  v_conv_id uuid;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'authentication required'; END IF;
  IF p_phone IS NULL OR btrim(p_phone) = '' THEN RAISE EXCEPTION 'phone required'; END IF;

  SELECT a.id, a.business_id, a.customer_id, a.customer_name, a.customer_phone
    INTO v_appt
    FROM public.appointments a
   WHERE a.id = p_appointment_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'appointment not found'; END IF;

  -- Phone must match the booking (digits only), mirroring the guest
  -- cancel/reschedule ownership check.
  IF regexp_replace(COALESCE(v_appt.customer_phone, ''), '[^0-9]', '', 'g') <>
     regexp_replace(p_phone, '[^0-9]', '', 'g')
     OR regexp_replace(p_phone, '[^0-9]', '', 'g') = '' THEN
    RAISE EXCEPTION 'phone does not match booking';
  END IF;

  SELECT messaging_enabled INTO v_enabled
    FROM public.businesses WHERE id = v_appt.business_id;
  IF NOT COALESCE(v_enabled, false) THEN RAISE EXCEPTION 'messaging_disabled'; END IF;

  -- Link this anon user to the conversation (create if the trigger hadn't,
  -- e.g. messaging was toggled on after booking). Only claims a conversation
  -- that isn't already owned by a (different) account.
  INSERT INTO public.conversations (business_id, customer_id, customer_user_id,
      customer_display_name, appointment_id, type)
  VALUES (v_appt.business_id, v_appt.customer_id, v_uid,
      COALESCE(NULLIF(btrim(v_appt.customer_name), ''), 'Customer'),
      v_appt.id, 'booking')
  ON CONFLICT (appointment_id) WHERE appointment_id IS NOT NULL
  DO UPDATE SET
    customer_user_id = CASE
      WHEN public.conversations.customer_user_id IS NULL
        THEN v_uid ELSE public.conversations.customer_user_id END,
    updated_at = now()
  RETURNING id INTO v_conv_id;

  RETURN v_conv_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.claim_guest_booking_conversation(uuid, text) TO authenticated;
