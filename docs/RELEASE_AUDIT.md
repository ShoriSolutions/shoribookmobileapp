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

Fixes already applied are marked **✅ FIXED**. Later passes centralized the
share links (H2), added an offline error message (M5), locked orientation to
portrait (M3), wrote a least-privilege RLS migration for H3 + M1
(`20260801000001_rls_least_privilege.sql`, run + test manually), wired the
**Android release signing** config (C5), and set iOS to **iPhone-only**
(`TARGETED_DEVICE_FAMILY="1"`) to shrink App Review surface.

**Step-by-step store submission guides:** [ANDROID_RELEASE.md](ANDROID_RELEASE.md)
· [IOS_RELEASE.md](IOS_RELEASE.md).

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

### C5 — Android release was signed with the DEBUG keystore ✅ WIRED (keystore is yours to generate)
`android/app/build.gradle.kts` used `signingConfig = signingConfigs.getByName("debug")`
for release. Google Play **rejects** debug-signed bundles, and the upload key is
permanent per app — a hard blocker for the first submission.
**Fix:** added a proper `release` signing config that reads
`android/key.properties` (gitignored), falling back to debug only when that file
is absent (so local `flutter run --release` still works). Added
`android/key.properties.example` and gitignored `key.properties` / `*.jks` /
`*.keystore`.
**Action for you (I cannot do this — it needs your secret key):**
1. `keytool -genkey -v -keystore ~/shorivo-upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
2. copy `android/key.properties.example` → `android/key.properties` and fill it in;
3. `flutter build appbundle --release` and confirm it's signed with your key
   (`keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab`);
4. back up the keystore + passwords somewhere safe — losing them means you can
   never update the app (unless you use Play App Signing, which is recommended).

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

### H2 — Share / booking links hardcoded to `betterbooking.app` ✅ CENTRALIZED (set domain)
`https://betterbooking.app/book/<slug>` and `/business/<slug>` were hardcoded in
5 places. If the live domain is now Shorivo's, **every share link customers send
is broken/mis-branded.**
**Fix:** all 5 usages now go through `AppLinks` (`lib/core/config/app_links.dart`),
so the domain is set in ONE place (`AppLinks.webBaseUrl`).
**Action for you:** set `AppLinks.webBaseUrl` to the correct live domain (it's
still `https://betterbooking.app` — the value I couldn't confirm) and open one
generated link to confirm it renders a real booking page.

### H3 — `profiles` is world-readable via `USING (true)` (VERIFY → likely PII enumeration)
`20260721000014_marketplace_access_final.sql:28` sets a `profiles` SELECT policy
`USING (true)` (to unbreak a businesses base policy that sub-selects profiles).
`anon` is correctly **not** granted table access (verified: permission denied),
but the `authenticated` role almost certainly is — meaning **any logged-in user
can read every profile's `full_name`, `email`, `phone`.**
**Impact:** PII enumeration across all users.
**Fix:** `20260801000001_rls_least_privilege.sql` restricts `profiles` SELECT to
`id = auth.uid()`. Confirmed safe for the mobile app — both profiles reads
(`profile_repository`, `trust_repository`) are own-row. Marketplace browsing
does not depend on it once M1's businesses policy is self-contained.
**Action for you:** run the migration; verify login + profile load and that
marketplace browsing still works (rollback SQL is in the migration).

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
**Fix:** `20260801000001_rls_least_privilege.sql` changes the policy to
`USING (is_published = true OR owner_id = auth.uid() OR
public.get_my_business_role(id) IS NOT NULL)`.
**Action for you:** run the migration; verify guest browsing/booking of a
published business and the owner opening their own (possibly unpublished)
business. Also check `pg_policies` for any other permissive businesses SELECT
policy (the verify query is in the migration).

### M2 — Staff can read all appointments + prices via the raw table
Documented in `20260710000000_mobile_app_support.sql:204-210`: the
`appointments_member_select` policy lets **any** member (incl. STAFF) read every
appointment and its `price`; only the reporting RPC enforces OWNER/ADMIN. A
staff member could query the table directly and see full revenue.
**Recommend:** tighten the member-select policy (staff → only their own
`staff_profile_id` rows) if staff shouldn't see business-wide revenue.

### M3 — Orientation locked to portrait ✅ FIXED
`ios/Runner/Info.plist` listed Landscape for iPhone (broken layouts risk under
App Review). **Fix:** iPhone locked to Portrait in `Info.plist` (iPad keeps all
orientations), and `android:screenOrientation="portrait"` added to `MainActivity`
so both platforms match.

### M4 — Subscription renewal date column reconciliation ✅ FIXED (app side)
Both purchase paths write `subscription_period_end`, but the model read only
`current_period_end` (always null for paid plans). Reconciled in `Business.fromJson`
(falls back to `subscription_period_end`) and the plan card now shows the date.
Also fixed: the Subscription screen showed the *popular* plan as "Current plan"
instead of the actual subscribed plan; and the purchase handler now matches a
package by monthly **or** annual store id.

### M5 — Offline error message ✅ FIXED
`AppException.from` previously mapped no-internet to the generic "Something went
wrong." **Fix:** it now detects `SocketException` and http/lookup network
failures and returns "You appear to be offline. Check your connection and try
again." (double-booking `23P01` and duplicate `23505` were already handled).

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
| H3 | `profiles` world-readable to authenticated (PII) | High | ✅ migration written (run + test) |
| M1 | Unpublished businesses' contact info enumerable | Medium | ✅ migration written (run + test) |
| M2 | Staff can read all appointments/prices | Medium | Documented only (product decision) |
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

0. ☐ **Android:** generate an upload keystore + `android/key.properties`, then
   build a signed AAB (C5). Enrol in Play App Signing.
1. ☐ Run `20260801000000_fix_reviews_read_policy.sql` (C3).
2. ☐ Run `20260801000001_rls_least_privilege.sql`, then run its verify query +
   test browsing/login (H3, M1).
3. ☐ Deploy `verify-purchase` + set `APPLE_SHARED_SECRET` /
   `GOOGLE_SERVICE_ACCOUNT_JSON` / `ANDROID_PACKAGE_NAME` (C4).
4. ☐ Add `ios/Runner/PrivacyInfo.xcprivacy` to the Runner target in Xcode (H1).
5. ☐ Set `AppLinks.webBaseUrl` to the live domain + confirm it renders (H2).
6. ☐ Create the App Store / Play subscription products matching
   `subscription_packages.store_product_id_*`; test a sandbox purchase.
7. ☐ Confirm the Supabase Auth redirect allow-list contains
   `shoribook://auth/callback`.
8. ☐ Smoke-test a **release** build on a real iOS + Android device (network,
   login, booking, purchase, reviews).
9. ☐ Fill App Store Connect / Play Data-Safety privacy questionnaires to match
   `PrivacyInfo.xcprivacy`.
