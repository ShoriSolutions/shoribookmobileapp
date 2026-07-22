# ShoriBooks — Web Admin Dashboard: feature list

The **admin** role (`profiles.role = 'admin'`) is intentionally **web-only** —
the mobile app treats it as unsupported. All admin capability lives in the
Supabase backend as `SECURITY DEFINER` RPCs (each checks `is_admin()`), so in
most cases the web dashboard only needs to **build UI on top of an existing
RPC** — no new backend.

Legend: ✅ = backend already exists (build UI) · 🟡 = data exists, build a view
· 🔧 = needs a small backend addition.

---

## A. Admin actions that already exist (build UI only)

### 1. Customer trust & moderation ✅
RPC: `admin_trust_action(p_user_id uuid, p_action text, p_value int, p_notes text)`
— one entry point; every action is audit-logged to `trust_events`. Actions:

| Action (`p_action`) | What it does | `p_value` |
|---|---|---|
| `issue_warning` / `remove_warning` | Warn a customer / undo | — |
| `require_deposit` / `remove_deposit` | Force / clear a deposit requirement | — |
| `suspend` / `lift_suspension` | Temporarily block booking / undo | days (default 7) |
| `adjust_score` | Set a new trust score | new score (0–100) |
| `approve_appeal` | Approve a customer's appeal | new score |
| `permanent_ban` / `remove_permanent_ban` | Permanent ban / undo | — |

- Gate before a permanent ban: `check_permanent_ban_eligibility(p_user_id)`
  (returns whether the customer meets the criteria).
- Admins can **read all** `trust_events` and customer trust rows (RLS already
  grants this via `is_admin()`), so the dashboard can show a per-customer
  history + current score/reputation/suspension state.

### 2. Registration & growth analytics ✅
RPC: `get_registration_analytics()` — **aggregate only** (privacy-safe, never
individual addresses). Returns counts `by_role`, `by_country`, `by_region`.
Build charts/tables from it.

### 3. Admin role check ✅
`is_admin()` — reuse for gating every admin screen/route in the web app.

---

## B. Data already in the DB to surface as admin views 🟡

These tables/columns exist (from recent work) and are useful for an admin or
support/troubleshooting console — build read-only views (admin reads via
service role or an `is_admin()`-gated RPC/policy):

- **Subscriptions & billing** — `businesses.subscription_status`,
  `trial_ends_at`, `auto_renew`, `billing_period`, `current_period_end`;
  `subscription_packages` catalog (name, price, features, popular flag, store
  product ids incl. **annual**).
- **Pricing config** — `app_config.annual_discount_percent` (and the table is
  the home for future promo/coupon/referral configs). Admin should be able to
  **edit** this value (changes annual pricing app-wide, no deploy).
- **Client blocking audit** — `customer_block_log` (which vendor blocked which
  customer, reason, when). `customers.is_blocked/blocked_reason/blocked_at`.
- **Reminder delivery** — `reminder_queue` (status/channel/retries/errors) and
  `trial_reminder_log` (which trial notices were sent). Great for "why didn't
  this reminder send?" support.
- **Time-zone troubleshooting** — appointments store **UTC** + the
  `customer_timezone`; `businesses.timezone`. An admin view showing stored UTC
  + both converted local times makes booking-time disputes trivial to debug.
- **Businesses / staff / services / appointments** — standard admin listing,
  search, and drill-down (all already modelled).

---

## C. Featured-listing review ✅

- Vendors set `businesses.featured_requested = true` ("please feature us");
  `is_featured` is **admin-only**.
- RPC: `admin_set_featured(p_business_id uuid, p_featured boolean)` — admin
  approves/denies and toggles `is_featured` (clears `featured_requested`).
  Build a review queue over `businesses where featured_requested = true`.

---

## D. Features that still need backend work 🔧

Nice-to-haves an admin dashboard would want that aren't built yet:

- **Approve/deny featured requests** (see C).
- **Store receipt validation + renewal handling** — IAP products (monthly +
  annual) are wired client-side; move receipt validation to an Edge Function
  and record entitlement/renewals server-side (see `FEATURE_NOTES.md`).
- **Payments/payouts oversight** — deposits are vendor-managed today; there is
  no platform payout/refund system to administer.
- **Per-tier plan enforcement** — the trial-end access gate exists; finer
  per-tier caps (services/staff/deposits/reports) would be enforced here.
- **Broadcast/announcements, coupon campaigns, referral rewards** — `app_config`
  is the intended config home; the mechanics aren't built.

---

## Notes for whoever builds it
- Everything in **A** is callable today via `supabase.rpc('...')` with an admin
  session — start there for the quickest wins (trust moderation + analytics).
- Admin reads of other users' data should go through the **service role** (in a
  secure server context) or `is_admin()`-gated RPCs/policies — never the anon
  key.
- Keep the mobile app's admin-unsupported stance: admin is a **web** surface.
