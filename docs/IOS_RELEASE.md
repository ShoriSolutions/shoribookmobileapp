# iOS Release Guide — Shorivo (Apple App Store)

Step-by-step to build and submit the iOS app. Bundle id:
**`com.shorisolutions.shorivo`** · iPhone-only · min iOS 13.0.

> Companion docs: [RELEASE_AUDIT.md](RELEASE_AUDIT.md) (must-fix items),
> [ANDROID_RELEASE.md](ANDROID_RELEASE.md).

---

## 0. Prerequisites

- **Apple Developer Program** membership ($99/yr).
- A **Mac with the current Xcode** — Apple requires apps be built with a recent
  Xcode / iOS SDK (Xcode 16 / iOS 18 SDK at time of writing). `flutter doctor`
  clean for iOS; run `pod install` in `ios/` if needed.
- **Backend ready** (shared — see §7).

---

## 1. App identity (already set in-repo ✅)

- Bundle id `com.shorisolutions.shorivo`, display name **Shorivo**, full AppIcon
  set incl. 1024×1024, `ITSAppUsesNonExemptEncryption=false`, photo + location
  usage strings, iPhone-only (`TARGETED_DEVICE_FAMILY="1"`), portrait-only.
- In the **Apple Developer** portal: register the App ID
  `com.shorisolutions.shorivo` (with In-App Purchase capability).
- In **App Store Connect**: create the app record with that bundle id.

## 2. Signing (Xcode — owner action)

```bash
open ios/Runner.xcworkspace
```

1. Select the **Runner** target → **Signing & Capabilities**.
2. Tick **Automatically manage signing** and pick your **Team**
   (`DEVELOPMENT_TEAM` isn't set in the repo — this is per-developer).
3. Confirm the **In-App Purchase** capability is present (needed for
   subscriptions).

## 3. Add the privacy manifest to the target (REQUIRED — one-time)

`ios/Runner/PrivacyInfo.xcprivacy` exists in the repo but **is not yet part of
the Xcode target**, so it won't be bundled until you add it:

1. In Xcode's Project navigator, right-click the **Runner** group → **Add Files
   to "Runner"…**
2. Select `ios/Runner/PrivacyInfo.xcprivacy`, ensure **Target: Runner** is
   checked, **Add**.
3. Verify it appears under Runner → Build Phases → **Copy Bundle Resources**.
4. Make its `NSPrivacyCollectedDataTypes` match your App Store Connect privacy
   answers (§6).

## 4. Set the version

`pubspec.yaml` `version: 1.0.0+1` drives `CFBundleShortVersionString` (1.0.0)
and `CFBundleVersion` (1). Bump the build number for every upload.

## 5. Build the IPA

Pass the prod environment file so Supabase config is baked in:

```bash
flutter build ipa --release --dart-define-from-file=env/prod.json
```

> Create `env/prod.json` (from `env/dev.example.json`) with your **production**
> Supabase URL + publishable (anon) key first. Without
> `--dart-define-from-file` the app launches with no backend and fails.

Then either open `build/ios/archive/Runner.xcarchive` in **Xcode → Organizer →
Distribute App**, or upload `build/ios/ipa/*.ipa` with **Transporter**.
(You can also archive directly from Xcode: **Product → Archive**.)

## 6. App Store Connect — before submitting

- **App Privacy** questionnaire: declare collected data (email, name, phone,
  precise location, photos), all "linked to user / app functionality / not used
  for tracking" — must match `PrivacyInfo.xcprivacy`.
- **Subscriptions:** create the auto-renewable subscription products whose IDs
  match `subscription_packages.store_product_id_ios`
  (`com.shorisolutions.shoribook.{sidehustle,solopro,squad}.monthly`), in a
  subscription group. Add localized display name, price, and the required
  **subscription terms** (the paywall already links Terms of Use + Privacy).
- **Age rating** questionnaire.
- **Screenshots:** 6.7" (and 6.5" if required) iPhone sizes. No iPad needed
  (iPhone-only).
- **Export compliance:** already declared via `ITSAppUsesNonExemptEncryption` —
  you shouldn't be prompted.
- **App Review Information → Sign-In required:** provide **demo credentials for a
  business account with an active subscription** so the reviewer can test the
  vendor side behind the paywall. Add notes explaining the deposit flow uses
  FirstPay for **in-person services** (allowed outside IAP under Guideline
  3.1.3(e)); only the app subscription uses IAP.
- **Account deletion:** the app already exposes it (Settings → Delete account) —
  Apple requires this for accounts (Guideline 5.1.1(v)).

## 7. Backend prerequisites (shared — do before submitting)

Same as Android — see [ANDROID_RELEASE.md](ANDROID_RELEASE.md#6b-backend-prerequisites-shared--do-before-submitting):

- ☐ Run `20260801000000_fix_reviews_read_policy.sql`.
- ☐ Run `20260801000001_rls_least_privilege.sql` (+ verify query).
- ☐ Deploy `verify-purchase` + set `APPLE_SHARED_SECRET` (and the Google secrets).
- ☐ Set `AppLinks.webBaseUrl` to the live domain.
- ☐ Supabase Auth redirect allow-list contains `shoribook://auth/callback`.

## Notes / compliance summary

- **Sign in with Apple (4.8):** NOT required — the app uses email/password only,
  no third-party social login.
- **IAP (3.1.1):** the app subscription correctly uses `in_app_purchase`.
  Booking **deposits** via FirstPay are for real-world/in-person services, which
  Apple permits outside IAP — call this out in review notes to avoid confusion.
- **TestFlight** first: push a build to TestFlight and self-test on a real
  device before submitting for App Review.

## Quick smoke test (TestFlight build)

Network loads, login (customer + business), browse marketplace, make a booking,
open reviews, run a sandbox subscription purchase, receive a confirmation,
delete-account flow works.
