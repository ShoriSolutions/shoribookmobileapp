-- ================================================================
-- ShoriBooks -- multiple job roles per staff member.
-- Adds staff_profiles.roles (text[]) alongside the legacy single `role`
-- column, and backfills existing single roles into the array. Roles are
-- free-form per business (Barber, Nail Tech, Receptionist, ...), a base
-- that future role-based permissions can build on. Additive + idempotent.
-- ================================================================

ALTER TABLE public.staff_profiles
  ADD COLUMN IF NOT EXISTS roles text[] NOT NULL DEFAULT '{}';

-- Backfill: seed the array from the existing single role where present.
UPDATE public.staff_profiles
SET roles = ARRAY[btrim(role)]
WHERE role IS NOT NULL
  AND btrim(role) <> ''
  AND (roles IS NULL OR array_length(roles, 1) IS NULL);
