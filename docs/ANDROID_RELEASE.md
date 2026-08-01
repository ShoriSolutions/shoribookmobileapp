# Android Release Guide — Shorivo (Google Play)

Step-by-step to build and submit the Android app. Package:
**`com.shorisolutions.shorivo`**.

> Companion docs: [RELEASE_AUDIT.md](RELEASE_AUDIT.md) (must-fix items),
> [IOS_RELEASE.md](IOS_RELEASE.md).

---

## 0. Prerequisites (do these once)

- A **Google Play Developer** account ($25 one-time).
- JDK installed (`keytool` comes with it) and the Flutter toolchain working
  (`flutter doctor` clean for Android).
- **Backend ready** (shared with iOS — see §6): run the pending migrations,
  deploy `verify-purchase` with its secrets, and set the live web domain.

---

## 1. Generate the upload keystore (ONCE — keep it forever)

```bash
keytool -genkey -v -keystore ~/shorivo-upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

- Choose strong passwords; you'll be asked for name/org (any real values).
- **Back this file up** (password manager + offline copy). If you lose it and
  are NOT on Play App Signing, you can never update the app again.

## 2. Create `android/key.properties`

Copy the template and fill in your values:

```bash
cp android/key.properties.example android/key.properties
```

```properties
storePassword=<the store password you just set>
keyPassword=<the key password you just set>
keyAlias=upload
storeFile=/Users/<you>/shorivo-upload-keystore.jks
```

`android/key.properties` and `*.jks` are **gitignored** — never commit them.

## 3. Signing config — already wired ✅

`android/app/build.gradle.kts` already reads `key.properties` for the `release`
build type (and falls back to debug only when the file is absent). Nothing to
change; just confirm §2 is filled in.

## 4. Set the version

In `pubspec.yaml` (`version: <name>+<code>`), e.g. `version: 1.0.0+1`.
`versionName` = `1.0.0`, `versionCode` = `1`. **Bump `+<code>` for every upload**
(Play rejects a re-used versionCode).

## 5. Build the signed App Bundle

Play requires an **.aab** (not .apk). You MUST pass the prod environment file so
the app has its Supabase URL/key baked in:

```bash
flutter build appbundle --release --dart-define-from-file=env/prod.json
```

> If `env/prod.json` doesn't exist yet, create it from `env/dev.example.json`
> with your **production** Supabase URL + publishable (anon) key. Without
> `--dart-define-from-file`, the app launches with no backend config and fails.

Output: `build/app/outputs/bundle/release/app-release.aab`.

## 6. Verify it's signed with YOUR key (not debug)

```bash
keytool -printcert -jarfile build/app/outputs/bundle/release/app-release.aab
```

The owner/issuer should be the identity you entered in §1 — **not** "Android
Debug". (If it shows debug, `key.properties` wasn't picked up — re-check §2.)

## 7. Google Play Console

1. **Create the app** (name "Shorivo", default language, app/free, declarations).
2. **Play App Signing:** accept it when prompted (recommended — Google holds the
   final signing key; your upload key just signs uploads). This protects you if
   the upload key is ever lost.
3. **Internal testing track first:** upload the `.aab`, add testers, and install
   from the test link on a real device before going to production.
4. **Store listing:** title, short + full description, app icon (512), feature
   graphic (1024×500), phone screenshots.
5. **Policy / required declarations (rejection-critical):**
   - **Privacy Policy URL** (a public, hosted URL — the in-app text isn't
     enough; host it on the website).
   - **Data safety** form — declare what's collected (name, email, phone,
     approximate/precise location, photos) and that it's not sold; matches the
     app's actual use.
   - **Content rating** questionnaire.
   - **Target audience** (adults; not directed at children).
   - **Ads** declaration (the app shows no ads → "No").
   - **App access:** provide **login credentials for a review account** (a
     business owner account with an active subscription) so Google can test the
     vendor side behind the paywall.
6. **Subscriptions (Monetize → Products → Subscriptions):** create products
   whose IDs exactly match `subscription_packages.store_product_id_android`
   (`com.shorisolutions.shoribook.{sidehustle,solopro,squad}.monthly`). Add a
   **license tester** and test a real sandbox purchase end-to-end.
7. **Promote to production** once internal testing + the checklist pass.

---

## 6b. Backend prerequisites (shared — do before submitting)

From [RELEASE_AUDIT.md](RELEASE_AUDIT.md):

- ☐ Run `20260801000000_fix_reviews_read_policy.sql` (guests can't see reviews
  otherwise).
- ☐ Run `20260801000001_rls_least_privilege.sql` (+ its verify query).
- ☐ Deploy `verify-purchase` and set `GOOGLE_SERVICE_ACCOUNT_JSON` +
  `ANDROID_PACKAGE_NAME` (+ `APPLE_SHARED_SECRET` for iOS) — otherwise purchases
  are trust-the-client.
- ☐ Set `AppLinks.webBaseUrl` (`lib/core/config/app_links.dart`) to the live
  web domain, or every shared booking link is broken.
- ☐ Confirm the Supabase Auth redirect allow-list contains
  `shoribook://auth/callback`.

## Quick smoke test on a real device (release build)

Network loads, login (customer + business), browse marketplace, make a booking,
open reviews, run a sandbox subscription purchase, receive a confirmation.
