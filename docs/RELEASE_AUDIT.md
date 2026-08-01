# Shorivo — Pre-Production Release Audit

_Audit date: 2026-08-01 · Branch: `main` · Scope: Flutter mobile app (customer + vendor) + Supabase backend (66 migrations, 6 edge functions)._

## Method & honest limitations

This is a **static + live-database** audit. I inspected the source, all SQL
migrations, and the edge functions, ran `flutter analyze` (clean) and the test
suite (36 pass), and probed the live Supabase project with the **publishable
(anon) key** to verify RLS behaviour as a guest.

What this audit could **not** do (and therefore did not verify): interactive
runtime testing of every screen on real devices, visual layout inspection at
different sizes, authenticated-role live probing (no test JWT), running
migrations, or store-sandbox purchase testing. Items depending on those are
called out as **VERIFY** rather than confirmed.

Fixes already applied in this pass are marked **✅ FIXED** and were committed
(`eb0f1e7` + the subscription commit `6cc3973`).

---

## Verdict: App Store readiness

**Not yet — but close.** No architectural blockers. The must-do items are a
mix of small code fixes (mostly done) and **operational/config** steps only the
account owner can perform (deploy edge functions, set store secrets, create
store products, confirm the share-link domain, wire the iOS privacy manifest
into Xcode, run the new migration). Once the Critical + High lists below are
closed, the app is submittable.

Overall the codebase is **well-engineered**: no hardcoded secrets, no debug
logging, no TODO/FIXME debt, strong SQL authorization (SECURITY DEFINER + role
checks), and a genuinely robust anti-double-booking design.

---

## Critical Issues (must fix before launch)

### C1 — Android release build could ship with no network ✅ FIXED
`INTERNET` was declared only in `android/app/src/debug/AndroidManifest.xml`.
Release builds merge only the main manifest + plugin manifests, and Supabase
networking is pure-Dart (no plugin guarantees the permission), so a release
APK/AAB could have **no network at all** — every screen would fail.
**Fix:** added `INTERNET` + `ACCESS_NETWORK_STATE` to the main manifest.
**Action for you:** none — but smoke-test a **release** build on-device.

### C2 — Subscription paywall missing Terms/Privacy links ✅ FIXED
Apple Guideline **3.1.2** (and Play policy) require auto-renewable subscription
paywalls to show functional links to the Terms of Use (EULA) and Privacy
Policy. The modal had neither — a very common rejection.
**Fix:** added "Terms of Use · Privacy Policy" links to the paywall footer
(open the same `LegalDocumentScreen` used at registration).

### C3 — Guests cannot load reviews (RLS error) ✅ FIXED (migration to run)
`reviews_read_mobile` inlined a subquery over `appointments`/`customers` to
check authorship. RLS expressions run as the **calling** role, and `anon` has
no grant on those tables, so the whole SELECT raised `permission denied for
table appointments` for guests — they saw the star average (rollup column) but
the **review list failed to load**. Verified live against the DB.
**Fix:** `20260801000000_fix_reviews_read_policy.sql` rewrites the policy to use
the existing SECURITY DEFINER `owns_appointment()` helper.
**Action for you:** run that migration in the Supabase SQL editor.

### C4 — Server-side purchase verification not proven live (VERIFY)
`verify-purchase` exists and is correct, but if it isn't **deployed with store
secrets** (`APPLE_SHARED_SECRET`, `GOOGLE_SERVICE_ACCOUNT_JSON`,
`ANDROID_PACKAGE_NAME`), the client falls back to the trust-the-client
`record_subscription_purchase` RPC — an OWNER could then grant themselves a paid
plan without paying. Not a code bug; a deployment gate.
**Action for you:** deploy the function + set the secrets, and confirm a
sandbox purchase returns `verified:true`.

---

## High Priority

### H1 — iOS privacy manifest not wired into the build ✅ FILE CREATED (Xcode step)
Apple requires `PrivacyInfo.xcprivacy` (required-reason APIs: `shared_preferences`
→ UserDefaults, `path_provider`/`image_picker` → file timestamps). I created
`ios/Runner/PrivacyInfo.xcprivacy`, but **a file on disk is not bundled** until
it's added to the Runner target in Xcode.
**Action for you:** in Xcode, drag `PrivacyInfo.xcprivacy` into the Runner
target (or add it as a resource in `project.pbxproj`), and make the
`NSPrivacyCollectedDataTypes` match your App Store Connect privacy answers.

### H2 — Share / booking links hardcoded to `betterbooking.app` (VERIFY)
`https://betterbooking.app/book/<slug>` and `/business/<slug>` are used in the
share sheet, booking-link screen, marketplace profile, and profile-marketplace
screen. If the live domain is now Shorivo's, **every share link customers send
is broken/mis-branded.**
Files: `lib/features/booking_link/presentation/booking_link_screen.dart:20`,
`booking_share_sheet.dart:13`,
`lib/features/marketplace/presentation/business_profile_screen.dart:81`,
`lib/features/profile_marketplace/presentation/profile_marketplace_screen.dart:28`,
`.../widgets/share_booking_link_section.dart:22`.
**Recommend:** move the base URL to one constant (e.g. `Env`/a config) and point
it at the correct live domain; confirm the domain resolves and renders a booking
page.

### H3 — `profiles` is world-readable via `USING (true)` (VERIFY → likely PII enumeration)
`20260721000014_marketplace_access_final.sql:28` sets a `profiles` SELECT policy
`USING (true)` (to unbreak a businesses base policy that sub-selects profiles).
`anon` is correctly **not** granted table access (verified: permission denied),
but the `authenticated` role almost certainly is — meaning **any logged-in user
can read every profile's `full_name`, `email`, `phone`.**
**Impact:** PII enumeration across all users.
**Recommend:** replace the profiles-dependent businesses base policy with a
SECURITY DEFINER helper, then restrict `profiles` SELECT to
`id = auth.uid()` (+ any minimal cross-read the app genuinely needs). Verify
with an authenticated session which columns are returned for a *different*
user's id before and after.

### H4 — No store server-notification webhook → lapsed paid subs keep access
Nothing flips `subscription_status` back to `canceled`/`past_due` when a paid
subscription lapses at the store. Once `active`, a business keeps Pro access
indefinitely (trials are safe — they expire via `trial_ends_at`).
**Impact:** revenue leak, not a functional break.
**Recommend:** App Store Server Notifications V2 + Google RTDN → an edge function
that downgrades `subscription_status`. Acceptable to ship v1 without it if you
accept the leak short-term.

---

## Medium Priority

### M1 — `businesses` marketplace read is `USING (true)` (unpublished businesses exposed)
`businesses_public_read USING (true)` lets anon/authenticated read **all**
businesses — including `is_published = false` / unlisted ones — with their safe
columns (which include `phone`, `email`, `address`). The app filters in queries,
but the API doesn't. Someone hitting REST directly can enumerate unpublished
businesses' contact details.
**Recommend:** `USING (is_published = true OR owner_id = auth.uid() OR
public.get_my_business_role(id) IS NOT NULL)`. Test the owner's own-business read
and marketplace browsing after changing it.

### M2 — Staff can read all appointments + prices via the raw table
Documented in `20260710000000_mobile_app_support.sql:204-210`: the
`appointments_member_select` policy lets **any** member (incl. STAFF) read every
appointment and its `price`; only the reporting RPC enforces OWNER/ADMIN. A
staff member could query the table directly and see full revenue.
**Recommend:** tighten the member-select policy (staff → only their own
`staff_profile_id` rows) if staff shouldn't see business-wide revenue.

### M3 — iPhone allows landscape but the UI is portrait-designed
`ios/Runner/Info.plist` lists Landscape Left/Right for iPhone. If screens aren't
built for landscape, reviewers may see broken layouts.
**Recommend:** lock iPhone to Portrait (remove the landscape entries) unless
landscape is explicitly tested. (Behaviour change — left for you to decide.)

### M4 — Subscription renewal date column reconciliation ✅ FIXED (app side)
Both purchase paths write `subscription_period_end`, but the model read only
`current_period_end` (always null for paid plans). Reconciled in `Business.fromJson`
(falls back to `subscription_period_end`) and the plan card now shows the date.
Also fixed: the Subscription screen showed the *popular* plan as "Current plan"
instead of the actual subscribed plan; and the purchase handler now matches a
package by monthly **or** annual store id.

### M5 — No specific offline error message
`AppException.from` maps a `SocketException`/no-internet to the generic
"Something went wrong. Please try again." (double-booking `23P01` and duplicate
`23505` are handled nicely, so this is minor.)
**Recommend:** add an offline branch ("You appear to be offline — check your
connection.") for `SocketException`/`ClientException`.

---

## Low Priority / Future

- **L1 — Branding drift.** `shoribook://` deep-link scheme, `CFBundleURLName
  app.betterbooking.auth`, `assets/branding/shoribookslogo.png`, and IAP product
  ids `com.shorisolutions.shoribook.*` all predate the "Shorivo" rename. All
  **functional** (schemes are internally consistent; product ids just have to
  match the store), but worth aligning for consistency. If you change the
  deep-link scheme, update the Supabase redirect allow-list too.
- **L2 — Push notifications are backend-only.** No `firebase_messaging` in the
  app; `device_push_tokens` / `register_push_token` are unused from mobile.
  Notifications are in-app + email. Fine for v1; wire FCM/APNs later.
- **L3 — `_cancel` trial button is cosmetic** (shows a snackbar; the trial just
  expires with no charge). Harmless but could confuse.
- **L4 — 58/90 providers are `autoDispose`.** The session-scoped ones (auth,
  membership, catalog) are intentionally kept alive; no leak identified.

---

## Security Findings (summary)

| # | Finding | Severity | Status |
|---|---------|----------|--------|
| C3 | Reviews RLS errors for guests | Critical (functional) | ✅ migration written |
| C4 | Purchase verification may be trust-the-client | Critical | VERIFY (deploy + secrets) |
| H3 | `profiles` world-readable to authenticated (PII) | High | Recommend RLS tightening |
| M1 | Unpublished businesses' contact info enumerable | Medium | Recommend RLS tightening |
| M2 | Staff can read all appointments/prices | Medium | Recommend RLS tightening |
| — | Secrets/keys | — | ✅ none exposed (env gitignored; service-role only in `Deno.env`) |
| — | Admin/privileged RPCs | — | ✅ `is_admin()` / OWNER-ADMIN gated |
| — | Review/booking/block RPCs | — | ✅ ownership-checked (anti-abuse: word-count, new-account flags, dedupe) |
| — | Login brute force | — | ✅ lockout + email alert (`login_attempts`) |
| — | Guest PII (customers/appointments/business_members) | — | ✅ anon denied (verified live) |
| — | Business store tokens (`subscription_token`) | — | ✅ column-level grant withholds from anon (verified live) |

## Performance Findings

No blocking issues. `cached_network_image` is used for remote images.
Opportunities (non-blocking): (a) audit any list that reads a business + its
services + staff separately for an N+1 pattern (prefer a single joined select);
(b) confirm the marketplace list paginates rather than fetching all businesses;
(c) `subscriptionPackagesProvider` is intentionally session-cached (good).

## UX Findings

- Empty/loading/error states exist on the key async surfaces (subscription
  modal, payment settings, error-retry view). Good.
- **C2/H1/H2** above are the user-visible ones (paywall legality, share links).
- Recommend a manual device pass for: text overflow at large font-scale
  (accessibility), small-screen (SE) layout, and dark-mode (the app appears to
  target a single light theme — confirm that's intended; iOS/Android users on
  dark mode will still get the light UI, which is acceptable but worth a note in
  the listing).

## Booking system — verified robust ✅

Double-booking is prevented by **two** independent mechanisms: a
`pg_advisory_xact_lock` in `create_appointment_safe` /
`create_customer_appointment_safe` (serialises check+insert, keyed by staff or
business), **and** an `appointments_no_overlap` GiST exclusion constraint
(`staff_profile_id WITH =`, `tstzrange(start,end) WITH &&`, `WHERE status NOT IN
('cancelled','no_show')`). The null-staff edge case is covered by the advisory
lock (documented). Exclusion violations surface to the user as "That time slot is
no longer available." (`23P01`). This is a genuinely strong design.

---

## Pre-submission checklist (owner actions)

1. ☐ Run `20260801000000_fix_reviews_read_policy.sql` (C3).
2. ☐ Deploy `verify-purchase` + set `APPLE_SHARED_SECRET` /
   `GOOGLE_SERVICE_ACCOUNT_JSON` / `ANDROID_PACKAGE_NAME` (C4).
3. ☐ Add `ios/Runner/PrivacyInfo.xcprivacy` to the Runner target in Xcode (H1).
4. ☐ Point share links at the correct live domain and confirm it renders (H2).
5. ☐ Decide + apply the `profiles` / `businesses` RLS tightening (H3, M1).
6. ☐ Create the App Store / Play subscription products matching
   `subscription_packages.store_product_id_*`; test a sandbox purchase.
7. ☐ Confirm the Supabase Auth redirect allow-list contains
   `shoribook://auth/callback`.
8. ☐ Smoke-test a **release** build on a real iOS + Android device (network,
   login, booking, purchase, reviews).
9. ☐ Fill App Store Connect / Play Data-Safety privacy questionnaires to match
   `PrivacyInfo.xcprivacy`.
