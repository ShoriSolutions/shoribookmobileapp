-- ================================================================
-- Shorivo -- Deposit Verification Phase 3: business deposit settings RPC.
--
-- OWNER/ADMIN saves the auto-expiry window and the "require a deposit for all
-- services" flag (columns added in 20260726000008). Deposit amount/type stay
-- per-service (the service form). Additive + idempotent. ASCII only.
-- ================================================================

CREATE OR REPLACE FUNCTION public.save_deposit_settings(
  p_business_id     UUID,
  p_expiry_minutes  INT     DEFAULT NULL,  -- null = no auto-expiry
  p_require_all     BOOLEAN DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
BEGIN
  IF public.get_my_business_role(p_business_id) NOT IN ('OWNER', 'ADMIN')
     AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  UPDATE public.businesses SET
    deposit_expiry_minutes = CASE
      WHEN p_expiry_minutes IS NULL THEN NULL
      ELSE LEAST(10080, GREATEST(5, p_expiry_minutes))
    END,
    require_deposit_all_services =
      COALESCE(p_require_all, require_deposit_all_services),
    updated_at = now()
  WHERE id = p_business_id;
END;
$$;
GRANT EXECUTE ON FUNCTION public.save_deposit_settings(UUID, INT, BOOLEAN)
  TO authenticated;
