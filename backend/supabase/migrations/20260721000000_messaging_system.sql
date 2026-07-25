-- ================================================================
-- ShoriBooks / Shorivo -- appointment-based messaging system.
--
-- Secure in-app messaging between a business (vendor side: any ACTIVE
-- member) and a customer (customer side: the auth user who owns the
-- customer contact, or the enquiry's author). Two conversation types:
--   'enquiry' -- a pre-booking question (no appointment yet)
--   'booking' -- auto-created for an appointment, carries its context
--
-- Design notes
--   * Writes go through SECURITY DEFINER RPCs (send_message, mark_read,
--     flags, block, report). Reads use RLS-guarded SELECT policies so
--     Supabase Realtime .stream() delivers only rows a user may see.
--   * conversations carries denormalised customer_display_name +
--     customer_user_id so an enquiry needs no pre-existing customers row
--     and the vendor list needs no extra joins.
--   * message_type / attachment_url / metadata are present now so photos,
--     documents, voice and location can be added without a schema change.
--   * Typing indicators use Realtime broadcast on the client -- no table.
-- Additive + idempotent.
-- ================================================================

-- ── Business messaging settings ─────────────────────────────────────────────
ALTER TABLE public.businesses
  ADD COLUMN IF NOT EXISTS messaging_enabled boolean NOT NULL DEFAULT true,
  ADD COLUMN IF NOT EXISTS pre_booking_messaging_enabled boolean NOT NULL DEFAULT true;

-- ── Platform messaging privileges (moderation suspension) ───────────────────
CREATE TABLE IF NOT EXISTS public.messaging_privileges (
  user_id                uuid PRIMARY KEY,
  suspended_until        timestamptz,
  permanently_restricted boolean NOT NULL DEFAULT false,
  reason                 text,
  updated_at             timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.messaging_privileges ENABLE ROW LEVEL SECURITY;
-- A user may read their own privilege row; admins read all.
DROP POLICY IF EXISTS messaging_privileges_select ON public.messaging_privileges;
CREATE POLICY messaging_privileges_select ON public.messaging_privileges
  FOR SELECT USING (user_id = (SELECT auth.uid()) OR public.is_admin());

-- ── Conversations ───────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.conversations (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id           uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  customer_id           uuid REFERENCES public.customers(id) ON DELETE SET NULL,
  customer_user_id      uuid,                         -- auth user on the customer side (nullable for guest bookings)
  customer_display_name text NOT NULL DEFAULT 'Customer',
  appointment_id        uuid REFERENCES public.appointments(id) ON DELETE SET NULL,
  type                  text NOT NULL CHECK (type IN ('enquiry','booking')),
  -- rolling summary for the list view
  last_message_at       timestamptz,
  last_message_preview  text,
  last_message_sender   text CHECK (last_message_sender IN ('vendor','customer','system')),
  -- per-side state
  vendor_archived       boolean NOT NULL DEFAULT false,
  customer_archived     boolean NOT NULL DEFAULT false,
  vendor_muted          boolean NOT NULL DEFAULT false,
  customer_muted        boolean NOT NULL DEFAULT false,
  vendor_last_read_at    timestamptz,
  customer_last_read_at   timestamptz,
  -- vendor blocked this customer from messaging in this conversation
  blocked_by_vendor     boolean NOT NULL DEFAULT false,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at           timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_conversations_business ON public.conversations(business_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_conversations_customer_user ON public.conversations(customer_user_id, updated_at DESC);
-- One booking conversation per appointment.
CREATE UNIQUE INDEX IF NOT EXISTS uq_conversations_appointment
  ON public.conversations(appointment_id) WHERE appointment_id IS NOT NULL;
-- One enquiry conversation per (business, customer user).
CREATE UNIQUE INDEX IF NOT EXISTS uq_conversations_enquiry
  ON public.conversations(business_id, customer_user_id)
  WHERE type = 'enquiry' AND customer_user_id IS NOT NULL;

ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;

-- Vendor (any active member of the business), customer (owner of the
-- contact row or the enquiry author), or an admin may read a conversation.
DROP POLICY IF EXISTS conversations_select ON public.conversations;
CREATE POLICY conversations_select ON public.conversations
  FOR SELECT USING (
    public.get_my_business_role(business_id) IS NOT NULL
    OR customer_user_id = (SELECT auth.uid())
    OR public.customer_owns_row(customer_id)
    OR public.is_admin()
  );

-- ── Messages ────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.messages (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id  uuid NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  sender_role      text NOT NULL CHECK (sender_role IN ('vendor','customer','system')),
  sender_user_id   uuid,                              -- null for system messages
  body             text NOT NULL,
  message_type     text NOT NULL DEFAULT 'text'
                     CHECK (message_type IN ('text','image','document','voice','location','system')),
  attachment_url   text,                              -- future: photos / docs / voice
  metadata         jsonb,                             -- future: location coords, etc.
  delivered_at     timestamptz,
  read_at          timestamptz,
  created_at       timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_messages_conversation ON public.messages(conversation_id, created_at);

ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

-- A message is visible to whoever can see its conversation.
DROP POLICY IF EXISTS messages_select ON public.messages;
CREATE POLICY messages_select ON public.messages
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.conversations c
      WHERE c.id = conversation_id
        AND (
          public.get_my_business_role(c.business_id) IS NOT NULL
          OR c.customer_user_id = (SELECT auth.uid())
          OR public.customer_owns_row(c.customer_id)
          OR public.is_admin()
        )
    )
  );

-- ── Reports + moderation audit log ──────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.conversation_reports (
  id               uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id  uuid NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  reporter_user_id uuid,
  reporter_role    text CHECK (reporter_role IN ('vendor','customer')),
  reason           text NOT NULL,
  details          text,
  status           text NOT NULL DEFAULT 'open'
                     CHECK (status IN ('open','reviewing','actioned','dismissed')),
  moderator_id     uuid,
  resolution       text,
  created_at       timestamptz NOT NULL DEFAULT now(),
  resolved_at      timestamptz
);
ALTER TABLE public.conversation_reports ENABLE ROW LEVEL SECURITY;
-- The reporter can see their own report; admins see all.
DROP POLICY IF EXISTS conversation_reports_select ON public.conversation_reports;
CREATE POLICY conversation_reports_select ON public.conversation_reports
  FOR SELECT USING (reporter_user_id = (SELECT auth.uid()) OR public.is_admin());

CREATE TABLE IF NOT EXISTS public.messaging_moderation_log (
  id                 uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id    uuid,
  target_user_id     uuid,
  target_business_id uuid,
  action             text NOT NULL,   -- 'warning' | 'suspend' | 'restrict' | 'reviewed' | 'dismissed' | 'reported'
  reason             text,
  actor_id           uuid,
  created_at         timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE public.messaging_moderation_log ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS messaging_moderation_log_select ON public.messaging_moderation_log;
CREATE POLICY messaging_moderation_log_select ON public.messaging_moderation_log
  FOR SELECT USING (public.is_admin());

-- ============================================================================
-- Helper: resolve the caller's side ('vendor' | 'customer') for a conversation.
-- Returns NULL if the caller is neither. Vendor membership wins if both.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.conversation_side(p_conversation_id uuid)
RETURNS text
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_conv  RECORD;
  v_uid   uuid := (SELECT auth.uid());
BEGIN
  SELECT * INTO v_conv FROM public.conversations WHERE id = p_conversation_id;
  IF NOT FOUND OR v_uid IS NULL THEN RETURN NULL; END IF;
  IF public.get_my_business_role(v_conv.business_id) IS NOT NULL THEN
    RETURN 'vendor';
  END IF;
  IF v_conv.customer_user_id = v_uid OR public.customer_owns_row(v_conv.customer_id) THEN
    RETURN 'customer';
  END IF;
  RETURN NULL;
END;
$$;

-- ============================================================================
-- Guard: is this caller allowed to send right now?  Raises on violation.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.assert_can_message(p_conversation_id uuid, p_side text)
RETURNS void
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_conv  RECORD;
  v_uid   uuid := (SELECT auth.uid());
  v_priv  RECORD;
BEGIN
  SELECT c.*, b.messaging_enabled
    INTO v_conv
    FROM public.conversations c
    JOIN public.businesses b ON b.id = c.business_id
   WHERE c.id = p_conversation_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'conversation not found'; END IF;
  IF NOT v_conv.messaging_enabled THEN RAISE EXCEPTION 'messaging_disabled'; END IF;
  IF v_conv.blocked_by_vendor AND p_side = 'customer' THEN
    RAISE EXCEPTION 'messaging_blocked';
  END IF;
  SELECT * INTO v_priv FROM public.messaging_privileges WHERE user_id = v_uid;
  IF FOUND AND (v_priv.permanently_restricted
       OR (v_priv.suspended_until IS NOT NULL AND v_priv.suspended_until > now())) THEN
    RAISE EXCEPTION 'messaging_suspended';
  END IF;
END;
$$;

-- ============================================================================
-- get_or_create_conversation -- customer side. Enquiry (no appointment) or
-- returns the existing booking conversation for an appointment.
-- ============================================================================
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
    -- Booking conversation is created by trigger; return it (create if missing).
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

-- ============================================================================
-- send_message
-- ============================================================================
CREATE OR REPLACE FUNCTION public.send_message(
  p_conversation_id uuid,
  p_body            text,
  p_message_type    text DEFAULT 'text'
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_uid    uuid := (SELECT auth.uid());
  v_side   text := public.conversation_side(p_conversation_id);
  v_id     uuid;
  v_preview text;
BEGIN
  IF v_side IS NULL THEN RAISE EXCEPTION 'not authorized'; END IF;
  IF p_body IS NULL OR btrim(p_body) = '' THEN RAISE EXCEPTION 'empty message'; END IF;
  IF p_message_type NOT IN ('text','image','document','voice','location') THEN
    RAISE EXCEPTION 'invalid message type';
  END IF;
  PERFORM public.assert_can_message(p_conversation_id, v_side);

  INSERT INTO public.messages (conversation_id, sender_role, sender_user_id, body, message_type)
  VALUES (p_conversation_id, v_side, v_uid, btrim(p_body), p_message_type)
  RETURNING id INTO v_id;

  v_preview := left(btrim(p_body), 140);
  UPDATE public.conversations SET
    last_message_at      = now(),
    last_message_preview = v_preview,
    last_message_sender  = v_side,
    updated_at           = now(),
    -- sending clears your own unread + un-archives your side
    vendor_last_read_at   = CASE WHEN v_side = 'vendor'   THEN now() ELSE vendor_last_read_at END,
    customer_last_read_at = CASE WHEN v_side = 'customer' THEN now() ELSE customer_last_read_at END,
    vendor_archived   = CASE WHEN v_side = 'vendor'   THEN false ELSE vendor_archived END,
    customer_archived = CASE WHEN v_side = 'customer' THEN false ELSE customer_archived END
  WHERE id = p_conversation_id;

  RETURN v_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.send_message(uuid, text, text) TO authenticated;

-- ============================================================================
-- mark_conversation_read -- clears unread for the caller's side + stamps
-- read_at on the other side's messages (read receipts).
-- ============================================================================
CREATE OR REPLACE FUNCTION public.mark_conversation_read(p_conversation_id uuid)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_side text := public.conversation_side(p_conversation_id);
BEGIN
  IF v_side IS NULL THEN RAISE EXCEPTION 'not authorized'; END IF;

  UPDATE public.conversations SET
    vendor_last_read_at   = CASE WHEN v_side = 'vendor'   THEN now() ELSE vendor_last_read_at END,
    customer_last_read_at = CASE WHEN v_side = 'customer' THEN now() ELSE customer_last_read_at END
  WHERE id = p_conversation_id;

  UPDATE public.messages SET read_at = now(), delivered_at = COALESCE(delivered_at, now())
  WHERE conversation_id = p_conversation_id
    AND sender_role <> v_side
    AND read_at IS NULL;
END;
$$;
GRANT EXECUTE ON FUNCTION public.mark_conversation_read(uuid) TO authenticated;

-- ============================================================================
-- set_conversation_flag -- per-side mute / archive.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.set_conversation_flag(
  p_conversation_id uuid,
  p_mute            boolean DEFAULT NULL,
  p_archive         boolean DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_side text := public.conversation_side(p_conversation_id);
BEGIN
  IF v_side IS NULL THEN RAISE EXCEPTION 'not authorized'; END IF;
  UPDATE public.conversations SET
    vendor_muted      = CASE WHEN v_side='vendor'   AND p_mute    IS NOT NULL THEN p_mute    ELSE vendor_muted END,
    customer_muted    = CASE WHEN v_side='customer' AND p_mute    IS NOT NULL THEN p_mute    ELSE customer_muted END,
    vendor_archived   = CASE WHEN v_side='vendor'   AND p_archive IS NOT NULL THEN p_archive ELSE vendor_archived END,
    customer_archived = CASE WHEN v_side='customer' AND p_archive IS NOT NULL THEN p_archive ELSE customer_archived END
  WHERE id = p_conversation_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.set_conversation_flag(uuid, boolean, boolean) TO authenticated;

-- ============================================================================
-- set_conversation_blocked -- vendor (OWNER/ADMIN) blocks a customer from
-- messaging in this conversation.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.set_conversation_blocked(
  p_conversation_id uuid,
  p_blocked         boolean
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_biz uuid;
BEGIN
  SELECT business_id INTO v_biz FROM public.conversations WHERE id = p_conversation_id;
  IF v_biz IS NULL THEN RAISE EXCEPTION 'conversation not found'; END IF;
  IF public.get_my_business_role(v_biz) NOT IN ('OWNER','ADMIN') THEN
    RAISE EXCEPTION 'not authorized';
  END IF;
  UPDATE public.conversations SET blocked_by_vendor = p_blocked, updated_at = now()
  WHERE id = p_conversation_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.set_conversation_blocked(uuid, boolean) TO authenticated;

-- ============================================================================
-- report_conversation -- either side reports; logged for moderation.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.report_conversation(
  p_conversation_id uuid,
  p_reason          text,
  p_details         text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_uid  uuid := (SELECT auth.uid());
  v_side text := public.conversation_side(p_conversation_id);
  v_id   uuid;
BEGIN
  IF v_side IS NULL THEN RAISE EXCEPTION 'not authorized'; END IF;
  IF p_reason IS NULL OR btrim(p_reason) = '' THEN RAISE EXCEPTION 'reason required'; END IF;

  INSERT INTO public.conversation_reports (conversation_id, reporter_user_id, reporter_role, reason, details)
  VALUES (p_conversation_id, v_uid, v_side, btrim(p_reason), p_details)
  RETURNING id INTO v_id;

  INSERT INTO public.messaging_moderation_log (conversation_id, actor_id, action, reason)
  VALUES (p_conversation_id, v_uid, 'reported', btrim(p_reason));

  RETURN v_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.report_conversation(uuid, text, text) TO authenticated;

-- ============================================================================
-- set_business_messaging_settings -- OWNER/ADMIN toggles.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.set_business_messaging_settings(
  p_business_id  uuid,
  p_enabled      boolean DEFAULT NULL,
  p_pre_booking  boolean DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF public.get_my_business_role(p_business_id) NOT IN ('OWNER','ADMIN') THEN
    RAISE EXCEPTION 'not authorized';
  END IF;
  UPDATE public.businesses SET
    messaging_enabled = COALESCE(p_enabled, messaging_enabled),
    pre_booking_messaging_enabled = COALESCE(p_pre_booking, pre_booking_messaging_enabled),
    updated_at = now()
  WHERE id = p_business_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.set_business_messaging_settings(uuid, boolean, boolean) TO authenticated;

-- ============================================================================
-- unread_conversation_count -- total conversations with unread inbound for
-- the caller (used for the nav badge). Cheap: compares last_message_at with
-- the caller's side last_read_at.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.unread_conversation_count()
RETURNS integer
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public
AS $$
  SELECT count(*)::int FROM public.conversations c
  WHERE c.last_message_at IS NOT NULL
    AND (
      -- vendor side
      (public.get_my_business_role(c.business_id) IS NOT NULL
        AND c.last_message_sender <> 'vendor'
        AND c.vendor_archived = false
        AND (c.vendor_last_read_at IS NULL OR c.last_message_at > c.vendor_last_read_at))
      OR
      -- customer side
      ((c.customer_user_id = (SELECT auth.uid()) OR public.customer_owns_row(c.customer_id))
        AND c.last_message_sender <> 'customer'
        AND c.customer_archived = false
        AND (c.customer_last_read_at IS NULL OR c.last_message_at > c.customer_last_read_at))
    );
$$;
GRANT EXECUTE ON FUNCTION public.unread_conversation_count() TO authenticated;

-- ============================================================================
-- Admin moderation RPCs (for the web dashboard).
-- ============================================================================
CREATE OR REPLACE FUNCTION public.admin_set_messaging_suspension(
  p_user_id     uuid,
  p_until       timestamptz DEFAULT NULL,
  p_permanent   boolean DEFAULT false,
  p_reason      text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'not authorized'; END IF;
  INSERT INTO public.messaging_privileges (user_id, suspended_until, permanently_restricted, reason, updated_at)
  VALUES (p_user_id, p_until, COALESCE(p_permanent, false), p_reason, now())
  ON CONFLICT (user_id) DO UPDATE SET
    suspended_until = EXCLUDED.suspended_until,
    permanently_restricted = EXCLUDED.permanently_restricted,
    reason = EXCLUDED.reason,
    updated_at = now();
  INSERT INTO public.messaging_moderation_log (target_user_id, actor_id, action, reason)
  VALUES (p_user_id, (SELECT auth.uid()),
          CASE WHEN p_permanent THEN 'restrict' ELSE 'suspend' END, p_reason);
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_set_messaging_suspension(uuid, timestamptz, boolean, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_resolve_report(
  p_report_id  uuid,
  p_status     text,
  p_resolution text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_conv uuid;
BEGIN
  IF NOT public.is_admin() THEN RAISE EXCEPTION 'not authorized'; END IF;
  IF p_status NOT IN ('reviewing','actioned','dismissed') THEN
    RAISE EXCEPTION 'invalid status';
  END IF;
  UPDATE public.conversation_reports SET
    status = p_status,
    resolution = p_resolution,
    moderator_id = (SELECT auth.uid()),
    resolved_at = CASE WHEN p_status IN ('actioned','dismissed') THEN now() ELSE resolved_at END
  WHERE id = p_report_id
  RETURNING conversation_id INTO v_conv;

  INSERT INTO public.messaging_moderation_log (conversation_id, actor_id, action, reason)
  VALUES (v_conv, (SELECT auth.uid()),
          CASE p_status WHEN 'dismissed' THEN 'dismissed' ELSE 'reviewed' END, p_resolution);
END;
$$;
GRANT EXECUTE ON FUNCTION public.admin_resolve_report(uuid, text, text) TO authenticated;

-- ============================================================================
-- Trigger: auto-create a booking conversation when an appointment is made
-- (only if the business has messaging enabled).
-- ============================================================================
CREATE OR REPLACE FUNCTION public.create_booking_conversation()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_enabled boolean;
  v_user    uuid;
BEGIN
  SELECT messaging_enabled INTO v_enabled FROM public.businesses WHERE id = NEW.business_id;
  IF NOT COALESCE(v_enabled, false) THEN RETURN NEW; END IF;

  SELECT user_id INTO v_user FROM public.customers WHERE id = NEW.customer_id;

  INSERT INTO public.conversations (business_id, customer_id, customer_user_id,
      customer_display_name, appointment_id, type)
  VALUES (NEW.business_id, NEW.customer_id, v_user,
      COALESCE(NULLIF(btrim(NEW.customer_name), ''), 'Customer'), NEW.id, 'booking')
  ON CONFLICT (appointment_id) WHERE appointment_id IS NOT NULL DO NOTHING;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_create_booking_conversation ON public.appointments;
CREATE TRIGGER trg_create_booking_conversation
  AFTER INSERT ON public.appointments
  FOR EACH ROW EXECUTE FUNCTION public.create_booking_conversation();

-- ============================================================================
-- Realtime: publish conversations + messages so clients can .stream() them.
-- ============================================================================
DO $$
BEGIN
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.conversations;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;
END $$;
