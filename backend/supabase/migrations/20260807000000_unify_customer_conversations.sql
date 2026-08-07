-- ================================================================
-- Shorivo -- one chat per customer (unify conversations).
--
-- Before: get_or_create_conversation created a NEW 'booking' conversation for
-- each appointment_id, so a repeat customer ended up with several chats. This
-- unifies messaging to ONE conversation per (business_id, customer_user_id):
-- all of a customer's enquiries and bookings live in a single ongoing thread.
--
-- Steps:
--   A. Merge existing duplicate conversations into the earliest one per
--      customer (move their messages + reports), then delete the extras.
--   B. Add a uniqueness guard so only one conversation per customer can exist.
--   C. Rewrite get_or_create_conversation to find-or-create that single thread
--      (and point its appointment context at the most recent booking).
--
-- Note: the canonical thread keeps its own appointment_id; going forward the
-- RPC updates it to the latest booking. Historical booking context on merged
-- threads may shift to the latest appointment -- messages are always preserved.
--
-- Run manually. ASCII only.
-- ================================================================

-- ── A. Merge duplicates into the earliest conversation per customer ──────────

-- A1: move messages from duplicate threads onto the canonical (earliest) one.
WITH canon AS (
  SELECT id AS conv_id,
         first_value(id) OVER (
           PARTITION BY business_id, customer_user_id
           ORDER BY created_at, id
         ) AS canonical_id
  FROM public.conversations
  WHERE customer_user_id IS NOT NULL
)
UPDATE public.messages m
SET conversation_id = canon.canonical_id
FROM canon
WHERE m.conversation_id = canon.conv_id
  AND canon.conv_id <> canon.canonical_id;

-- A2: move any conversation reports onto the canonical thread too.
WITH canon AS (
  SELECT id AS conv_id,
         first_value(id) OVER (
           PARTITION BY business_id, customer_user_id
           ORDER BY created_at, id
         ) AS canonical_id
  FROM public.conversations
  WHERE customer_user_id IS NOT NULL
)
UPDATE public.conversation_reports r
SET conversation_id = canon.canonical_id
FROM canon
WHERE r.conversation_id = canon.conv_id
  AND canon.conv_id <> canon.canonical_id;

-- A3: delete the now-empty duplicate threads (keep the earliest per customer).
WITH ranked AS (
  SELECT id,
         row_number() OVER (
           PARTITION BY business_id, customer_user_id
           ORDER BY created_at, id
         ) AS rn
  FROM public.conversations
  WHERE customer_user_id IS NOT NULL
)
DELETE FROM public.conversations c
USING ranked
WHERE c.id = ranked.id AND ranked.rn > 1;

-- A4: recompute the surviving threads' last-message summary from their messages.
UPDATE public.conversations c
SET last_message_at     = lm.created_at,
    last_message_preview = left(lm.body, 140),
    last_message_sender  = lm.sender_role
FROM (
  SELECT DISTINCT ON (conversation_id)
         conversation_id, created_at, body, sender_role
  FROM public.messages
  ORDER BY conversation_id, created_at DESC
) lm
WHERE lm.conversation_id = c.id;

-- ── B. Uniqueness guard: one conversation per customer ──────────────────────
-- The enquiry-only partial index is superseded by the full one below.
DROP INDEX IF EXISTS public.uq_conversations_enquiry;
CREATE UNIQUE INDEX IF NOT EXISTS uq_conversations_customer
  ON public.conversations (business_id, customer_user_id)
  WHERE customer_user_id IS NOT NULL;

-- ── C. Rewrite the RPC to find-or-create the single thread ──────────────────
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

  SELECT * INTO v_biz FROM public.businesses WHERE id = p_business_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'business not found'; END IF;
  IF NOT v_biz.messaging_enabled THEN RAISE EXCEPTION 'messaging_disabled'; END IF;

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
    UPDATE public.conversations
    SET updated_at        = now(),
        customer_archived = false,
        customer_id       = COALESCE(customer_id, v_customer),
        appointment_id    = COALESCE(p_appointment_id, appointment_id),
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

GRANT EXECUTE ON FUNCTION public.get_or_create_conversation(uuid, uuid) TO authenticated;

-- ================================================================
-- VERIFY: each customer now has at most one row --
--   SELECT business_id, customer_user_id, count(*)
--   FROM public.conversations WHERE customer_user_id IS NOT NULL
--   GROUP BY 1,2 HAVING count(*) > 1;   -- expect 0 rows
-- Then in the app: message a business, book an appointment, message again --
-- all land in the same thread.
-- ================================================================
