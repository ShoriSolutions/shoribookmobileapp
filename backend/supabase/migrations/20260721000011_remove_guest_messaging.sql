-- ================================================================
-- Shorivo -- remove guest messaging (require a real account to message).
--
-- Guests still browse and book (they may hold an anonymous session purely so
-- the marketplace is readable), but they can no longer contact vendors. The
-- app hides the messaging entry points from anonymous users; this is the
-- server-side backstop:
--   * a BEFORE INSERT trigger on messages rejects anonymous senders, so even
--     a booking conversation (auto-created for any booking) can't be messaged
--     by a guest.
--   * the guest booking-conversation claim RPC is dropped.
--
-- Real customers and vendors are unaffected. The booking-conversation
-- auto-create trigger still runs (it inserts a conversation, not a message).
-- Additive + idempotent.
-- ================================================================

CREATE OR REPLACE FUNCTION public.reject_anonymous_message()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  -- auth.jwt() carries is_anonymous=true for anonymous (guest) sessions.
  -- Null (e.g. service role / system inserts) is treated as allowed.
  IF COALESCE((auth.jwt() ->> 'is_anonymous')::boolean, false) THEN
    RAISE EXCEPTION 'account_required'
      USING HINT = 'Create an account to message businesses.';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_reject_anonymous_message ON public.messages;
CREATE TRIGGER trg_reject_anonymous_message
  BEFORE INSERT ON public.messages
  FOR EACH ROW EXECUTE FUNCTION public.reject_anonymous_message();

-- No longer used: guests don't claim booking conversations.
DROP FUNCTION IF EXISTS public.claim_guest_booking_conversation(uuid, text);
