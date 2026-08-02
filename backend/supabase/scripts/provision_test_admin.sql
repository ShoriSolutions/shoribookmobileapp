-- ================================================================
-- Shorivo -- provision a TEST account: platform admin + business OWNER with an
-- active Squad subscription. Creates the business + membership if the account
-- doesn't already own one (so it fixes the "No business found" screen too).
--
-- Target: mcdn2112@gmail.com (must already exist in Supabase Auth -- i.e. it
-- has signed in at least once; this cannot create the login itself).
--
-- Safe to re-run (idempotent). Only touches THIS user's profile and the
-- business it owns; never other users' data.
--
-- Run manually in the Supabase SQL editor (button says "Run", not "Run
-- selected"). NOT a numbered migration on purpose -- it is dev/test data.
-- Change the email on the first line of the block to target another account.
-- ================================================================

DO $$
DECLARE
  v_email TEXT := 'mcdn2112@gmail.com';   -- <-- target account
  v_uid   UUID;
  v_pkg   UUID;
  v_biz   UUID;
  v_slug  TEXT;
  v_base  TEXT := 'mcdn-test-business';
  v_n     INT  := 0;
BEGIN
  -- 1. Resolve the auth user (must have signed in at least once).
  SELECT id INTO v_uid FROM auth.users WHERE lower(email) = lower(v_email);
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'No auth user for % -- sign in with it once first.', v_email;
  END IF;

  -- 2. The Squad package (top tier, everything unlocked for testing).
  SELECT id INTO v_pkg FROM public.subscription_packages WHERE name = 'Squad' LIMIT 1;
  IF v_pkg IS NULL THEN
    RAISE EXCEPTION 'Squad package not found -- run 20260714000004_subscriptions.sql first.';
  END IF;

  -- 3. Find a business this user already OWNS (prefer an ACTIVE membership).
  SELECT b.id INTO v_biz
  FROM public.business_members m
  JOIN public.businesses b ON b.id = m.business_id
  WHERE m.user_id = v_uid AND m.role = 'OWNER'
  ORDER BY (m.status = 'ACTIVE') DESC
  LIMIT 1;

  -- 4. None? Create one (unique slug), matching register_business's columns.
  IF v_biz IS NULL THEN
    v_slug := v_base;
    WHILE EXISTS (SELECT 1 FROM public.businesses WHERE slug = v_slug) LOOP
      v_n := v_n + 1;
      v_slug := v_base || '-' || v_n;
    END LOOP;

    INSERT INTO public.businesses (id, owner_id, name, slug, category)
    VALUES (gen_random_uuid(), v_uid, 'MCDN Test Business', v_slug, 'Other')
    RETURNING id INTO v_biz;
  END IF;

  -- 5. Ensure an ACTIVE OWNER membership on that business.
  INSERT INTO public.business_members
    (id, business_id, user_id, role, status, created_at, updated_at)
  SELECT gen_random_uuid(), v_biz, v_uid, 'OWNER', 'ACTIVE', now(), now()
  WHERE NOT EXISTS (
    SELECT 1 FROM public.business_members
    WHERE business_id = v_biz AND user_id = v_uid
  );
  UPDATE public.business_members
     SET role = 'OWNER', status = 'ACTIVE', updated_at = now()
   WHERE business_id = v_biz AND user_id = v_uid;

  -- 6. Active Squad subscription (no paywall).
  UPDATE public.businesses
     SET subscription_status     = 'active',
         subscription_package_id = v_pkg,
         current_period_end      = now() + INTERVAL '10 years',
         updated_at              = now()
   WHERE id = v_biz;

  -- 7. Platform admin. role='admin' makes is_admin() true; combined with the
  --    OWNER membership above the app routes it to the business side.
  UPDATE public.profiles SET role = 'admin' WHERE id = v_uid;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'No profiles row for % (uid %) -- unexpected.', v_email, v_uid;
  END IF;

  RAISE NOTICE 'Done: % is admin + ACTIVE OWNER of business % with an active Squad subscription.',
               v_email, v_biz;
END $$;
