-- ================================================================
-- Shorivo -- provision a TEST account: platform admin + business owner
-- with an active Squad subscription.
--
-- Target: mcdn2112@gmail.com (must already exist in Supabase Auth and
-- already own a business -- this only adjusts role + subscription, it does
-- NOT create the login or the business).
--
-- Safe to re-run. Purely additive: it only touches THIS user's profile row
-- and the businesses THIS user owns. It never modifies anyone else's
-- membership, business, or subscription.
--
-- Run manually in the Supabase SQL editor (button says "Run", not "Run
-- selected"). NOT a numbered migration on purpose -- it is dev/test data.
--
-- To use a different account, change the email on the SELECT below.
-- ================================================================

DO $$
DECLARE
  v_email TEXT := 'mcdn2112@gmail.com';   -- <-- change to target another account
  v_uid   UUID;
  v_pkg   UUID;
  v_biz   INT;
BEGIN
  -- 1. Resolve the auth user (must have signed in at least once).
  SELECT id INTO v_uid FROM auth.users WHERE lower(email) = lower(v_email);
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'No auth user for % -- sign in with it once first.', v_email;
  END IF;

  -- 2. Platform admin. role='admin' makes is_admin() true; combined with an
  --    existing OWNER membership the app also routes it to the business side
  --    (app mode is resolved from membership for non-'entrepreneur' roles).
  UPDATE public.profiles SET role = 'admin' WHERE id = v_uid;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'No profiles row for % (uid %) -- unexpected.', v_email, v_uid;
  END IF;

  -- 3. Pick the top tier (Squad) so every feature is unlocked for testing.
  SELECT id INTO v_pkg FROM public.subscription_packages WHERE name = 'Squad' LIMIT 1;
  IF v_pkg IS NULL THEN
    RAISE EXCEPTION 'Squad package not found -- run 20260714000004_subscriptions.sql first.';
  END IF;

  -- 4. Give every business this user OWNS an active Squad subscription.
  UPDATE public.businesses b
  SET subscription_status     = 'active',
      subscription_package_id = v_pkg,
      current_period_end      = now() + INTERVAL '10 years',
      updated_at              = now()
  WHERE EXISTS (
    SELECT 1 FROM public.business_members m
    WHERE m.business_id = b.id
      AND m.user_id = v_uid
      AND m.role = 'OWNER'
      AND m.status = 'ACTIVE'
  );
  GET DIAGNOSTICS v_biz = ROW_COUNT;

  IF v_biz = 0 THEN
    RAISE NOTICE 'Set % to admin, but found no ACTIVE OWNER business to subscribe. '
                 'Open the app once (it self-heals the OWNER membership), then re-run.', v_email;
  ELSE
    RAISE NOTICE 'Done: % is now admin + owner with an active Squad subscription on % business(es).',
                 v_email, v_biz;
  END IF;
END $$;
