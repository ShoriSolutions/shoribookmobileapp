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
| `20260719000004_annual_store_products.sql` | `subscription_packages.store_product_id_{ios,android}_annual` |
| `20260719000005_trial_reminder_log.sql` | `trial_reminder_log` (dedupe for trial-ending notices) |
| `20260720000000_appointment_customer_timezone.sql` | `appointments.customer_timezone` + write-once RPC |
| `20260720000001_set_business_timezone.sql` | `set_business_timezone` RPC (vendor picks business zone) |
| `20260720000002_admin_set_featured.sql` | `admin_set_featured` RPC |
| `20260720000003_guest_manage_booking.sql` | `cancel_guest_appointment` / `reschedule_guest_appointment` RPCs |
| `20260720000004_service_plan_limit.sql` | `subscription_packages.max_services` + service-cap trigger |
| `20260720000005_booking_staff_assignment_fix.sql` | booking allowed when a service has no staff assignments |
| `20260720000006_fix_reminder_channels_array.sql` | fixes "malformed array literal: push" blocking Save booking |
| `20260721000000_messaging_system.sql` | **messaging**: conversations, messages, reports, moderation log, privileges, business toggles, RLS, RPCs, realtime, auto-create trigger |
| `20260721000001_message_attachments.sql` | private `message-attachments` bucket + participant-scoped storage RLS; `send_message` extended with attachment + metadata |
| `20260721000002_push_tokens.sql` | `device_push_tokens` + `register_push_token`/`unregister_push_token` RPCs + `message_push_targets` helper (for push) |
| `20260721000003_message_email_notify.sql` | `message_email_log` + `claim_message_email_targets` RPC (decides who to email for messages) |
| `20260721000004_email_outbox.sql` | `email_outbox` + `claim_outbox_emails`/`mark_outbox_sent`/`mark_outbox_failed` (all email unified for Nodemailer) |
| `20260721000005_messaging_hours_toggle.sql` | `businesses.messaging_restrict_after_hours` (default true) + `set_business_messaging_settings` gains a 4th param |
| `20260721000006_guest_messaging.sql` | (superseded) `claim_guest_booking_conversation` RPC — dropped again in `20260721000011` |
| `20260721000007_fix_enquiry_upsert.sql` | fixes "no unique or exclusion constraint matching the ON CONFLICT" on "Ask a question" |
| `20260721000008_fix_profiles_rls.sql` | **security**: scopes `profiles` SELECT to owner+admin (was readable by any authenticated/anon user) |
| `20260721000009_purge_anonymous_users.sql` | `purge_stale_anonymous_users(days)` + daily pg_cron; clears stale guest accounts/profiles + abandoned enquiries |
| `20260721000010_revert_profiles_rls.sql` | **reverts** 20260721000008 — the profiles lockdown broke marketplace browsing (businesses RLS reads profiles) |
| `20260721000011_remove_guest_messaging.sql` | blocks anonymous senders (`trg_reject_anonymous_message`); drops `claim_guest_booking_conversation` — guests can't message |
| `20260721000012_guest_marketplace_access.sql` | grants the `anon` role marketplace read (guests browse with NO session); protects `businesses` store cols + `staff_profiles` email/phone |

All migrations are additive + idempotent. Run in the Supabase SQL editor
(make sure the button says **Run**, not "Run selected").

---

## What shipped (Flutter + Supabase, reusing existing services)

### Appointment-based messaging — `features/messaging/`
Secure in-app chat between a business (any active member) and a customer,
built on Supabase Realtime.
- **Two types:** `enquiry` (pre-booking questions, gated by the business's
  `pre_booking_messaging_enabled`) and `booking` (auto-created by a trigger
  when an appointment is made, showing the booking summary + quick actions).
- **Live:** `MessagingRepository.watchMessages` / `watchConversations` use
  `.stream()`; typing indicators use a Realtime broadcast channel (no DB).
- **Read receipts / delivered:** `mark_conversation_read` stamps `read_at`;
  bubbles show a single/double check.
- **Controls:** per-side mute + archive (`set_conversation_flag`), vendor
  block (`set_conversation_blocked`), report (`report_conversation`), and
  business on/off toggles (`set_business_messaging_settings`, in vendor
  Reminders & notifications).
- **Security:** RLS scopes conversations to the business's members, the
  customer who owns the contact / authored the enquiry, or an admin. All
  writes go through SECURITY DEFINER RPCs.
- **Messaging requires a real account** — guests CANNOT message vendors.
  Tapping "Ask a question" / "Message business" as a guest shows the
  sign-in prompt. Enforced in-app (entry points gate on
  `authStatus == authenticated`, and anonymous sessions count as guests) and
  server-side (`trg_reject_anonymous_message` blocks message inserts from
  anonymous sessions — see `20260721000011_remove_guest_messaging.sql`).
  Guests browse + book with **no session at all** — the `anon` role is
  granted read on the marketplace tables (`20260721000012`), with sensitive
  columns (business store tokens, staff email/phone) revoked. Anonymous
  sessions have been removed entirely.
- **Entry points:** "Messages" (vendor More + customer Profile, **plus a
  badge icon on both home screens** — Discover header / Dashboard header),
  "Message business" on the customer booking detail, and "Ask a question" on
  the business profile.
- **Opening-hours gate:** `businesses.messaging_restrict_after_hours`
  (default **on**, vendor toggle in Reminders & notifications → Customer
  messaging → "Only during opening hours") closes the customer's composer
  outside the business's hours — applies to both enquiries and booking
  chats. Vendors can always reply regardless. `businessMessagingGateProvider`
  combines `isOpenNow` + the toggle client-side.
- **Future-ready:** `messages.message_type` / `attachment_url` / `metadata`
  are in place for photos, documents, voice, and location; the schema also
  anticipates group/staff-specific threads and templates.

**Photos** send/receive via a private, participant-scoped bucket (signed
URLs). Documents/voice/location reuse the same `message_type`/`attachment_url`
path when you're ready.

### All email unified on Nodemailer (via an outbox)
Supabase Edge Functions run on Deno and can't run Nodemailer, so email is now
**produced** in the Edge Function and **sent** by your Node backend:

- **Producer:** `process-reminders` (per-minute cron) no longer calls Resend.
  It ENQUEUEs every email into `public.email_outbox` — booking reminders
  (category `booking_reminder`), trial notices (`trial`), and new-message
  notices (`message`). Message recipients come from `claim_message_email_targets`
  (unread past a 3-min grace, mute-aware, 60-min cooldown, atomic claim so no
  double-send; recipient = business **owner** or the **customer** account).
- **Consumer:** `backend/nodemailer/email-dispatcher.mjs` — one worker that
  drains the outbox via `claim_outbox_emails` (FOR UPDATE SKIP LOCKED, so you
  can run several) and sends with your SMTP Nodemailer transport. Failures
  requeue up to 5 attempts, then mark `failed`.

**To activate:**
1. Run migrations `20260721000003` + `20260721000004`.
2. Re-deploy the producer: `supabase functions deploy process-reminders
   --no-verify-jwt`. (Resend is no longer used — `RESEND_API_KEY` can be
   removed.)
3. Run `email-dispatcher.mjs` on a schedule in your Node backend
   (`npm i @supabase/supabase-js nodemailer`, set SMTP + Supabase env).

`push` / `whatsapp` reminder channels stay no-ops in the Edge Function and
fall back to email → outbox.

### Message push notifications — backend built; optional (needs Firebase)
Instant push is **optional** — email (above) already covers offline users.
If you later want banner-style push:
The server side is done and reusable:
- `device_push_tokens` + `register_push_token` / `unregister_push_token` RPCs
  and a `PushTokensRepository` (`pushTokensRepositoryProvider`) ready to call.
- Edge Function **`send-message-push`**: resolves the recipient (honouring the
  mute flag) via `message_push_targets`, looks up their device tokens, and
  sends FCM HTTP v1. Prunes stale tokens. No-ops safely if the FCM secret is
  unset.

**To turn push on** (needs a Firebase project — not set up yet):
1. Create a Firebase project; add the iOS + Android apps (bundle id
   `com.shorisolutions.shorivo`). Drop in `google-services.json` (Android) and
   `GoogleService-Info.plist` (iOS), and upload the APNs key in Firebase.
2. Add `firebase_core` + `firebase_messaging` to the app; on login call
   `FirebaseMessaging.instance.getToken()` then
   `ref.read(pushTokensRepositoryProvider).register(token)`, and
   `unregister(token)` on sign-out. (Deferred here so the build doesn't break
   without the Firebase config files.)
3. Deploy the function: `supabase functions deploy send-message-push
   --no-verify-jwt` and set secret `FCM_SERVICE_ACCOUNT_JSON` (the Firebase
   service-account key, one line).
4. Add a **Database Webhook** (dashboard → Database → Webhooks): table
   `public.messages`, event INSERT, POST to the function URL. The function
   accepts `{ record }` or `{ message_id }`.

Email-on-message could extend `process-reminders`; not built. The moderation
`messaging_moderation_log` + `conversation_reports` are ready for the web
admin (see WEB_ADMIN.md).

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

### Intelligent time zones (IANA / DST) — `core/time/`
`TimeZoneService` is the single source of truth: it loads the **IANA tz
database** (`timezone` pkg, `ensureInitialized()` in `main`) and does all
UTC↔local conversion, DST handling, device detection (`flutter_timezone`),
zone-diff checks and formatting. The old fixed-offset table is gone;
`businessLocalToUtc` / `utcToBusinessLocal` now delegate here, so every
existing caller is DST-correct.

- **Storage:** appointments stay UTC; each booking also records the
  customer's IANA zone (`appointments.customer_timezone`, write-once RPC).
- **Customer zone:** auto-detected from the device; manual override in
  Account & security → **Time zone** (`customerTimeZoneProvider` +
  `CustomerTimeZonePrefs`).
- **Business zone:** editable in the business profile (**Business time
  zone**, `set_business_timezone` RPC); still defaults to America/Barbados.
- **Booking confirm (C06):** shows Business time + Your local time with a
  friendly notice when they differ.
- **Details:** customer booking detail shows "your local time" (+ business
  time when different); vendor appointment detail shows a "Customer's time"
  row so vendors understand reminder times.
- **Reminders:** `process-reminders` appends "Business time … · Your time …"
  when zones differ (uses `customer_timezone`).
- **Calendar export:** ICS keeps UTC (`Z`) timestamps (correct on any
  device) + `X-WR-TIMEZONE` with the business zone.
- **Admin/troubleshooting:** stored UTC + business zone + `customer_timezone`
  are all queryable; the vendor appointment detail surfaces both local
  times. (A dedicated admin panel wasn't added — the data is all there.)
- **Extension point:** every conversion/format goes through
  `TimeZoneService`, so new booking/scheduling features stay consistent.

## Needs backend / app-store work (not doable from app code alone)

### Receipt validation — implemented + deployed; just add store secrets
The `verify-purchase` Edge Function (deployed to project `hdfuwrlvpswylikjuswj`)
validates the App Store / Play receipt server-side and grants the entitlement
with the **store's own trusted expiry** — the client never grants access
directly. Flow: `SubscriptionRepository.verifyPurchase` forwards the receipt
(`serverVerificationData`) → the function checks the caller is an OWNER/ADMIN,
verifies with Apple `verifyReceipt` (prod→sandbox fallback) or the Google Play
Developer API (service-account JWT), then activates the plan. If no store
secret is configured it returns **501** and the client falls back to the
legacy `recordPurchase` RPC, so nothing breaks before secrets are set.
**Remaining — set these secrets in the dashboard** (Project → Edge Functions →
Secrets), then verification turns on automatically:
- `APPLE_SHARED_SECRET` — App Store Connect "app-specific shared secret".
- `GOOGLE_SERVICE_ACCOUNT_JSON` — Play service-account key (androidpublisher
  access), pasted as one line.
- `ANDROID_PACKAGE_NAME` — e.g. `com.shorisolutions.shoribook`.

### Subscription auto-renewal — the actual charge
`auto_renew` + dates are stored, but **charging on renewal is store-managed**
(auto-renewable IAP handles renewal/retry) or requires a payment-processor
(e.g. Stripe) Edge Function. To complete:
- **Failed-payment retry + graceful restriction:** the access gate already
  restricts on `hasActiveAccess`; a `past_due` grace window + retry schedule
  belongs in the billing Edge Function.

### Annual purchase via IAP — wired; just add product ids
The app now supports annual end-to-end: the model carries
`store_product_id_{ios,android}_annual`, `SubscriptionRepository.storeProductId`
takes a `BillingPeriod`, `queryProducts` fetches monthly + annual, and the
modal's Yearly toggle uses the annual product for both price display and
purchase. **Remaining:** create the annual auto-renewable products in App
Store Connect / Play Console and put their ids in
`subscription_packages.store_product_id_*_annual` (e.g.
`com.shorisolutions.shoribook.solopro.annual`). Until set, Yearly shows the
computed discounted price and the CTA explains annual isn't available yet.

### Trial-ending reminders — implemented; deploy + schedule
`process-reminders` now sends "trial ends in N days" emails at 7/3/1 days
before `trial_ends_at` (auto-renew-aware copy), deduped via
`trial_reminder_log`. **Remaining:** deploy the function + set `RESEND_API_KEY`,
and keep the existing per-minute cron (the trial pass runs each invocation).

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

---

## Booking Confirmation Window (Phase 1)

Vendors can require customers to **confirm** an online booking within a
configurable window; unconfirmed bookings auto-cancel and the slot reopens.

**Scope decision:** applies to **online, no-deposit** bookings only. Deposit
bookings keep their own `pending` gate; vendor-created (walk-in/phone) bookings
are never affected. Waitlist + analytics are later phases.

**Schema** (`20260726000001`, `20260726000002`):
- `businesses.require_confirmation`, `confirmation_window_minutes` (default 120),
  `waitlist_enabled` (reserved for Phase 2). Set via `save_booking_rules`
  (two new trailing args, backward-compatible).
- `appointments.confirmation_required`, `confirmation_deadline`, `confirmed_at`,
  `cancellation_reason`; new status `pending_confirmation`; partial index on
  the pending rows for the cron sweep.
- `reminder_queue.kind` + `payload` — confirmation reminders and expiry notices
  reuse the existing `process-reminders` pipeline (no new dispatcher).

**Flow:**
1. `create_customer_appointment_safe` — online no-deposit booking at a
   confirmation-required business is created `pending_confirmation` with
   `confirmation_deadline = LEAST(now()+window, start_time)`; imminent bookings
   (no useful window) auto-confirm. It enqueues confirmation nudges
   (`generate_confirmation_reminders`: halfway / 30m / 10m before the deadline,
   future-only) and returns `confirmation_required` + `confirmation_deadline`.
2. `confirm_appointment` (customer/staff) / `confirm_guest_appointment`
   (id + phone) — flips to `confirmed`, cancels the nudges; the status trigger
   regenerates the normal appointment reminders. `generate_reminders` now skips
   `pending_confirmation` rows so appointment reminders only start on confirm.
3. `expire_unconfirmed_appointments()` — pg_cron every minute
   (`expire-unconfirmed-bookings`); cancels past-deadline bookings, sets
   `cancellation_reason='confirmation_expired'`, and enqueues customer + vendor
   email notices. The status trigger cancels remaining reminders on cancel.

**Client:** Booking Rules tab (toggle + duration picker); wizard "Almost done"
screen with a live countdown + Confirm button; My Bookings card/detail badges +
confirm CTA (guest via id+phone); vendor manual confirm on the appointment
detail; dashboard "N bookings awaiting confirmation" banner.

**Ops (run manually):** run `20260726000001` + `20260726000002`; redeploy
`process-reminders`; ensure the per-minute cron is scheduled (guarded in the
migration — schedule `expire-unconfirmed-bookings` by hand if pg_cron wasn't
available). Email is the guaranteed channel today (push/WhatsApp are stubs).

**Later phases:** waitlist (done — see below), analytics (confirmation rate,
expired count, avg confirm time, waitlist conversion), per-service/staff
windows, deposit interaction.

---

## Waitlist (Phase 2)

Customers join a waitlist for a business/service (+ optional pro, date, time or
range); when a slot frees up, matching customers are notified. Vendors toggle it.

**Schema** (`20260726000003`, `20260726000004`):
- `waitlist_entries` (service/staff/date/time optional; status
  active|booked|cancelled|expired; notified_at/notified_count) + RLS (self +
  business read; writes via RPCs so guests work).
- `reminder_queue.booking_id` made nullable + `waitlist_entry_id` added, so
  "spot opened" notices reuse the `process-reminders` pipeline.
- `save_booking_rules` gains `p_waitlist_enabled`.
- Guests get column SELECT on `require_confirmation` /
  `confirmation_window_minutes` / `waitlist_enabled` so the wizard can show the
  right UI before a booking exists.

**Flow:**
1. `join_waitlist` / `leave_waitlist` / `get_guest_waitlist` (guest id+phone).
2. `trg_appointments_waitlist` — on a booking cancelled/no-show from any active
   state (customer/guest/vendor cancel + Phase-1 confirmation expiry, uniformly),
   calls `notify_waitlist_for_slot`; on a new active booking, marks the booker's
   matching entries `booked`.
3. `notify_waitlist_for_slot` — matches active entries (service/staff/date),
   honours the vendor toggle + a 30-min per-entry cooldown (so a run of
   cancellations can't spam), enqueues `waitlist_open`. Entries stay `active`
   (keep their place) until booked or left.
4. `process-reminders` renders `waitlist_open` from the `waitlist_entry` (not an
   appointment) via a shared `deliver()` helper.
5. `expire_stale_waitlist_entries()` + a daily cron tidies past-date entries.

**Client:** vendor Waitlist toggle in Booking Rules + a `/waitlist` list screen;
customer "Join the waitlist" CTA on a full/empty day in the wizard (join sheet:
name/phone, guest id stored on-device); a "Waitlist" tab in My Bookings with a
Leave action.

**Matching (MVP):** business + service (or any) + preferred date (or any) +
staff (or any). Time/range is stored but not yet used to filter — a future
refinement, along with re-notify tuning and waitlist analytics.

**Ops (run manually):** run `20260726000003` + `20260726000004`; redeploy
`process-reminders`; ensure the daily `expire-stale-waitlist` cron scheduled
(guarded in the migration).

---

## Confirmation + Waitlist analytics (Phase 3)

`get_confirmation_waitlist_analytics(business, from, to)` (`20260726000005`,
OWNER/ADMIN only) aggregates, by `created_at` over the range:
- **Confirmation rate** = confirmed / (confirmed + expired) of bookings that
  required confirmation; **expired count**; **avg confirmation time**
  (`confirmed_at - created_at`).
- **Waitlist**: total / notified / **conversion rate** (booked among notified).
- **Rebook rate**: of distinct customers with an expired confirmation, how many
  later created another booking.

Surfaced in the **Reports** screen as a "Confirmations & waitlist" section that
follows the existing period picker (`reportRangeDates` shared helper) and hides
itself when there's no activity. Rates are null-safe (show "—" when the
denominator is 0).

**Ops (run manually):** run `20260726000005`. Read-only RPC, no cron/redeploy.

This completes the original Confirmation / Auto-cancel / Waitlist spec. Possible
follow-ups: trend charts over time, per-service breakdowns, and time/range-aware
waitlist matching.

---

## Payment profiles + deposit prerequisite (FirstPay) -- Phase 1

A business must complete a **FirstPay** payment profile before it can require
deposits. Layered on the existing tier gate: deposits need **both** a plan that
includes them (Solo Pro/Squad) **and** a ready payment method.

**Schema** (`20260726000007`): `payment_profiles` -- one row per
(business, provider); provider-specific fields in `details` JSONB (FirstPay:
account_holder_name / account_number / email) + optional deposit_instructions /
payment_notes. OWNER/ADMIN-only RLS; never exposed to anon/customers.
- `payment_profile_ready(provider, details)` -- per-provider required-field rule
  (only FirstPay implemented).
- `business_has_ready_payment_method(business_id)` -- used by the trigger + app.
- `save_payment_profile(...)` RPC (OWNER/ADMIN) -- upsert, returns status.
- `trg_enforce_deposit_requires_payment` on services -- blocks setting
  `deposit_required = true` (insert or false->true) unless a ready method exists
  (`payment_setup_required`). Turning deposits off is always allowed.

**Client:** PaymentProfile model (typed FirstPay getters, `PaymentStatus`,
account masking), PaymentRepository + `firstPayProfileProvider` /
`depositReadyProvider`; **Payment Settings** screen (`/payment-settings`, masked
account number, status badge) in More > Business with a status subtitle; the
service-form deposit toggle shows the **"Complete your FirstPay setup first"**
dialog (Set Up FirstPay / Cancel) when the plan allows deposits but FirstPay
isn't ready, with the server trigger as the backstop.

**Ops (run manually):** run `20260726000007`.

**Future providers:** WiPay / bank transfer / card each get a readiness rule in
`payment_profile_ready` + a form; the table + gate already support "any ready
method enables deposits".

### Phase 2 (client-only, no migration)
Shared `depositCapabilityProvider` (enabled / needsPayment / needsPlan) drives:
- **Dashboard reminder card** — "Complete your payment setup" -> Payment
  Settings, shown only when the plan includes deposits but FirstPay isn't ready
  (`needsPayment`); auto-hides once ready.
- **Deposit status** on the business Settings screen — "Deposits Enabled" /
  "Deposits Disabled" with the reason ("FirstPay setup required before deposits
  can be enabled." or an upgrade prompt) + a shortcut.
- **Business setup checklist** (`/setup-checklist`, More > Business): Business
  information / Address / Services / Staff / Payment settings (Required for
  deposits) / Availability, each ✅/⚠️ and tap-to-navigate. Completion is
  derived from existing providers (business fields, services/staff counts,
  business hours, depositReady).
