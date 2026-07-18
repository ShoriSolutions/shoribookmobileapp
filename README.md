# ShoriBooks (shori_book)

A Flutter + Supabase appointment‑booking platform with a **guest‑first**
customer marketplace and an authenticated vendor side, in one app:

- **Customers** browse the marketplace and book **without an account**.
  Creating a customer account is optional (booking history, favourites,
  saved contact details).
- **Vendors** (owner / admin / staff) sign in to a dashboard: calendar,
  appointments, clients, services, staff, deposits, reports, availability,
  a marketplace profile, and a subscription.

Which experience a signed‑in account sees is derived from `profiles.role`
(`entrepreneur` → business, `user` → customer, `admin` → unsupported in the
mobile app; admin actions are exposed as RPCs for the web dashboard).

## Features

**Customer / marketplace (no login required)**
- Opens straight to the marketplace: search, category filters, "Near me"
  distance sort, featured/nearby vendors, and public business profiles
  (photo gallery with full‑screen preview, map + directions, hours,
  services, staff).
- **Guest booking** — pick a service, staff and time, then *Continue as
  guest* (or log in) and confirm. No password, no account.
- Booking confirmation with details, a booking reference, **Add to
  calendar** (.ics), and *Book another*.
- **My bookings for guests** — bookings made on the device are viewable
  (looked up securely by id + phone). Signed‑in customers see all of theirs.
- Guest Profile (Guest User, Become a Vendor, Vendor Login, Support, legal)
  and an optional customer account.

**Vendor / business (authenticated)**
- Home dashboard: daily report (customisable stat cards + staff‑on‑duty)
  and a quick‑share button.
- Availability: business hours, per‑staff schedules, breaks, blocked time,
  special days, and **booking rules** (buffer + per‑day/hour/simultaneous
  limits).
- **Smart scheduling** — a server‑side validator enforces open hours,
  closures, blocks, buffer/overlap and limits before a booking is created
  (DST‑aware via Postgres IANA timezones).
- Clients, services, staff, deposits, and atomic race‑free appointment
  management.
- Reports (week/month/quarter/year, revenue trend + breakdowns).
- Profile & Marketplace: editable profile, logo + cover + gallery, map pin
  (OpenStreetMap) with structured address + geolocation autofill, social
  links, visibility toggles, share cards, 90‑day name/category lock.
- **Reminders & notifications** — provider‑abstracted (push / email /
  official WhatsApp Business / SMS‑future); reminders are queued and sent
  server‑side.
- **Trust & no‑show protection** — server‑calculated customer trust score
  (booking behaviour only; never device/location), booking eligibility gate,
  and admin moderation RPCs.
- **Subscriptions** — dynamic package catalog (Side Hustle / Solo Pro /
  Squad) loaded live from the DB, a **14‑day free trial**, a premium
  bottom‑sheet modal, a launch promo, and Store IAP wiring. *(Feature
  gating / trial‑end lockout is planned — see Roadmap.)*

**Authentication**
- Guest‑first: customers never hit a login wall; a clear **Vendor Login**.
- Forgot‑password via emailed deep link (`shoribook://auth/callback`).
- Strong password policy (8–12 chars + a letter/number/special) with a live
  checklist and show/hide preview.
- **Login attempt limit** (5 → 15‑min lock + a "was this you?" owner alert).
- Switch‑account shortcut.

## Tech stack

- **Flutter** (Dart), **Riverpod** state, **go_router** routing.
- **Supabase** (Postgres + Auth + Storage + Edge Functions) via
  `supabase_flutter`.
- `fl_chart`, `table_calendar`, `qr_flutter`, `image_picker`, `geolocator`,
  `geocoding`, `flutter_map` + `latlong2`, `in_app_purchase`,
  `cached_network_image`, `share_plus`, `url_launcher`, `shared_preferences`,
  `intl`.

## Getting started

### Prerequisites
- Flutter SDK (stable) and Xcode / Android Studio for the target platform.
- A Supabase project.

### 1. Configure environment
Supabase credentials are injected at build time (not bundled). Create
`env/dev.json` from the template:

```bash
cp env/dev.example.json env/dev.json
```

Fill in your project's values (Supabase Dashboard → Project Settings → API):

```json
{
  "SUPABASE_URL": "https://your-project-ref.supabase.co",
  "SUPABASE_ANON_KEY": "your-anon-public-key"
}
```

`env/dev.json` is gitignored.

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Run

```bash
flutter run --dart-define-from-file=env/dev.json
```

`.vscode/settings.json` / `launch.json` pass the config automatically for
IDE launches.

### App icons

Launcher icons are generated from `assets/branding/shoribooks_icon.png`:

```bash
dart run flutter_launcher_icons
```

## Database

SQL migrations live in [`backend/supabase/migrations/`](backend/supabase/migrations/)
and are **additive**. Apply any not yet on your project by pasting them, in
filename order, into the Supabase **SQL Editor**. Broad areas:

- mobile/marketplace support, business self‑registration, profile editing,
  geolocation, per‑day report revenue, photo gallery, account deletion
- trust & no‑show system, reminder system, smart scheduling (buffer/limits)
- structured address fields + registration analytics
- subscriptions (package catalog, trial, purchase recording) + pricing tiers
- guest booking (auth‑optional booking RPC) + guest booking lookup
- login attempt limiting + security alerts, 14‑day trial

**Storage buckets** (created by migrations, public read + owner‑scoped
write): `business-images` (logos/covers/gallery) and `avatars`.

**Edge Functions** ([`backend/supabase/functions/`](backend/supabase/functions/)) —
deploy + configure a provider before they send:
- `process-reminders` — sends queued appointment reminders.
- `send-security-alert` — emails the "login limit reached" alert.

**Required dashboard config**
- Authentication → URL Configuration → **Redirect URLs**: add
  `shoribook://auth/callback` (so password‑reset / invite links open the app).

## Project structure

```
lib/
  core/         # theme, shared widgets, utils (timezone, currency, location,
                # password policy, calendar export), Supabase client
  features/     # feature-first: each has data / application / presentation
  models/       # plain data models (Business, Appointment, Service, …)
  routing/      # go_router config, route paths, bottom-nav shells
backend/
  supabase/migrations/   # additive SQL migrations
  supabase/functions/    # Deno Edge Functions
assets/branding/         # logo + generated app-icon source
env/                     # dev.example.json (template); dev.json is gitignored
```

## Notes

- **Timezones:** business times use the business's IANA timezone (e.g.
  `America/Barbados`), never the device timezone — see
  `core/utils/timezone_offsets.dart`; the scheduling validator uses Postgres
  `AT TIME ZONE` so it's DST‑aware.
- **Email confirmation is on**, so sign‑up returns no session until
  confirmed; a business is finalised, and any pending address drained, on
  first login.
- **Guest data safety:** guests read only their own booking(s) via an RPC
  that requires the appointment id **and** the matching phone; all RLS stays
  enforced.
- **Admin** is web‑only on mobile; admin capabilities are RPCs
  (`admin_trust_action`, `check_permanent_ban_eligibility`,
  `get_registration_analytics`, featured‑listing review).

## Operational setup (not wired by default)

These need provider credentials / store setup before they work end‑to‑end:
- **Reminders & security emails** — implement the Edge Function provider
  `send()` (push/email/WhatsApp), add secrets, schedule a cron.
- **Store IAP** — create the subscription products in App Store Connect /
  Play Console using the `store_product_id_*` values in
  `subscription_packages`; add server‑side receipt validation.

## Roadmap

- **Trial‑end lockout + per‑tier entitlements** — trial grants full access;
  when it ends without a paid plan the account is locked until they
  subscribe, and per‑tier caps (services/staff/deposits/reports/marketplace)
  are enforced client‑ and server‑side. *(Billing/trial are in place; the
  gating is not yet.)*
- **Sign in with Google / Apple / phone‑OTP** at guest checkout.
- **Guest booking management** (cancel/reschedule via email or phone code)
  and **guest → account** history linking.
