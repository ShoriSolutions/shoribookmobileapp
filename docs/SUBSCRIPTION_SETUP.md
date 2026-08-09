# Subscriptions — Go‑Live Checklist

_A plain‑English guide to switching on paid subscriptions in the Shorivo /
ShoriBooks mobile app. Written for a non‑developer — no coding required for any
step here._

---

## 1. Where things stand

The app already does everything on the software side:

- Customers can pick a plan (**Solo Pro / Squad**, monthly or yearly) and buy it
  through Apple's or Google's in‑app purchase.
- When they buy, the app sends the purchase receipt to our **secure server**,
  which double‑checks it directly with Apple/Google before unlocking the plan.
  (This stops anyone faking a "paid" status.)
- The recurring monthly/yearly charge and any failed‑payment retries are handled
  **by Apple and Google automatically** — we never touch card details.

**What's left is account/credential setup that only the business owner can do.**
None of it is coding — it's creating the products in the store consoles and
pasting three keys into our server dashboard. This guide walks through each one.

There are **three tasks**:

| # | Task | Where | Who |
|---|------|-------|-----|
| A | Create the subscription products | App Store Connect + Google Play Console | Owner |
| B | Get the two store keys | App Store Connect + Google Cloud | Owner |
| C | Paste the three secrets into our server | Supabase dashboard | Owner / dev |

Until these are done, buying shows the price but purchases won't complete for
real (they run in a safe "not configured yet" fallback).

---

## 2. The product IDs we use

These exact IDs must be created in **both** stores so the app can find them.

| Plan | Monthly product ID | Yearly product ID |
|------|--------------------|-------------------|
| Solo Pro | `com.shorisolutions.shoribook.solopro.monthly` | `com.shorisolutions.shoribook.solopro.annual` |
| Squad | `com.shorisolutions.shoribook.squad.monthly` | `com.shorisolutions.shoribook.squad.annual` |

> Set each as an **auto‑renewable subscription**. The yearly IDs may still need
> to be created — until they exist, the app shows the yearly price but tells the
> customer yearly isn't available yet.

App bundle / package name: **`com.shorisolutions.shoribook`**

---

## 3. Task A — Create the products in the stores

### Apple (App Store Connect)
1. Go to **App Store Connect → your app → Subscriptions**.
2. Create a **Subscription Group** (e.g. "Shorivo Plans").
3. Add each subscription above using the **exact product ID** from the table.
4. Set the price and (optionally) a **free‑trial introductory offer**.
5. Fill in the localizations/review notes Apple requires so the product can be
   approved.

### Google (Play Console)
1. Go to **Play Console → your app → Monetize → Subscriptions**.
2. Create each subscription using the **exact product ID** from the table.
3. Add a **base plan** (monthly or yearly) and set the price.
4. Activate the subscription.

---

## 4. Task B — Get the two store keys

### B1. Apple "app‑specific shared secret"
1. App Store Connect → **your app → App Information** (or **Subscriptions**).
2. Find **App‑Specific Shared Secret** → **Generate** (or copy the existing one).
3. Copy the long string. This is the value for `APPLE_SHARED_SECRET`.

### B2. Google service‑account key (JSON)
1. In **Google Cloud Console**, for the project linked to Play:
   - **APIs & Services → Enable APIs** → enable **Google Play Android Developer
     API**.
   - **IAM & Admin → Service Accounts → Create service account**.
   - Give it a name; finish creating it.
   - Open the account → **Keys → Add key → Create new key → JSON** → download it.
2. In **Play Console → Users & permissions**, invite that service‑account email
   and grant it permission to **view financial data / manage orders** (enough to
   read subscription status).
3. The downloaded **JSON file's contents** is the value for
   `GOOGLE_SERVICE_ACCOUNT_JSON` (paste the whole thing as one line).

---

## 5. Task C — Paste the three secrets into our server

In the **Supabase dashboard** for project `hdfuwrlvpswylikjuswj`:

1. Go to **Project Settings → Edge Functions → Secrets** (or
   **Edge Functions → `verify-purchase` → Secrets**).
2. Add these three secrets:

   | Secret name | Value |
   |-------------|-------|
   | `APPLE_SHARED_SECRET` | the string from step B1 |
   | `GOOGLE_SERVICE_ACCOUNT_JSON` | the full JSON from step B2, on one line |
   | `ANDROID_PACKAGE_NAME` | `com.shorisolutions.shoribook` |

3. Save. **That's it** — server‑side verification turns on automatically. No app
   update or code change is needed.

---

## 6. How to confirm it's working

- Do a **test purchase** using an Apple **Sandbox** tester account and a Google
  **licensed/internal‑testing** account.
- After buying, the account should show an **active plan with the correct
  renewal date** (the date comes straight from Apple/Google, so it's trusted).
- If a secret is missing or wrong, the server safely refuses to grant access
  rather than granting it incorrectly — so a failed test means "check the
  secret," never "a customer got free access."

---

## 7. What about renewals and failed payments?

For auto‑renewable in‑app purchases, **Apple and Google handle the actual
recurring charge and the retry if a card fails** — there is nothing to build or
run on our side for the charge itself. A customer's access simply reflects
whether the store says their subscription is still active.

**Optional future polish** (not required for billing to work):
- **Instant renewal sync** — webhooks from Apple (App Store Server
  Notifications) and Google (Real‑Time Developer Notifications) so a renewal,
  cancellation, or refund updates the app immediately instead of the next time
  the customer opens it.
- **Grace period** — a short "your payment failed, please update it" window
  before access is restricted.

---

## 8. One‑line summary for the boss

> The subscription system is fully built and the server that validates purchases
> is already live. To start charging real money we just need to (1) create the
> subscription products in the App Store and Google Play, (2) grab two keys from
> those consoles, and (3) paste three values into our server dashboard. Apple and
> Google handle the recurring billing automatically after that.
