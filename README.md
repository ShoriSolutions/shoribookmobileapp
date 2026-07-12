# BetterBooking (shori_book)

A Flutter + Supabase appointment-booking platform with two experiences in one app:

- **Business** (owner / admin / staff) — dashboard, calendar, appointments, clients, services, staff, deposits, reports, availability, and a marketplace profile.
- **Customer** (marketplace) — discover businesses, view profiles, book appointments, and manage bookings and favourites.

Which experience a signed-in account sees is derived from its `profiles.role` (`entrepreneur` → business, `user` → customer).

## Features

**Business side**
- Home dashboard with a daily report (customisable stat cards + staff-on-duty) and a quick-share floating button.
- Availability: business hours, per-staff schedules, blocked time, and special days.
- Clients, services, staff, deposits, and appointment management (with atomic, race-free booking).
- Reports: week / month / quarter / year with a revenue trend line and breakdowns.
- Profile & Marketplace: editable business profile, logo + cover + photo gallery (max 10), map pin, social links, visibility toggles, share-link cards, and a 90-day name/category edit lock.
- Help & Support: FAQ, Terms of Service, and Privacy/data documents.

**Customer side**
- Discover with search, category filters, and a "Near me" distance sort.
- Public business profiles with photos, map + directions, hours, services, and staff.
- Booking wizard, my bookings, and favourites.

## Tech stack

- **Flutter** (Dart), **Riverpod** for state, **go_router** for routing.
- **Supabase** (Postgres + Auth + Storage) via `supabase_flutter`.
- `fl_chart`, `table_calendar`, `qr_flutter`, `image_picker`, `geolocator`, `flutter_map` + `latlong2`, `cached_network_image`, `share_plus`, `url_launcher`, `shared_preferences`, `intl`.

## Getting started

### Prerequisites
- Flutter SDK (stable channel) and Xcode / Android Studio for the target platform.
- A Supabase project.

### 1. Configure environment
Supabase credentials are injected at build time (not bundled as assets). Create `env/dev.json` from the template:

```bash
cp env/dev.example.json env/dev.json
```

Then fill in your project's values (Supabase Dashboard → Project Settings → API):

```json
{
  "SUPABASE_URL": "https://your-project-ref.supabase.co",
  "SUPABASE_ANON_KEY": "your-anon-public-key"
}
```

`env/dev.json` is gitignored — your keys never get committed.

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Run

```bash
flutter run --dart-define-from-file=env/dev.json
```

The included `.vscode/settings.json` sets `dart.flutterRunAdditionalArgs` so IDE launches pick up the config automatically; the `.vscode/launch.json` configs do the same.

## Database

SQL migrations live in [`backend/supabase/migrations/`](backend/supabase/migrations/) and are **additive**. Apply any that aren't yet on your project by pasting them, in filename order, into the Supabase **SQL Editor** and running them. They add the mobile/marketplace support, business self-registration, profile editing, geolocation, per-day report revenue, and the photo gallery.

Business logos, covers, and gallery photos are stored in a public `business-images` Storage bucket (created by a migration), with owner/admin write policies scoped to each business's folder.

## Project structure

```
lib/
  core/         # theme, shared widgets, utils (timezone, currency, location), Supabase client
  features/     # feature-first: each has data / application / presentation
  models/       # plain data models (Business, Appointment, Service, …)
  routing/      # go_router config, route paths, bottom-nav shell
backend/
  supabase/migrations/   # additive SQL migrations
env/            # dev.example.json (template); dev.json is gitignored
```

## Notes

- **Timezones:** business-facing times use a fixed-offset business timezone (e.g. `America/Barbados`), never the device timezone — see `core/utils/timezone_offsets.dart`.
- **Email confirmation is on**, so sign-up returns no session until the email is confirmed; business creation is finalised on first login.
