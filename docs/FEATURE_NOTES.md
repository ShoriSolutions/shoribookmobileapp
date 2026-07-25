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
| `20260721000006_guest_messaging.sql` | `claim_guest_booking_conversation` RPC (guest links their anon uid to a booking chat by phone) |

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
- **Guests can message** via Supabase **anonymous auth**: tapping "Ask a
  question" / "Message business" as a guest calls `AuthRepository.ensureSession`
  (signs in anonymously → real `auth.uid()` so RLS + Realtime + attachments
  all work). Anonymous users are still treated as **guests** everywhere else —
  `authStatusProvider` reports anonymous sessions as unauthenticated, so
  browsing / guest booking / "Log in or sign up" prompts are unchanged. A
  guest links their booking chat with the phone they booked with
  (`claim_guest_booking_conversation`). **Requires "Enable anonymous sign-ins"
  in the Supabase dashboard (Auth → Providers)**; if it's off, the app falls
  back to prompting a normal login.
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
