-- ================================================================
-- Shorivo -- messaging attachments (photos now; documents/voice later).
--
-- A PRIVATE storage bucket 'message-attachments'. Unlike business logos
-- (public), chat media is private: access is scoped to the two parties of
-- the conversation via storage RLS, reusing conversation_side(). Files live
-- under "<conversation_id>/<random>.<ext>"; the client stores that PATH in
-- messages.attachment_url and fetches a short-lived signed URL to display.
--
-- Also extends send_message to carry an attachment + metadata (so an image
-- message can have an empty body). Additive + idempotent.
-- ================================================================

INSERT INTO storage.buckets (id, name, public)
VALUES ('message-attachments', 'message-attachments', false)
ON CONFLICT (id) DO NOTHING;

-- Only a participant of the conversation (first path segment) may read...
DROP POLICY IF EXISTS "message_attachments_read" ON storage.objects;
CREATE POLICY "message_attachments_read" ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'message-attachments'
    AND public.conversation_side(((storage.foldername(name))[1])::uuid) IS NOT NULL
  );

-- ...or write.
DROP POLICY IF EXISTS "message_attachments_insert" ON storage.objects;
CREATE POLICY "message_attachments_insert" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'message-attachments'
    AND public.conversation_side(((storage.foldername(name))[1])::uuid) IS NOT NULL
  );

-- ── Extend send_message with attachment + metadata ──────────────────────────
DROP FUNCTION IF EXISTS public.send_message(uuid, text, text);

CREATE OR REPLACE FUNCTION public.send_message(
  p_conversation_id uuid,
  p_body            text,
  p_message_type    text DEFAULT 'text',
  p_attachment_url  text DEFAULT NULL,
  p_metadata        jsonb DEFAULT NULL
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
  PERFORM public.assert_can_message(p_conversation_id, v_side);

  INSERT INTO public.messages (conversation_id, sender_role, sender_user_id,
      body, message_type, attachment_url, metadata)
  VALUES (p_conversation_id, v_side, v_uid, v_body, p_message_type,
      NULLIF(btrim(COALESCE(p_attachment_url, '')), ''), p_metadata)
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
GRANT EXECUTE ON FUNCTION public.send_message(uuid, text, text, text, jsonb) TO authenticated;
