-- ================================================================
-- BetterBooking — Customer profile editing.
-- Lets a signed-in user edit their own name, phone, and avatar. Email
-- is intentionally NOT editable here (changing it goes through support).
-- Additive; the trust-column guard trigger on profiles is unaffected
-- (this only writes full_name / phone / avatar_url).
-- ================================================================

-- Phone number on the profile (customers had no phone field before).
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS phone TEXT;

-- ── Public 'avatars' bucket ─────────────────────────────────────────────────
INSERT INTO storage.buckets (id, name, public)
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;

-- Anyone can read an avatar (they appear on public profiles); a user may
-- only write within their own folder ('<user_id>/...').
DROP POLICY IF EXISTS "avatars_read" ON storage.objects;
CREATE POLICY "avatars_read" ON storage.objects
  FOR SELECT USING (bucket_id = 'avatars');

DROP POLICY IF EXISTS "avatars_insert" ON storage.objects;
CREATE POLICY "avatars_insert" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "avatars_update" ON storage.objects;
CREATE POLICY "avatars_update" ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

DROP POLICY IF EXISTS "avatars_delete" ON storage.objects;
CREATE POLICY "avatars_delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'avatars'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- ── Self-service profile update ─────────────────────────────────────────────
-- Updates ONLY the caller's own name / phone / avatar. Email and role are
-- never touched here. A blank name is ignored (keeps the existing one); a
-- blank phone clears it; avatar_url is set as given (null removes the photo).
CREATE OR REPLACE FUNCTION public.update_my_profile(
  p_full_name  TEXT,
  p_phone      TEXT,
  p_avatar_url TEXT
)
RETURNS VOID
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'authentication required';
  END IF;
  UPDATE public.profiles SET
    full_name  = COALESCE(NULLIF(btrim(p_full_name), ''), full_name),
    phone      = NULLIF(btrim(COALESCE(p_phone, '')), ''),
    avatar_url = p_avatar_url,
    updated_at = now()
  WHERE id = v_uid;
END;
$$;
GRANT EXECUTE ON FUNCTION public.update_my_profile(TEXT, TEXT, TEXT) TO authenticated;
