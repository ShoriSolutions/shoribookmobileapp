-- ================================================================
-- Shorivo -- fix booking failing with "record already exists" (23505).
--
-- The AFTER INSERT trigger create_booking_conversation() inserted a NEW
-- 'booking' conversation per appointment with ON CONFLICT (appointment_id).
-- After 20260807000000 unified messaging to ONE conversation per customer
-- (unique index uq_conversations_customer on business_id, customer_user_id),
-- a repeat customer's booking hit that index -- which the ON CONFLICT didn't
-- cover -- so the whole booking INSERT aborted with 23505.
--
-- Fix: make the trigger reuse the customer's single thread (update its
-- appointment context) instead of inserting a second one. Walk-ins with no
-- account (customer_user_id IS NULL) keep a per-appointment thread, since the
-- one-per-customer index is partial on customer_user_id IS NOT NULL.
--
-- Idempotent. Run manually.
-- ================================================================

CREATE OR REPLACE FUNCTION public.create_booking_conversation()
RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_enabled boolean;
  v_user    uuid;
  v_conv    uuid;
  v_name    text;
BEGIN
  SELECT messaging_enabled INTO v_enabled
    FROM public.businesses WHERE id = NEW.business_id;
  IF NOT COALESCE(v_enabled, false) THEN RETURN NEW; END IF;

  SELECT user_id INTO v_user FROM public.customers WHERE id = NEW.customer_id;
  v_name := COALESCE(NULLIF(btrim(NEW.customer_name), ''), 'Customer');

  IF v_user IS NOT NULL THEN
    -- One thread per customer: reuse the existing conversation if there is one.
    SELECT id INTO v_conv
    FROM public.conversations
    WHERE business_id = NEW.business_id AND customer_user_id = v_user
    ORDER BY created_at, id
    LIMIT 1;

    IF v_conv IS NOT NULL THEN
      UPDATE public.conversations
      SET appointment_id    = NEW.id,
          type              = 'booking',
          customer_id       = COALESCE(customer_id, NEW.customer_id),
          customer_archived = false,
          updated_at        = now()
      WHERE id = v_conv;
      RETURN NEW;
    END IF;

    -- None yet -- create it; DO UPDATE guards against a concurrent insert.
    INSERT INTO public.conversations (business_id, customer_id, customer_user_id,
        customer_display_name, appointment_id, type)
    VALUES (NEW.business_id, NEW.customer_id, v_user, v_name, NEW.id, 'booking')
    ON CONFLICT (business_id, customer_user_id) WHERE customer_user_id IS NOT NULL
    DO UPDATE SET appointment_id = EXCLUDED.appointment_id,
                  type = 'booking',
                  customer_archived = false,
                  updated_at = now();
    RETURN NEW;
  END IF;

  -- No account (walk-in): keep a per-appointment thread.
  INSERT INTO public.conversations (business_id, customer_id, customer_user_id,
      customer_display_name, appointment_id, type)
  VALUES (NEW.business_id, NEW.customer_id, NULL, v_name, NEW.id, 'booking')
  ON CONFLICT (appointment_id) WHERE appointment_id IS NOT NULL DO NOTHING;

  RETURN NEW;
END;
$$;

-- ================================================================
-- VERIFY: booking as a customer who already has a chat should now succeed,
-- and their appointment lands in the same single thread.
-- ================================================================
