# Backend additions for the BetterBooking mobile app

These files are **not applied automatically** — they were written without access to your live
Supabase project. Review them, then apply to the same Supabase project the web app uses.

## Contents

- `supabase/migrations/20260710000000_mobile_app_support.sql` — additive SQL: a `status` column
  on `business_members`, `mark_membership_active()`, `create_appointment_safe()`, a booking
  overlap `EXCLUDE` constraint, and `get_business_report_summary()`. Does not modify or drop
  anything that exists today. Backs the Owner/Staff mode of the app.
- `supabase/migrations/20260710000001_customer_marketplace_support.sql` — additive SQL for the
  customer/marketplace mode: a `user_id` column on `customers` (links a business-scoped contact
  record to a real login identity), self-select/update RLS on `customers`, anon-read grants on
  `staff_availability`/`staff_breaks`, `get_blocked_time_ranges()`/`get_booked_appointment_ranges()`
  (let the app compute free slots client-side without exposing sensitive fields), a
  `customer_owns_row()` helper + read-only booking-history RLS on `appointments`, a new
  `customer_favorites` table, and `create_customer_appointment_safe()` /
  `cancel_own_appointment()` / `reschedule_own_appointment()`. Requires
  `20260710000000_mobile_app_support.sql` already applied. Does not modify or drop anything
  that exists today.
- `supabase/functions/invite-staff/index.ts` — a Deno Edge Function that lets an OWNER/ADMIN
  invite a teammate by email.

## How to apply

1. Copy `supabase/migrations/...sql` (both files) and `supabase/functions/invite-staff/` into
   the `ShoriSolutions/BetterBooking` repo's own `supabase/` folder (its migrations folder is
   missing the base schema for `profiles`/`entrepreneur_profiles`/`handle_updated_at`, so make
   sure those already exist in your live project — these migrations assume the full existing
   migration set, `20260702000000` through `20260702000009`, is already applied).
2. Apply the migrations, in order (`20260710000000` before `20260710000001`):
   - Easiest: paste each SQL file's contents into the Supabase Dashboard → SQL Editor → Run.
   - Or, with the Supabase CLI linked to your project: `supabase db push`.
3. Deploy the Edge Function:
   ```
   supabase functions deploy invite-staff
   supabase secrets set MOBILE_APP_DEEP_LINK=shoribook://auth/callback
   ```
   `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_SERVICE_ROLE_KEY` are auto-injected by the
   Supabase platform for Edge Functions — you don't need to set them yourself unless your CLI
   setup requires it explicitly.
4. In Supabase Dashboard → Authentication → URL Configuration, add `shoribook://auth/callback`
   to the redirect URL allow-list (required for invite/reset-password emails to open the app).

## Known gaps this does not fix

`appointments` SELECT/UPDATE have no per-role RLS restriction — any business member (including
STAFF) can technically read every other staff member's appointments/revenue via a direct API
call, and update any column on an appointment they can see. This mirrors the web app's existing
posture (enforced only in its UI, not RLS), so the mobile app doesn't regress anything — but it's
worth hardening later with role-scoped or column-level policies. Not changed here since it goes
beyond what was asked and could affect the live web app's behavior.

A customer's booking history for a service/staff member the business later deactivates will show
a blank name in the app (the `services`/`staff_profiles` RLS a non-member sees only covers
`is_active = true` rows, and `appointments` has no name-snapshot columns). The Flutter app falls
back to a placeholder label for this case; a proper fix would add snapshot columns to
`appointments`, which is a bigger, separate change not included here.
