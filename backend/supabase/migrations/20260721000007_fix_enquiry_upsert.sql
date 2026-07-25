-- ================================================================
-- Shorivo -- fix: "Ask a question" failed with
--   "there is no unique or exclusion constraint matching the ON CONFLICT
--    specification"
--
-- get_or_create_conversation's enquiry upsert used
--   ON CONFLICT (business_id, customer_user_id) WHERE type = 'enquiry'
-- but the partial unique index (uq_conversations_enquiry) is defined
--   WHERE type = 'enquiry' AND customer_user_id IS NOT NULL
-- For partial-index inference Postgres requires the ON CONFLICT predicate to
-- match the index predicate exactly, so it couldn't find the index. This
-- recreates the function with the matching predicate. Additive + idempotent.
-- ================================================================

CREATE OR REPLACE FUNCTION public.get_or_create_conversation(
  p_business_id   uuid,
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

  SELECT * INTO v_biz FROM public.businesses WHERE id = p_business_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'business not found'; END IF;
  IF NOT v_biz.messaging_enabled THEN RAISE EXCEPTION 'messaging_disabled'; END IF;

  IF p_appointment_id IS NOT NULL THEN
    SELECT id INTO v_conv_id FROM public.conversations WHERE appointment_id = p_appointment_id;
    IF v_conv_id IS NOT NULL THEN RETURN v_conv_id; END IF;
  ELSIF NOT v_biz.pre_booking_messaging_enabled THEN
    RAISE EXCEPTION 'pre_booking_disabled';
  END IF;

  SELECT COALESCE(NULLIF(btrim(full_name), ''), 'Customer') INTO v_name
    FROM public.profiles WHERE id = v_uid;
  v_name := COALESCE(v_name, 'Customer');

  SELECT id INTO v_customer
    FROM public.customers WHERE business_id = p_business_id AND user_id = v_uid;

  IF p_appointment_id IS NOT NULL THEN
    INSERT INTO public.conversations (business_id, customer_id, customer_user_id,
        customer_display_name, appointment_id, type)
    VALUES (p_business_id, v_customer, v_uid, v_name, p_appointment_id, 'booking')
    ON CONFLICT (appointment_id) WHERE appointment_id IS NOT NULL
    DO UPDATE SET updated_at = now()
    RETURNING id INTO v_conv_id;
  ELSE
    INSERT INTO public.conversations (business_id, customer_id, customer_user_id,
        customer_display_name, type)
    VALUES (p_business_id, v_customer, v_uid, v_name, 'enquiry')
    ON CONFLICT (business_id, customer_user_id) WHERE type = 'enquiry' AND customer_user_id IS NOT NULL
    DO UPDATE SET updated_at = now(), customer_archived = false
    RETURNING id INTO v_conv_id;
  END IF;

  RETURN v_conv_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.get_or_create_conversation(uuid, uuid) TO authenticated;
