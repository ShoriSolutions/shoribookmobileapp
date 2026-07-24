-- ================================================================
-- Shorivo -- device push-token registry (for message + booking pushes).
--
-- Each signed-in device registers its FCM/APNs token here. The
-- send-message-push Edge Function looks these up to deliver a push to the
-- recipient of a new message (respecting their mute flag). Writes go through
-- SECURITY DEFINER RPCs so a client only ever manages its own tokens.
-- Additive + idempotent.
-- ================================================================

CREATE TABLE IF NOT EXISTS public.device_push_tokens (
  token       text PRIMARY KEY,          -- FCM registration token (unique per install)
  user_id     uuid NOT NULL,
  platform    text NOT NULL CHECK (platform IN ('ios','android','web')),
  updated_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_device_push_tokens_user ON public.device_push_tokens(user_id);

ALTER TABLE public.device_push_tokens ENABLE ROW LEVEL SECURITY;
-- A user may read their own tokens (admins/service-role bypass RLS).
DROP POLICY IF EXISTS device_push_tokens_select ON public.device_push_tokens;
CREATE POLICY device_push_tokens_select ON public.device_push_tokens
  FOR SELECT USING (user_id = (SELECT auth.uid()));

CREATE OR REPLACE FUNCTION public.register_push_token(
  p_token    text,
  p_platform text
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_uid uuid := (SELECT auth.uid());
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'authentication required'; END IF;
  IF p_token IS NULL OR btrim(p_token) = '' THEN RAISE EXCEPTION 'token required'; END IF;
  IF p_platform NOT IN ('ios','android','web') THEN RAISE EXCEPTION 'invalid platform'; END IF;

  INSERT INTO public.device_push_tokens (token, user_id, platform, updated_at)
  VALUES (btrim(p_token), v_uid, p_platform, now())
  ON CONFLICT (token) DO UPDATE SET
    user_id = EXCLUDED.user_id,      -- reassign if the device switched account
    platform = EXCLUDED.platform,
    updated_at = now();
END;
$$;
GRANT EXECUTE ON FUNCTION public.register_push_token(text, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.unregister_push_token(p_token text)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  DELETE FROM public.device_push_tokens
  WHERE token = btrim(p_token) AND user_id = (SELECT auth.uid());
END;
$$;
GRANT EXECUTE ON FUNCTION public.unregister_push_token(text) TO authenticated;

-- Helper the push Edge Function uses (service role) to resolve who should be
-- notified for a message, honouring the recipient side's mute flag. Returns
-- the recipient user ids + a title/body for the notification.
CREATE OR REPLACE FUNCTION public.message_push_targets(p_message_id uuid)
RETURNS TABLE(user_id uuid, title text, body text)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_msg   RECORD;
  v_conv  RECORD;
  v_title text;
  v_body  text;
BEGIN
  SELECT * INTO v_msg FROM public.messages WHERE id = p_message_id;
  IF NOT FOUND OR v_msg.sender_role = 'system' THEN RETURN; END IF;

  SELECT c.*, b.name AS business_name
    INTO v_conv
    FROM public.conversations c
    JOIN public.businesses b ON b.id = c.business_id
   WHERE c.id = v_msg.conversation_id;
  IF NOT FOUND THEN RETURN; END IF;

  v_body := CASE v_msg.message_type
    WHEN 'text' THEN left(v_msg.body, 140)
    WHEN 'image' THEN 'Sent a photo'
    ELSE 'Sent an attachment'
  END;

  IF v_msg.sender_role = 'customer' THEN
    -- Notify the business side (active members), unless the vendor muted it.
    IF v_conv.vendor_muted THEN RETURN; END IF;
    v_title := v_conv.customer_display_name;
    RETURN QUERY
      SELECT bm.user_id, v_title, v_body
      FROM public.business_members bm
      WHERE bm.business_id = v_conv.business_id AND bm.status = 'ACTIVE';
  ELSE
    -- Notify the customer, unless they muted it.
    IF v_conv.customer_muted OR v_conv.customer_user_id IS NULL THEN RETURN; END IF;
    v_title := v_conv.business_name;
    RETURN QUERY SELECT v_conv.customer_user_id, v_title, v_body;
  END IF;
END;
$$;
-- Callable only by the service role (Edge Function); no grant to authenticated.
