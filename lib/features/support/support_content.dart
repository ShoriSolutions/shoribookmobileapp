/// Static copy for the Support / Help screens. Edit the email and legal
/// text here to match your business — the ToS and Privacy text below are
/// a reasonable starting template, not legal advice; have them reviewed
/// before you rely on them.
class SupportContent {
  const SupportContent._();

  /// Where "Contact support" and the 90-day appeal email are sent.
  /// TODO: change this to your real support inbox.
  static const supportEmail = 'support@shorisolutions.com';

  /// Bump this whenever the Terms/Privacy text below materially changes.
  /// Stored on the account at sign-up (terms_version) so you can tell who
  /// accepted which version.
  static const termsVersion = '2026-07.2';

  static const faq = <(String, String)>[
    (
      'How do clients book with me?',
      'Share your booking link or QR code (More → Profile & Marketplace → '
          'Booking link). Clients pick a service, a staff member, and an '
          'available time — bookings then appear in your Appointments and '
          'Calendar.',
    ),
    (
      'Why can\'t I change my business name or category?',
      'To keep marketplace listings stable, your business name and category '
          'can only be changed once every 90 days. After a change, both are '
          'locked until the date shown in the profile editor. If you need to '
          'change it sooner, tap "Appeal this lock" to email our team.',
    ),
    (
      'How do I add staff and set their hours?',
      'Add team members in More → Staff. Set each person\'s working days and '
          'hours in More → Availability → Staff Schedules.',
    ),
    (
      'How do I block off time or set holidays?',
      'Use More → Availability. "Blocked Time" is for one-off gaps; "Special '
          'Days" overrides your regular hours for a specific date (e.g. a '
          'holiday closure or shorter day).',
    ),
    (
      'How do I add my logo and cover photo?',
      'More → Profile & Marketplace → Edit profile, then tap the cover image '
          'or the logo. Images are automatically fitted so they never look '
          'stretched.',
    ),
    (
      'How do I get featured in the marketplace?',
      'In the profile editor, turn on "Request featured listing". Our team '
          'reviews requests before featuring a business.',
    ),
    (
      'How do deposits work?',
      'When you create a booking, toggle "Deposit required" and set the '
          'amount and status. Deposits and payments are handled directly '
          'between you and your client. Customers with a lower trust score '
          'may be asked for a refundable deposit automatically.',
    ),
    (
      'What is a trust score / reputation?',
      'Each customer has a trust score (0–100) based only on booking '
          'behaviour — completed bookings raise it; no-shows and late '
          'cancellations lower it. Cancelling within the allowed window is '
          'free. Low scores can require a deposit or temporarily pause '
          'booking; reliable behaviour restores trust over time. It never '
          'uses your device or location.',
    ),
    (
      'How do I delete my account?',
      'Go to More → Delete account (or Profile → Delete account). You type '
          'DELETE and confirm with a code we email you. Deletion is '
          'permanent, and for a business owner it also removes the business '
          'and all of its data.',
    ),
  ];

  static const termsOfService = '''
Welcome to BetterBooking. By creating an account or using the app you agree to these terms.

1. Your account
You are responsible for the information you enter and for keeping your login secure. You must provide accurate business and contact details.

2. Using the service
BetterBooking helps businesses manage bookings, availability, staff, clients, and a public marketplace listing, and helps customers discover businesses and book appointments. You agree to use it lawfully and not to misuse, disrupt, or attempt to gain unauthorized access to the service or other users' data.

3. Bookings and payments
Appointments, prices, deposits, and any payments are agreements between the business and its clients. BetterBooking provides the tools to schedule and track them but is not a party to those transactions and does not process payments on your behalf.

4. Attendance, cancellations and deposits
Customers are expected to honour the bookings they make. Cancellations made within the allowed window carry no penalty. Late cancellations and no-shows may affect a customer's reputation (see section 5), and a refundable deposit may be required before some bookings are confirmed.

5. Customer reputation and no-show protection
To keep the marketplace reliable, each customer has a trust score based ONLY on their booking behaviour (completed bookings, late cancellations, and no-shows) and on actions taken by our team. Reliable behaviour raises the score over time. Repeated no-shows may lower it and can lead to a deposit requirement, a need for vendor approval, or a temporary suspension of booking ability. Suspensions are temporary. Permanent bans are never automatic — they are only applied after manual review, and customers may appeal a restriction by contacting support. This system does not use your device information or your location (see the Privacy notice).

6. Content you provide
You keep ownership of the content you upload (logo, cover image, gallery photos, descriptions, etc.). You confirm you have the right to upload it, and you grant BetterBooking permission to display that content where needed to run the service, including your public marketplace listing. Do not upload unlawful, infringing, or misleading content; we may remove content that violates these terms.

7. Marketplace listing
Publishing or requesting to be featured is optional. We may review, decline, or remove listings that are inaccurate, unlawful, or violate these terms.

8. Deleting your account
You can delete your account at any time from the app; we confirm the request by email first. Deletion is permanent. If you own a business, deleting your account also permanently deletes that business and its data (services, staff, clients, bookings, images).

9. Availability and changes
We work to keep the service running but provide it "as is", without warranties. Features may change over time. We may update these terms and will make the current version available in the app.

10. Termination
You may stop using the app at any time. We may suspend or close accounts that violate these terms.

11. Contact
Questions about these terms? Email us at the support address in the Support screen.
''';

  static const privacyPolicy = '''
This explains what BetterBooking collects and how it is used.

What we collect
• Account details: your name and email address when you sign up.
• Business profile: business name, category, description, phone, email, address, social links, logo, cover image, and gallery photos that you enter.
• Client contacts: the customer names, phone numbers, WhatsApp numbers, and emails you add or that clients provide when booking.
• Bookings: appointment times, services, staff, prices, deposit status, and notes.
• Reputation data: the outcome of your bookings (completed, cancelled, late-cancelled, no-show) and any related actions by our team, used to calculate your trust score.
• Location (optional): your approximate location, only when you use "Near me" or directions.
• Usage: basic technical information needed to operate and secure the app.

How we use it
• To provide the booking, scheduling, staff, and marketplace features.
• To show your public listing and booking page to clients you share it with.
• To calculate a customer trust score that reduces repeat no-shows (see the Terms).
• To keep the service secure and troubleshoot problems.

How we use your location
Location is used ONLY to help you find nearby businesses, show distance, and open directions. It is never used to calculate your trust score, determine suspensions, or track you.

What we do NOT use
We do not use device fingerprinting, and we do not collect or use hardware identifiers (IMEI, MAC address, serial numbers) or advertising IDs — for trust calculations or for anything else.

Where it's stored
Your data is stored using Supabase (our backend and database provider). Images are stored in Supabase Storage. Public listing details (business name, category, description, images, and the map pin you set) are visible to anyone with your booking link or through the marketplace if you enable it.

Sharing
We do not sell your data. Client contact details you enter are used only to run your bookings and are not shared with other businesses.

Your choices and deletion
You can edit most details anytime in the app. You can permanently delete your account (and, for a business owner, the business and all its data) from the app — we confirm by email first. To request a copy of your data, contact support from the Support screen.

Contact
For any privacy question, email the support address shown in the Support screen.
''';
}
