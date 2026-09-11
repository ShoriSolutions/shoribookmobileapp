-- ================================================================
-- Shorivo -- chat: tag each message with the booking it's about.
--
-- Messaging is one thread per (business, customer account). Until now the
-- thread held a single appointment_id that was overwritten by every new
-- booking, and by opening an older booking's chat, while messages carried no
-- booking at all -- so with several bookings nobody could tell which booking
-- a message was about. This migration:
--
--   1. Adds messages.appointment_id: the booking a message is about (optional).
--   2. send_message gains p_appointment_id, checked to belong to that chat's
--      customer at that chat's business.
--   3. get_or_create_conversation: guest (anonymous) sessions can't open
--      chats; a booking passed in must be the caller's own booking at that
--      business; opening an older booking no longer re-points the thread.
--   4. create_booking_conversation (booking trigger) no longer creates empty
--      chats: it only points an existing thread at the newest booking, and it
--      can never block a booking.
--   5. Drops the one-chat-per-booking rule (uq_conversations_appointment). It
--      caused "record already exists" errors and means nothing once bookings
--      live on messages.
--   6. Deletes guest (no-account) booking chats that never had a message:
--      guests can't use chat, so vendor messages there reached nobody.
--
-- conversations.type / appointment_id keep meaning "has booked" / "latest
-- booking" for the list filter. One transaction. Idempotent. ASCII only.
-- ================================================================

BEGIN;

-- 1. Booking tag on each message -------------------------------------------
ALTER TABLE public.messages
  ADD COLUMN IF NOT EXISTS appointment_id uuid
    REFERENCES public.appointments(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_messages_appointment
  ON public.messages (appointment_id) WHERE appointment_id IS NOT NULL;

-- Does this booking belong to this chat's customer, at this chat's business?
CREATE OR REPLACE FUNCTION public.booking_belongs_to_conversation(
  p_appointment_id  uuid,
  p_conversation_id uuid
)
RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1
    FROM public.conversations c
    JOIN public.appointments a
      ON a.id = p_appointment_id AND a.business_id = c.business_id
    LEFT JOIN public.customers cu ON cu.id = a.customer_id
    WHERE c.id = p_conversation_id
      AND ((c.customer_user_id IS NOT NULL AND cu.user_id = c.customer_user_id)
        OR (c.customer_id IS NOT NULL AND a.customer_id = c.customer_id))
  );
$$;
REVOKE EXECUTE ON FUNCTION public.booking_belongs_to_conversation(uuid, uuid)
  FROM PUBLIC, anon, authenticated;

-- 2. send_message with an optional booking tag ------------------------------
-- New signature, so drop the old one (otherwise two overloads would make the
-- API's named-argument call ambiguous). Old app builds keep working: the new
-- parameter defaults to NULL.
DROP FUNCTION IF EXISTS public.send_message(uuid, text, text, text, jsonb);
CREATE OR REPLACE FUNCTION public.send_message(
  p_conversation_id uuid,
  p_body            text,
  p_message_type    text  DEFAULT 'text',
  p_attachment_url  text  DEFAULT NULL,
  p_metadata        jsonb DEFAULT NULL,
  p_appointment_id  uuid  DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_uid     uuid := (SELECT auth.uid());
  v_side    text := public.conversation_side(p_conversation_id);
  v_id      uuid;
  v_preview text;
  v_body    text := COALESCE(btrim(p_body), '');
BEGIN
  IF v_side IS NULL THEN RAISE EXCEPTION 'not authorized'; END IF;
  IF p_message_type NOT IN ('text','image','document','voice','location') THEN
    RAISE EXCEPTION 'invalid message type';
  END IF;
  -- A text message needs text; a media message needs an attachment.
  IF p_message_type = 'text' AND v_body = '' THEN
    RAISE EXCEPTION 'empty message';
  END IF;
  IF p_message_type <> 'text' AND (p_attachment_url IS NULL OR btrim(p_attachment_url) = '') THEN
    RAISE EXCEPTION 'attachment required';
  END IF;
  -- A booking tag must be one of this chat customer's bookings here.
  IF p_appointment_id IS NOT NULL
     AND NOT public.booking_belongs_to_conversation(p_appointment_id, p_conversation_id) THEN
    RAISE EXCEPTION 'invalid_booking';
  END IF;
  PERFORM public.assert_can_message(p_conversation_id, v_side);

  INSERT INTO public.messages (conversation_id, sender_role, sender_user_id,
      body, message_type, attachment_url, metadata, appointment_id)
  VALUES (p_conversation_id, v_side, v_uid, v_body, p_message_type,
      NULLIF(btrim(COALESCE(p_attachment_url, '')), ''), p_metadata,
      p_appointment_id)
  RETURNING id INTO v_id;

  v_preview := CASE p_message_type
    WHEN 'image'    THEN 'Photo'
    WHEN 'document' THEN 'Document'
    WHEN 'voice'    THEN 'Voice message'
    WHEN 'location' THEN 'Location'
    ELSE left(v_body, 140)
  END;

  UPDATE public.conversations SET
    last_message_at      = now(),
    last_message_preview = v_preview,
    last_message_sender  = v_side,
    updated_at           = now(),
    vendor_last_read_at   = CASE WHEN v_side = 'vendor'   THEN now() ELSE vendor_last_read_at END,
    customer_last_read_at = CASE WHEN v_side = 'customer' THEN now() ELSE customer_last_read_at END,
    vendor_archived   = CASE WHEN v_side = 'vendor'   THEN false ELSE vendor_archived END,
    customer_archived = CASE WHEN v_side = 'customer' THEN false ELSE customer_archived END
  WHERE id = p_conversation_id;

  RETURN v_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.send_message(uuid, text, text, text, jsonb, uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.send_message(uuid, text, text, text, jsonb, uuid)
  TO authenticated;

-- 3. get_or_create_conversation ---------------------------------------------
CREATE OR REPLACE FUNCTION public.get_or_create_conversation(
  p_business_id    uuid,
  p_appointment_id uuid DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_uid       uuid := (SELECT auth.uid());
  v_biz       RECORD;
  v_name      text;
  v_customer  uuid;
  v_conv_id   uuid;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'authentication required'; END IF;
  -- Guest (anonymous) sessions can't send messages, so don't let them open
  -- (empty) chats either.
  IF COALESCE((auth.jwt() ->> 'is_anonymous')::boolean, false) THEN
    RAISE EXCEPTION 'account_required';
  END IF;

  SELECT * INTO v_biz FROM public.businesses WHERE id = p_business_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'business not found'; END IF;
  IF NOT v_biz.messaging_enabled THEN RAISE EXCEPTION 'messaging_disabled'; END IF;

  -- A booking passed in must be the caller's own booking at this business.
  IF p_appointment_id IS NOT NULL AND NOT EXISTS (
    SELECT 1
    FROM public.appointments a
    JOIN public.customers cu ON cu.id = a.customer_id
    WHERE a.id = p_appointment_id
      AND a.business_id = p_business_id
      AND cu.user_id = v_uid
  ) THEN
    RAISE EXCEPTION 'invalid_booking';
  END IF;

  -- The single existing thread for this customer + business (if any).
  SELECT id INTO v_conv_id
  FROM public.conversations
  WHERE business_id = p_business_id AND customer_user_id = v_uid
  ORDER BY created_at, id
  LIMIT 1;

  -- Pre-booking gate: only blocks a brand-new enquiry (no appointment, no
  -- existing thread) when the business has pre-booking messaging turned off.
  IF v_conv_id IS NULL
     AND p_appointment_id IS NULL
     AND NOT v_biz.pre_booking_messaging_enabled THEN
    RAISE EXCEPTION 'pre_booking_disabled';
  END IF;

  SELECT COALESCE(NULLIF(btrim(full_name), ''), 'Customer') INTO v_name
    FROM public.profiles WHERE id = v_uid;
  v_name := COALESCE(v_name, 'Customer');

  SELECT id INTO v_customer
    FROM public.customers WHERE business_id = p_business_id AND user_id = v_uid;

  IF v_conv_id IS NOT NULL THEN
    -- Reuse the thread. Its appointment_id is the latest booking (kept by the
    -- booking trigger); opening an older booking no longer re-points it --
    -- which booking a message is about now lives on the message.
    UPDATE public.conversations
    SET updated_at        = now(),
        customer_archived = false,
        customer_id       = COALESCE(customer_id, v_customer),
        appointment_id    = COALESCE(appointment_id, p_appointment_id),
        type              = CASE WHEN p_appointment_id IS NOT NULL
                                 THEN 'booking' ELSE type END
    WHERE id = v_conv_id;
    RETURN v_conv_id;
  END IF;

  -- None yet -- create the customer's single thread.
  BEGIN
    INSERT INTO public.conversations (business_id, customer_id, customer_user_id,
        customer_display_name, appointment_id, type)
    VALUES (p_business_id, v_customer, v_uid, v_name, p_appointment_id,
        CASE WHEN p_appointment_id IS NOT NULL THEN 'booking' ELSE 'enquiry' END)
    RETURNING id INTO v_conv_id;
  EXCEPTION WHEN unique_violation THEN
    -- A concurrent call created it first -- return that one.
    SELECT id INTO v_conv_id
    FROM public.conversations
    WHERE business_id = p_business_id AND customer_user_id = v_uid
    ORDER BY created_at, id
    LIMIT 1;
  END;

  RETURN v_conv_id;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.get_or_create_conversation(uuid, uuid) FROM PUBLIC, anon;
GRANT  EXECUTE ON FUNCTION public.get_or_create_conversation(uuid, uuid) TO authenticated;

-- 4. Booking trigger: keep the thread's latest booking, create nothing ------
-- (Name kept so the existing trg_create_booking_conversation still uses it.)
CREATE OR REPLACE FUNCTION public.create_booking_conversation()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_user uuid;
BEGIN
  SELECT user_id INTO v_user FROM public.customers WHERE id = NEW.customer_id;
  IF v_user IS NULL THEN RETURN NEW; END IF;  -- guests have no chat

  -- Point the customer's existing chat (if any) at their newest booking. No
  -- chat is created here: one is made when the customer actually opens it.
  UPDATE public.conversations
     SET appointment_id = NEW.id,
         type           = 'booking',
         customer_id    = COALESCE(customer_id, NEW.customer_id),
         updated_at     = now()
   WHERE business_id = NEW.business_id AND customer_user_id = v_user;
  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- A chat problem must never block a booking.
  RETURN NEW;
END;
$$;

-- 5. Drop the one-chat-per-booking rule --------------------------------------
-- (Safe now: the trigger above no longer uses ON CONFLICT (appointment_id).)
DROP INDEX IF EXISTS public.uq_conversations_appointment;

-- 6. Remove guest booking chats that were never used -------------------------
DELETE FROM public.conversations c
WHERE c.customer_user_id IS NULL
  AND c.last_message_at IS NULL
  AND NOT EXISTS (SELECT 1 FROM public.messages m WHERE m.conversation_id = c.id)
  AND NOT EXISTS (SELECT 1 FROM public.conversation_reports r WHERE r.conversation_id = c.id);

COMMIT;
