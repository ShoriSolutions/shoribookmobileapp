# Handoff: ShoriBooks — Marketplace-First Customer App & Vendor App

## Overview
ShoriBooks is a bookings marketplace for Barbados (currency **BBD**). This handoff covers a refactor of the mobile app around one idea: **open straight into a marketplace and book fast**. All informational/marketing content (pricing, about, FAQs) moves to the website; the app is purely booking-focused.

It documents **two experiences that are the SAME Flutter app** (one binary, role-based routing):
- **Customer app** — 16 screens: first-run → marketplace → search → business → 3-step booking → my bookings/profile + account & help.
- **Vendor app** — 20 screens: becoming a vendor (real paywall), run-the-day tools, clients & services, shop setup, and growth/support. Reached from the customer Profile via **"Become a vendor" / "Vendor login"**.

There is only ONE app to build and ship. Customer is the default; the vendor UI appears when the signed-in account has a vendor role.

## About the Design Files
The files in this bundle (`ShoriBooks Marketplace-First.dc.html`, `ShoriBooks Vendor App.dc.html`) are **design references authored in HTML** — prototypes that show intended look, layout, and copy. They are **not production code to copy**. The task is to **recreate these screens as Flutter widgets inside the existing `shoribookmobileapp-main` codebase**, using its established patterns (its state management, routing, theme, and widget conventions). Match the visuals precisely; implement with Flutter, not HTML/CSS.

Each HTML file is a horizontal "canvas" of phone screens. Every screen is wrapped in an on-screen iOS device frame purely for presentation — **the device bezel, status bar, and the outer cream canvas (`#E7E0D2`) are NOT part of the app**. Build only the inner screen content (each screen's root is a full-height column on background `#F8F6F2`).

## Fidelity
**High-fidelity (hifi).** Final colors, type sizes/weights, spacing, radii, shadows, icons, and copy are all intentional and specified below. Recreate pixel-accurately using the codebase's existing components where they exist; where they don't, build to these specs. Icons are **Lucide** line icons (see Design Tokens → Icons).

## Design Tokens

### Color — brand
| Token | Hex | Use |
|---|---|---|
| Sage | `#7A9E8C` | Primary accent, active states, primary fills |
| Sage deep | `#5C8070` | Active nav/text on light, sage text |
| Sage tint | `#EDF3F0` | Sage chip/icon-tile backgrounds |
| Sage tint border | `#cfe0d8` / `#d7e6df` | Borders on sage tints |
| Terracotta | `#D97A4F` | Primary CTA buttons, key highlights, "deposit" markers |
| Terracotta deep | `#b3673a` / `#9a5a2c` | Terracotta text on tint |
| Terracotta tint | `#FCEBDD` | Warning/pending/trial backgrounds |
| Terracotta tint border | `#f2d9c6` | Borders on terracotta tint |
| Cream (app bg) | `#F8F6F2` | Screen background |
| Ink (text) | `#1E1B16` | Primary text |
| Shori-blue | `#A3D0E6` | Tertiary accent (blue category, cover gradients) |

### Color — neutrals & semantic
| Token | Hex | Use |
|---|---|---|
| Muted text | `#78746D` | Secondary/body-muted text |
| Faint text | `#a49d92` / `#9c8f77` / `#b3aca0` | Tertiary labels, inactive nav |
| Card border | `#E8E4DC` | Default card/input border |
| Divider | `#F0ECE3` | In-card row dividers |
| Field muted bg | `#F2EFE8` | Disabled/secondary tiles |
| Success | text `#15803D` on `#DCFCE7` | Confirmed, "Open now", positive trust |
| Pending/warning | text `#9a5a2c` on `#FCEBDD` | Pending, deposit due, trial |
| Destructive | text `#B3543E`, border `#eccdc4`, tint `#F7ECE9` | Cancel, no-show, log out |
| Closed | text `#374151` on `#F3F4F6` | "Closed" status |
| WhatsApp | `#25D366` | WhatsApp action buttons |

### Typography
- **Font:** the app screens use the **system font** (`system-ui / -apple-system`), deliberately, to match the current Flutter build. (The spec's own chrome uses *Figtree*; ignore that for the app — use the platform default / your existing app font.)
- **Scale (screen content):**
  - Big screen title: **28px / 800**, letter-spacing −0.5px (e.g. "Clients", "Categories", "Reports")
  - Pushed-screen header: **18px / 800** (with back chevron)
  - Section header: **14–17px / 800**
  - Stat number: **26px / 800**, letter-spacing −0.5px
  - Body: **14–15px / 400–600**
  - Meta / secondary: **12–12.5px**, color `#78746D`
  - Micro (nav labels, tags): **10.5–11px**
  - Uppercase group label: **12px / 800**, letter-spacing .06–.08em, color `#9c8f77`

### Spacing, radius, shadow
- **Screen padding:** top area starts ~54px (below status bar), horizontal 16–20px.
- **Radius:** inputs/cards 12–16px; larger cards/tiles 16–20px; buttons 12–14px; pills/avatars `999px` / 50%; icon tiles 10–14px.
- **Shadows:**
  - Terracotta CTA: `0 10px 22px rgba(217,122,79,.28)`
  - Sage CTA: `0 10px 22px rgba(122,158,140,.30)`
  - Card lift: `0 6px 18px rgba(30,27,22,.05)`
  - FAB (terracotta): `0 12px 24px rgba(217,122,79,.4)`
  - Sticky footer bar: `0 -6px 18px rgba(30,27,22,.05)`

### Icons
- **Library:** Lucide (line icons). Recreate with `lucide_flutter` or your existing icon set; match the glyphs described per screen.
- **Style:** stroke-width **2.2** default, **2.4** for active/emphasis, **round** caps & joins. Sizes 14–24px inline, 23px in the tab bar.
- On gradient cover/avatar tiles, icons are **white** at ~1.6–1.9 stroke. On tinted category tiles, icons take the tile's accent color.
- Star used in badges/ratings is a filled star; deposit markers are terracotta.

### Bottom navigation (persistent tab bars)
- **Customer:** Home · Search · Categories · Bookings · Profile
- **Vendor:** Home · Calendar · Clients · Services · More
- Bar: white, top border `#E8E4DC`, padding `9px 12–14px 24px` (extra bottom for the home indicator). Active = sage deep `#5C8070` + weight 700 + stroke 2.4; inactive = `#a49d92` + weight 500 + stroke 2.2. Icons 23px above a 10.5px label.

## Business Rules (baked into the designs)
- **Subscription tiers (BBD/mo), vendor side:** Side Hustle **$10**, Solo Pro **$30** (recommended / "Most Popular"), Squad **$50**. **14-day free trial, no card required.** Prices are DB-driven — don't hard-code copy that implies otherwise.
- **Customers never pay a subscription** and never hit a paywall. Booking is **guest-first** (name + phone); sign-in (Apple / Google / Email / Phone) is always optional and additive (syncs bookings & favourites).
- **Category/business-name lock:** after vendor setup, name & category lock for 90 days (keeps marketplace listings stable).
- **Trust score:** per-client 0–100; high shows green, low shows amber; drives whether deposits are required.
- **Deposits / no-show protection:** vendor-configurable (percentage or fixed; keep-on-no-show); reduces no-shows.
- **Smart validator** enforces working hours, buffers, booking window, and min notice on every booking (manual or online).
- **Reminders/automations** are sent over WhatsApp (SMS fallback): confirmation, 24h, 2h, review request, win-back.

---

## Screens — Customer App (`ShoriBooks Marketplace-First.dc.html`)

**01 · First run** — One light, skippable intro slide, then straight into the marketplace. No pricing/about. CTA "Get started"; skip affordance. Logo tile on cream.

**02 · Marketplace (home)** — The centrepiece. Top: location ("Bridgetown, Barbados") + a big question headline; one search field. Then **Featured** horizontal cards (236px wide: 126px gradient cover with white category icon, "★ Featured" badge top-left, heart top-right, name + area + "Open now"/distance chips) and **Near you** list rows (78px gradient cover w/ white icon, name, category·area, status + distance chips, chevron). Category chip row uses line icons. Bottom nav (Home active).

**03 · Search & map** — Results as a map with terracotta teardrop pins + one larger sage active pin, a recenter button (top-right), and a peeking result card at bottom (66px cover, name, "Open now"/"from $40" chips, terracotta **Book** button). List/Map toggle is one tap. Bottom nav (Search active).

**04 · Business profile** — Booking-first. 210px gradient hero (white category icon, back + share + heart overlays). Name (23px/800), chips (category / Open now / 📍distance·street as a pin-icon pill). Row of actions: **WhatsApp** (green) + **Call** (sage tint). About paragraph. **Services** list (name, duration, price sage, chevron) — each row jumps into booking. Sticky bottom **Book** bar.

**05 · Pro, date & time (one screen)** — Collapses the old 4 steps. Header "Book" + selected service summary card (44px cover, name, duration·business, price + Change). **Choose your pro:** horizontal avatars (56px) — first is "Any" (users icon, sage tint), others are initials; selected has a sage ring + check badge. **Pick a date:** horizontal day chips (52px; selected = sage fill white; unavailable dimmed). **Available times:** 3-col grid of time pills (selected = sage fill; taken = muted). Sticky footer: terracotta **Continue** + summary line.

**06 · Confirm — guest-first** — Summary card (service, pro, date/time, price). Guest fields: **Name + Phone** only, big and first. Collapsed "Sign in for faster checkout" (Apple/Google/Email/Phone) stays optional below. Deposit note if required. Sticky terracotta **Confirm booking**.

**07 · Confirmed** — Success state: green check, "You're booked", booking **reference** (mono), key details, **Add to calendar**, and a soft "Create an account to manage bookings" nudge (never a wall).

**08 · My bookings** — Tab. Note "Bookings made on this device" (phone icon) for guests. Upcoming list: cards with 60px gradient cover (white icon), business name, service·pro, date/time + status chip (Confirmed green / Deposit due amber), chevron. Bottom nav (Bookings active).

**09 · Profile** — Light & guest-first. Header identity (guest or signed-in). Rows for account/prefs. **"For businesses"** card with two rows → **Become a vendor** (storefront icon) and **Vendor login** (login icon); **both link into the Vendor app**. Footer "ShoriBooks v1.0 · Shori Solutions". Bottom nav (Profile active).

**10 · Categories** — Tab. 2-col grid of category tiles (120px; pastel bg per category, **line icon in the tile's accent color** top-left, name + "N nearby" count). Taxonomy: Barbers, Nail techs, Lash artists, Brow artists, Estheticians, Hair stylists, Personal trainers, Everything else.

**11 · Favourites** — Reached from Profile. 2-col grid of saved businesses (104px gradient cover, white icon, filled terracotta heart top-right, name + area). Sign-in syncs across devices.

**12 · Booking detail** — Confirmed banner (green). Business card. Details card (date/time, duration·price, Ref mono) each with a sage leading icon. Small static map with a pin. Actions: **Reschedule** (sage tint) + **Cancel** (destructive) + **Add to calendar**. Cancellation policy note (free >24h before).

**13 · Notifications** — List of cards: 38px rounded icon tile (colored by type) + title + body + timestamp; unread dot (terracotta). Types: reminder (bell/sage), confirmed (check/green), deposit due (currency/terracotta), "new in your area" (storefront/blue).

**14 · Log in** — "Continue as guest" stays **top-right** (never a wall). Logo, "Welcome back", Email + Password (eye toggle), "Forgot password?", terracotta **Log in**, divider, **Continue with Apple** / **Continue with Google**, "New here? Create account".

**15 · Sign up** — "Create your account (optional)". Full name, Email, Password with a **live checklist** (8–12 chars + letter / number / special — matches real policy). Terracotta **Create account**, terms note, "Have an account? Log in".

**16 · Help & FAQ** — Search field (pill). Expandable FAQ list (first item open): booking, guest, cancel/reschedule, trust score, reminders. Sage "Still need a hand?" contact card → **Contact support** (support@shorisolutions.com).

---

## Screens — Vendor App (`ShoriBooks Vendor App.dc.html`)

### Becoming a vendor
**V1 · Become a vendor (set up business)** — Back header. Intro "Free for 14 days". Fields: Business name, Category (scissors icon, chevron), Phone + WhatsApp (2-col), Area (pin icon). Sage-tint note with **lock icon**: name/category lock 90 days. Sticky terracotta **Continue to plans**.

**V2 · Choose your plan** — Sage-tint pill (gift icon): "14-day free trial · no card needed". **Solo Pro $30** card is emphasized (2px sage border, shadow, star **MOST POPULAR** badge, check-ringed) with feature checklist. **Side Hustle $10** and **Squad $50** as compact rows. Sticky sage **Start free trial** + "Cancel anytime".

**V3 · Trial started** — Big sage success circle + check, "You're all set!", unlocked-features list (checks), terracotta-tint pill (hourglass) "14 days left", terracotta **Go to dashboard**.

### Run the day
**V4 · Home dashboard** — "Good morning / Bridgetown Fades" + share icon. Terracotta-tint **trial banner** (hourglass) "Trial · 14 days left · Upgrade". "Today" report cards (2×2 grid: Bookings, Revenue sage, Completed, No-show terracotta) with "Edit cards". **On duty** staff avatars + Add. **Next up** appointment rows (time, client, service·staff, status chip). Bottom nav (Home active).

**V5 · Calendar** — Title + "Today" chip. Month grid (booked-day dots: sage = normal, terracotta = deposit due; today = sage fill; selected = sage outline). Day agenda list (colored left bar, time+duration, client, service·staff). Terracotta **FAB (+)** bottom-right. Bottom nav (Calendar active).

**V6 · Appointment detail** — Status chip + Ref. Client card (avatar, name, phone, **trust score**). **WhatsApp** + **Call**. Details rows (service, when, staff, price, deposit). Actions: **Mark complete** (sage) + **No-show** (destructive) + **Cancel appointment**.

**V7 · New booking** — Manual add (DM/call/walk-in). CLIENT (with Change), SERVICE (chevron), STAFF + DATE (2-col), TIME grid, **Require deposit** toggle. Sticky terracotta **Create booking**. Note: smart validator still enforces hours/buffers/limits.

### Clients & services
**V8 · Clients** — Title + add (sage). Search. Filter chips (All active / Regulars / New / Flagged). "248 clients · 31 regulars". List rows: avatar (initials), name, visits·last visit, **trust pill** (green high / amber low / "New"). Bottom nav (Clients active).

**V9 · Client profile** — Back header + overflow. Centered avatar + name + "client since"·phone. 3 stats (Visits, Spent sage, Trust green). **Message** (WhatsApp) + **New booking** (sage). **Private note** card (editable, pencil). **Booking history** list. (Pushed screen — no bottom nav.)

**V10 · Services** — Title + add. "Drag to reorder". Grouped ("Haircuts", "Beard & extras") with count; rows: drag handle, name, duration (+ deposit tag), price. Hidden service shown dimmed. Bottom nav (Services active).

**V11 · Edit service** — Back header (X). NAME, DESCRIPTION, DURATION chips (30/45/60/90; 45 selected), PRICE + DEPOSIT (2-col), **OFFERED BY** staff chips (avatar + name), **Visible in marketplace** toggle (on). Sticky terracotta **Save service**. (Pushed — no nav.)

### Set up shop (behind "More")
**V12 · More** — Title. Business card (logo tile, name, "Barbershop · Broad St", "View listing"). Grouped menu cards — **Business** (Staff, Availability, Deposits & payments, Marketplace profile), **Grow** (Reports, Reminders & automations), **Account** (Subscription — trial state in terracotta, Help & support, Log out — destructive). Each row: colored icon tile + title + subtitle + chevron. Bottom nav (More active).

**V13 · Staff** — Back header. Sage-tint note "3 of 5 staff used on your Squad plan". Staff rows (avatar, name, role·today's hours, On/Off pill). Dashed **Add staff member**. Explainer note. (Pushed — no nav.)

**V14 · Availability** — Back header. **Working hours** card: Mon–Sun rows (day, time range, toggle; Sun closed/off). **Booking rules** card: Buffer between bookings (10 min), Booking window (30 days), Min notice (2 hours). (Pushed — no nav.)

**V15 · Deposits & payments** — Back header. **Require deposits** toggle (on) + explainer. DEFAULT DEPOSIT segmented (Percentage/Fixed) + amount grid (20/50/75/Full; 50% selected). **No-show fee** = Keep deposit (destructive text). **Payout account** card (bank ****3092, next-day). Sage-tint tip note (info icon). (Pushed — no nav.)

**V16 · Marketplace profile** — Back header. Note "This is your public listing". **Live preview card** (92px blue→sage gradient cover, logo tile overlap, name + rating "4.9 (214)", category·area·distance). ABOUT (editable), PHOTOS (3-up grid + dashed add), rows (Category, Hours, Booking link & QR). Sticky sage **Save & publish**. (Pushed — no nav.)

**V17 · Subscription** — Back header. **Dark card** (`#1E1B16`): "Current plan / Solo Pro / $30 BBD after trial" + terracotta-tint pill "Free trial · 14 days left · renews 2 Aug". Manage rows (Change plan, Payment method → Add card, Billing history). OTHER PLANS (Side Hustle $10, Squad $50). **Cancel trial** (destructive). (Pushed — no nav.)

### Grow & support
**V18 · Reports** — Title + period chip ("This month"). Revenue card ($5,340, +12% green pill, 4-bar weekly chart w/ current week sage). Metrics 2×2 (Bookings, Avg ticket, Rebook rate green, No-show rate terracotta). **Top services** list (count·revenue). **Top staff** (2 cards, avatar + revenue). Bottom nav (More active / from More).

**V19 · Reminders & automations** — Back header. Sage-tint note "Sent free over WhatsApp, SMS fallback". Toggle cards: Booking confirmation (on), 24-hour reminder (on), 2-hour reminder (on), Review request (on), Win-back (off). (Pushed — no nav.)

**V20 · Help & support** — Back header. Search. POPULAR TOPICS list (deposits, staff, payouts, plan). STILL STUCK: **Chat on WhatsApp** (green, "replies in under an hour") + **Email support** (help@shoribooks.com). Footer "ShoriBooks for Business · v2.4.0". (Pushed — no nav.)

---

## Interactions & Behavior
- **Navigation:** persistent bottom tab bar per role (see tokens). Pushed screens (detail/edit/settings) use a back chevron (or X for modals) and **hide** the tab bar.
- **Booking flow:** Profile → tap a service → **V05 combined pro/date/time** → **V06 confirm (guest)** → **V07 confirmed**. Guest path requires only name + phone.
- **Role switch:** customer **Profile → Become a vendor / Vendor login** enters the vendor side; vendor header links back to the customer app. In the real app this is one app switching on account role, not a separate binary.
- **Toggles/segments/chips:** selected = sage fill (white content) or sage border; unselected = white + `#E8E4DC` border; disabled = `#F2EFE8` / reduced opacity.
- **Destructive actions** (cancel, no-show, log out, cancel trial) use `#B3543E`.
- **Empty/guest states:** "Bookings made on this device"; favourites/bookings sync after sign-in.
- **Form validation:** live password checklist (8–12 chars + letter + number + special); phone required for guest booking.

## State Management (use the codebase's existing approach)
- Session/role: guest vs. customer vs. vendor (drives routing & tab bar).
- Marketplace: location, search query, category filter, featured/nearby lists, favourites.
- Booking draft: business, service, staff (or "Any"), date, time slot, deposit-required, guest contact.
- Bookings: upcoming/past, status (confirmed/pending/deposit-due/completed/no-show/cancelled), reference.
- Vendor: subscription (tier, trial days left, renewal), calendar/appointments, clients (+trust, notes, history), services (+groups, visibility, deposit), staff (+schedules), availability rules, deposit config, payout account, reminder toggles, reports (period-scoped).

## Assets
- **Logo:** `assets/shoribookslogo.png` (included) — used in headers, More, login, marketplace-profile tiles.
- **Icons:** Lucide line set (recreate via your Flutter icon library). Specific glyphs are named per screen above.
- **Photography:** none supplied. Business covers/avatars currently use **gradient placeholders with a white category line icon**, and category tiles use **accent-colored line icons**. When real vendor photos exist, they replace the gradient covers; keep the rounded corners.
- **Gradients used for placeholders:** sage `135deg,#7A9E8C→#5C8070`; terracotta `135deg,#E39A72→#D97A4F`; blue `135deg,#BADAEA→#A3D0E6`.

## Files
- `ShoriBooks Marketplace-First.dc.html` — all 16 customer screens (canvas of device frames).
- `ShoriBooks Vendor App.dc.html` — all 20 vendor screens.
- `support.js`, `ios-frame.jsx` — runtime + device-frame used to render the mockups (presentation only; **not** to be reimplemented).
- `assets/shoribookslogo.png` — the app logo.

### Viewing the mockups
These are `.dc.html` files that load a small runtime and mount screens inside a device frame. Open them from a **local static server** in the handoff folder (e.g. `python3 -m http.server` then browse to the file) so the `./support.js` and `./ios-frame.jsx` imports resolve. Read the inner screen markup directly in the HTML for exact values.

> Note: the mockups were built on the ShoriBooks palette from the current Flutter app (not the project's "Organic" design system). Implement against the tokens above / your app's theme.
