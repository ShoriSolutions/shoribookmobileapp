-- ================================================================
-- Shorivo -- vendor toggle for after-hours messaging.
--
-- The app closes the customer composer ("<Business> is closed right now")
-- whenever the business is outside its opening hours. Some vendors want
-- that; others are happy to be messaged anytime. This adds a per-business
-- toggle, defaulting to the existing (restricted) behaviour, applied to
-- BOTH conversation types -- pre-booking enquiries and booking chats.
-- Additive + idempotent.
-- ================================================================

ALTER TABLE public.businesses
  ADD COLUMN IF NOT EXISTS messaging_restrict_after_hours boolean NOT NULL DEFAULT true;

-- Replace (not just CREATE OR REPLACE) so the old 3-arg overload doesn't
-- linger and make 3-arg calls ambiguous against the new 4-arg signature.
DROP FUNCTION IF EXISTS public.set_business_messaging_settings(uuid, boolean, boolean);

CREATE OR REPLACE FUNCTION public.set_business_messaging_settings(
  p_business_id          uuid,
  p_enabled              boolean DEFAULT NULL,
  p_pre_booking          boolean DEFAULT NULL,
  p_restrict_after_hours boolean DEFAULT NULL
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
    messaging_restrict_after_hours = COALESCE(p_restrict_after_hours, messaging_restrict_after_hours),
    updated_at = now()
  WHERE id = p_business_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.set_business_messaging_settings(uuid, boolean, boolean, boolean) TO authenticated;
