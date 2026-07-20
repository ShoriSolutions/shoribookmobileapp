# Feature notes — Subscription, Vendor Controls, Staff & UX

This document covers the services and extension points added for the
subscription / vendor-controls / staff-management / UX work, and calls out
what still needs backend or app-store configuration.

## Migrations to run (Supabase SQL editor, in order)

| File | Adds |
|---|---|
| `20260719000000_staff_roles.sql` | `staff_profiles.roles text[]` (+ backfill) |
| `20260719000001_client_blocking.sql` | `customers.is_blocked/blocked_reason/blocked_at`, `customer_block_log`, `set_customer_blocked` / `check_customer_blocked` RPCs, `trg_reject_blocked_customer` |
| `20260719000002_app_config_annual_discount.sql` | `app_config` table + `annual_discount_percent` (default 20) |
| `20260719000003_subscription_auto_renew.sql` | `businesses.auto_renew/billing_period/current_period_end`, `set_subscription_prefs` RPC |

All migrations are additive + idempotent. Run in the Supabase SQL editor
(make sure the button says **Run**, not "Run selected").

---

## What shipped (Flutter + Supabase, reusing existing services)

### Time-based greetings — `core/utils/greeting.dart`
`Greeting.full(name: 'Sarah')` → "Good morning, Sarah 👋" / "Working late,
Sarah? 🌙". Reusable anywhere; used on the vendor dashboard header.

### Staff → services assignment
`ServicesRepository.fetch/setAssignedStaff`; the "Offered by" picker on
Edit Service writes `service_staff`. The customer booking flow **already**
restricts pro selection to assigned staff (empty set = any active staff).

### Staff job roles (multiple)
`staff_profiles.roles text[]` + `StaffProfile.roles`. Editable on the staff
detail sheet (suggested chips in `_suggestedRoles` + custom add). **Extension
point:** future role-based permissions should read `roles` (the legacy single
`role` is kept in sync with `roles.first`).

### Vendor client blocking
`ClientsRepository.setBlocked` → `set_customer_blocked` RPC (OWNER/ADMIN,
audit-logged to `customer_block_log`). Enforced three ways:
1. `check_customer_blocked` pre-check in the booking controller (polite msg),
2. `trg_reject_blocked_customer` BEFORE INSERT trigger (authoritative),
3. per-business only — never affects other businesses.
UI: block/unblock + reason on the client profile, a blocked banner, and a
"Blocked" clients filter/badge.

### Monthly / annual billing
`app_config.annual_discount_percent` (configurable, no deploy) →
`annualDiscountPercentProvider` + `annualAmount(monthly, pct)`. The
subscription modal has a Monthly/Yearly toggle + a dynamic "Save X% with
annual billing" badge; `PricingCard` takes a `periodLabel` override.
**Extension point:** `app_config` is the home for future promo/coupon/referral
config values.

### Auto-renew controls
`businesses.auto_renew/billing_period/current_period_end` +
`set_subscription_prefs` RPC (OWNER/ADMIN). V17 Subscription screen has an
Auto-renew toggle; the dark card shows the renewal date; Cancel is present.

### Staff booking views
`calendarStaffFilterProvider` + a staff filter row on the calendar lets
owners/admins view one staff member's day. STAFF users are already scoped
to their own bookings at the query level (calendar + dashboard). Every
booking carries `staff_profile_id`.

---

## Needs backend / app-store work (not doable from app code alone)

### Subscription auto-renewal — the actual charge
`auto_renew` + dates are stored, but **charging on renewal is store-managed**
(auto-renewable IAP handles renewal/retry) or requires a payment-processor
(e.g. Stripe) Edge Function. To complete:
- **Store path:** create auto-renewable subscription products (monthly + a
  separate **annual** product per tier — the app currently only queries
  monthly product ids), and validate receipts in an Edge Function before
  granting entitlement (`SubscriptionRepository.recordPurchase` has a TODO).
- **Trial-ending reminders (7/3/1 day):** extend the existing
  `process-reminders` Edge Function to enqueue trial-expiry notices from
  `trial_ends_at`. The reminder plumbing already exists.
- **Failed-payment retry + graceful restriction:** the access gate already
  restricts on `hasActiveAccess`; a `past_due` grace window + retry schedule
  belongs in the billing Edge Function.

### Annual purchase via IAP
The Monthly/Yearly toggle computes/display annual pricing, and trial start
(no charge) works on either. Buying an **annual** plan needs annual store
product ids wired into `subscription_packages` + queried in the modal.

### Switch Accounts — true multi-session
Current "Switch account" re-authenticates (sign out → login) and lives in
**Account & security** / customer Profile. Keeping several accounts
simultaneously authenticated (guest + customer + vendor, no re-login) is a
larger change: Supabase GoTrue is single-session per client, so it needs
multiple `Gaclient`/session stores and a session-swap layer. Deferred to
avoid a risky auth refactor; the re-auth switch works today.

### Staff invites
`invite-staff` Edge Function exists in the repo but must be **deployed** with
an email provider key (`RESEND_API_KEY`) or invites hang.

---

## Future-compatibility hooks already in place
- **Roles** (`staff_profiles.roles`) → role-based permissions, payroll roles.
- **`app_config`** → promotions, coupons, referral configs without deploys.
- **`customer_block_log`** → audit pattern reusable for other moderation.
- **`billing_period` / `current_period_end`** → annual plans, proration.
- **`service_staff`** links → per-staff availability, commission by service.
- Every booking carries `staff_profile_id` → staff schedules, commission,
  team performance analytics, multi-location scoping (add `location_id`).
