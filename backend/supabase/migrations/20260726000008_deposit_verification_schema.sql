-- ================================================================
-- Shorivo -- Deposit Verification Flow (FirstPay) Phase 1: schema.
--
-- Customers submit proof of an out-of-band deposit; the business approves or
-- rejects it, which confirms or holds the booking. This migration is the data
-- model + storage; the logic (submit/approve/reject/expire) is in the next one.
--
-- Reuses the FirstPay payment_profiles (Step 2 shows those details), the
-- deposit tier/FirstPay gate, and the waitlist notify-on-free trigger (fires
-- when an expired deposit cancels a slot). Additive + idempotent. ASCII only.
-- ================================================================

-- 1. Appointment: awaiting-deposit state + a submission deadline -------------
ALTER TABLE public.appointments
  ADD COLUMN IF NOT EXISTS deposit_deadline TIMESTAMPTZ;

DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN
    SELECT conname FROM pg_constraint
    WHERE conrelid = 'public.appointments'::regclass
      AND contype = 'c'
      AND pg_get_constraintdef(oid) ILIKE '%status%'
      AND pg_get_constraintdef(oid) ILIKE '%confirmed%'
  LOOP
    EXECUTE format('ALTER TABLE public.appointments DROP CONSTRAINT %I', r.conname);
  END LOOP;
  ALTER TABLE public.appointments
    ADD CONSTRAINT appointments_status_check
    CHECK (status IN (
      'pending', 'confirmed', 'completed', 'cancelled', 'no_show',
      'pending_confirmation', 'pending_deposit'
    ));
END $$;

-- 2. Business-level deposit settings ----------------------------------------
ALTER TABLE public.businesses
  ADD COLUMN IF NOT EXISTS deposit_expiry_minutes       INT,  -- null = no auto-expiry
  ADD COLUMN IF NOT EXISTS require_deposit_all_services BOOLEAN NOT NULL DEFAULT false;

-- 3. Deposit submissions -----------------------------------------------------
CREATE TABLE IF NOT EXISTS public.deposit_submissions (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  appointment_id   UUID NOT NULL REFERENCES public.appointments(id) ON DELETE CASCADE,
  business_id      UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  user_id          UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- null for guests
  amount           NUMERIC,
  currency         TEXT,
  proof_path       TEXT,   -- path in the deposit-proofs storage bucket
  reference_number TEXT,
  customer_notes   TEXT,
  -- submitted | approved | rejected | expired | superseded
  status           TEXT NOT NULL DEFAULT 'submitted',
  reject_reason    TEXT,
  reject_notes     TEXT,
  reviewed_by      UUID,
  reviewed_at      TIMESTAMPTZ,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_deposit_sub_business_status
  ON public.deposit_submissions(business_id, status);
CREATE INDEX IF NOT EXISTS idx_deposit_sub_appointment
  ON public.deposit_submissions(appointment_id);
ALTER TABLE public.deposit_submissions ENABLE ROW LEVEL SECURITY;

-- The business (OWNER/ADMIN) sees submissions to their business; the customer
-- sees their own; admins see all. Writes go through the RPCs / edge function.
DROP POLICY IF EXISTS "deposit_sub_read" ON public.deposit_submissions;
CREATE POLICY "deposit_sub_read" ON public.deposit_submissions
  FOR SELECT TO authenticated
  USING (
    public.get_my_business_role(business_id) IN ('OWNER', 'ADMIN')
    OR user_id = (SELECT auth.uid())
    OR public.is_admin()
  );
GRANT SELECT ON public.deposit_submissions TO authenticated;

-- 4. Audit log (approve / reject / expire / submit) -------------------------
CREATE TABLE IF NOT EXISTS public.deposit_audit_log (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id   UUID NOT NULL REFERENCES public.businesses(id) ON DELETE CASCADE,
  appointment_id UUID REFERENCES public.appointments(id) ON DELETE SET NULL,
  submission_id UUID REFERENCES public.deposit_submissions(id) ON DELETE SET NULL,
  action        TEXT NOT NULL,  -- submitted | approved | rejected | expired
  reason        TEXT,
  notes         TEXT,
  actor_id      UUID,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE public.deposit_audit_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "deposit_audit_read" ON public.deposit_audit_log;
CREATE POLICY "deposit_audit_read" ON public.deposit_audit_log
  FOR SELECT TO authenticated
  USING (
    public.get_my_business_role(business_id) IN ('OWNER', 'ADMIN')
    OR public.is_admin()
  );
GRANT SELECT ON public.deposit_audit_log TO authenticated;

-- 5. Proof-of-payment storage (private) -------------------------------------
-- Files live under "<business_id>/<appointment_id>/<random>.<ext>". Businesses
-- read their own; the (authed) customer reads/writes their own appointment's.
-- Guest uploads go through an Edge Function (service role) -- see Phase 2.
INSERT INTO storage.buckets (id, name, public)
VALUES ('deposit-proofs', 'deposit-proofs', false)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "deposit_proofs_business_read" ON storage.objects;
CREATE POLICY "deposit_proofs_business_read" ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'deposit-proofs'
    AND public.get_my_business_role(((storage.foldername(name))[1])::uuid) IS NOT NULL
  );

DROP POLICY IF EXISTS "deposit_proofs_customer_read" ON storage.objects;
CREATE POLICY "deposit_proofs_customer_read" ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'deposit-proofs'
    AND EXISTS (
      SELECT 1 FROM public.appointments a
      JOIN public.customers c ON c.id = a.customer_id
      WHERE a.id = ((storage.foldername(name))[2])::uuid
        AND c.user_id = (SELECT auth.uid())
    )
  );

DROP POLICY IF EXISTS "deposit_proofs_customer_insert" ON storage.objects;
CREATE POLICY "deposit_proofs_customer_insert" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'deposit-proofs'
    AND EXISTS (
      SELECT 1 FROM public.appointments a
      JOIN public.customers c ON c.id = a.customer_id
      WHERE a.id = ((storage.foldername(name))[2])::uuid
        AND c.user_id = (SELECT auth.uid())
    )
  );
