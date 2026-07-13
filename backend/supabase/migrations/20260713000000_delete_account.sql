-- ================================================================
-- BetterBooking — Self-service account deletion
-- Adds delete_my_account(): a SECURITY DEFINER RPC that permanently
-- deletes the caller's account and everything they own, then removes
-- their auth identity. Irreversible.
--
-- Per product decision: deleting a business OWNER's account also deletes
-- the business and ALL its data. Child rows are deleted explicitly in
-- FK-safe order so this works regardless of ON DELETE settings.
--
-- The app guards this behind a typed "DELETE" confirmation AND an emailed
-- one-time code (Supabase Auth OTP) before ever calling it.
-- ================================================================

CREATE OR REPLACE FUNCTION public.delete_my_account()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID;
BEGIN
  v_uid := (SELECT auth.uid());
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'authentication required';
  END IF;

  -- ── Businesses owned by this user: wipe all their data ──────────────
  -- (owned = businesses.owner_id = caller)
  DELETE FROM public.appointments
    WHERE business_id IN (SELECT id FROM public.businesses WHERE owner_id = v_uid);

  DELETE FROM public.service_staff
    WHERE staff_profile_id IN (
      SELECT id FROM public.staff_profiles
      WHERE business_id IN (SELECT id FROM public.businesses WHERE owner_id = v_uid)
    );

  DELETE FROM public.staff_availability
    WHERE staff_id IN (
      SELECT id FROM public.staff_profiles
      WHERE business_id IN (SELECT id FROM public.businesses WHERE owner_id = v_uid)
    );

  DELETE FROM public.staff_breaks
    WHERE staff_id IN (
      SELECT id FROM public.staff_profiles
      WHERE business_id IN (SELECT id FROM public.businesses WHERE owner_id = v_uid)
    );

  DELETE FROM public.blocked_times
    WHERE business_id IN (SELECT id FROM public.businesses WHERE owner_id = v_uid);

  DELETE FROM public.special_business_days
    WHERE business_id IN (SELECT id FROM public.businesses WHERE owner_id = v_uid);

  DELETE FROM public.business_hours
    WHERE business_id IN (SELECT id FROM public.businesses WHERE owner_id = v_uid);

  DELETE FROM public.customer_favorites
    WHERE business_id IN (SELECT id FROM public.businesses WHERE owner_id = v_uid);

  DELETE FROM public.customers
    WHERE business_id IN (SELECT id FROM public.businesses WHERE owner_id = v_uid);

  DELETE FROM public.staff_profiles
    WHERE business_id IN (SELECT id FROM public.businesses WHERE owner_id = v_uid);

  DELETE FROM public.services
    WHERE business_id IN (SELECT id FROM public.businesses WHERE owner_id = v_uid);

  DELETE FROM public.business_members
    WHERE business_id IN (SELECT id FROM public.businesses WHERE owner_id = v_uid);

  DELETE FROM public.businesses WHERE owner_id = v_uid;

  -- ── This user's own records elsewhere ───────────────────────────────
  -- Memberships at businesses they don't own (staff/admin roles).
  DELETE FROM public.business_members WHERE user_id = v_uid;

  -- Their customer contact rows at OTHER businesses: unlink (keep the
  -- business's contact history) rather than delete.
  UPDATE public.customers SET user_id = NULL WHERE user_id = v_uid;

  -- Their favourites.
  DELETE FROM public.customer_favorites WHERE user_id = v_uid;

  -- Profile + auth identity.
  DELETE FROM public.profiles WHERE id = v_uid;
  DELETE FROM auth.users WHERE id = v_uid;
END;
$$;

GRANT EXECUTE ON FUNCTION public.delete_my_account() TO authenticated;
