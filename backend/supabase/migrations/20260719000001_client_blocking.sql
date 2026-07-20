-- ================================================================
-- ShoriBooks -- vendor client blocking.
-- A vendor can block an individual customer from making FUTURE bookings
-- with their business only (never affects other businesses). Existing
-- appointments are untouched. All block/unblock actions are audit-logged.
--
--  - customers.is_blocked / blocked_reason / blocked_at  (per-business row)
--  - customer_block_log                                  (audit trail)
--  - set_customer_blocked(...)  RPC   -> OWNER/ADMIN only, writes the log
--  - check_customer_blocked(...) RPC  -> pre-check for a polite message
--  - trg_reject_blocked_customer      -> authoritative BEFORE INSERT guard
-- Additive + idempotent.
-- ================================================================

ALTER TABLE public.customers
  ADD COLUMN IF NOT EXISTS is_blocked boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS blocked_reason text,
  ADD COLUMN IF NOT EXISTS blocked_at timestamptz;

CREATE TABLE IF NOT EXISTS public.customer_block_log (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  customer_id uuid NOT NULL REFERENCES public.customers(id) ON DELETE CASCADE,
  action      text NOT NULL CHECK (action IN ('blocked', 'unblocked')),
  reason      text,
  actor_id    uuid,
  created_at  timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.customer_block_log ENABLE ROW LEVEL SECURITY;

-- Members of the business can read its block log.
DROP POLICY IF EXISTS customer_block_log_select ON public.customer_block_log;
CREATE POLICY customer_block_log_select ON public.customer_block_log
  FOR SELECT USING (
    business_id IN (
      SELECT business_id FROM public.business_members
      WHERE user_id = auth.uid() AND status = 'ACTIVE'
    )
  );

-- Block / unblock a customer. OWNER/ADMIN of that customer's business only.
CREATE OR REPLACE FUNCTION public.set_customer_blocked(
  p_customer_id uuid,
  p_blocked     boolean,
  p_reason      text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid      uuid := auth.uid();
  v_business uuid;
  v_role     text;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'authentication required';
  END IF;

  SELECT business_id INTO v_business FROM public.customers WHERE id = p_customer_id;
  IF v_business IS NULL THEN
    RAISE EXCEPTION 'customer not found';
  END IF;

  SELECT role INTO v_role FROM public.business_members
  WHERE user_id = v_uid AND business_id = v_business AND status = 'ACTIVE';
  IF v_role IS DISTINCT FROM 'OWNER' AND v_role IS DISTINCT FROM 'ADMIN' THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  UPDATE public.customers
  SET is_blocked     = p_blocked,
      blocked_reason = CASE WHEN p_blocked THEN NULLIF(btrim(COALESCE(p_reason, '')), '') ELSE NULL END,
      blocked_at     = CASE WHEN p_blocked THEN now() ELSE NULL END,
      updated_at     = now()
  WHERE id = p_customer_id;

  INSERT INTO public.customer_block_log (business_id, customer_id, action, reason, actor_id)
  VALUES (
    v_business,
    p_customer_id,
    CASE WHEN p_blocked THEN 'blocked' ELSE 'unblocked' END,
    NULLIF(btrim(COALESCE(p_reason, '')), ''),
    v_uid
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.set_customer_blocked(uuid, boolean, text) TO authenticated;

-- Lightweight pre-check so the app can show a polite message before a guest
-- even tries to book (anon-callable; matches by phone within the business).
CREATE OR REPLACE FUNCTION public.check_customer_blocked(
  p_business_id uuid,
  p_phone       text
)
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT COALESCE(bool_or(is_blocked), false)
  FROM public.customers
  WHERE business_id = p_business_id
    AND regexp_replace(phone, '[^0-9]', '', 'g') =
        regexp_replace(p_phone, '[^0-9]', '', 'g');
$$;

GRANT EXECUTE ON FUNCTION public.check_customer_blocked(uuid, text) TO anon, authenticated;

-- Authoritative guard: no appointment may be inserted for a blocked customer,
-- regardless of which code path attempts it.
CREATE OR REPLACE FUNCTION public.reject_blocked_customer()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.customer_id IS NOT NULL
     AND EXISTS (SELECT 1 FROM public.customers
                 WHERE id = NEW.customer_id AND is_blocked) THEN
    RAISE EXCEPTION 'customer_blocked'
      USING ERRCODE = 'P0001',
            HINT = 'This customer is blocked from booking with this business.';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_reject_blocked_customer ON public.appointments;
CREATE TRIGGER trg_reject_blocked_customer
  BEFORE INSERT ON public.appointments
  FOR EACH ROW EXECUTE FUNCTION public.reject_blocked_customer();
