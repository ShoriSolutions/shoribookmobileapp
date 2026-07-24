/// Static copy for the Support / Help screens. Edit the email and legal
/// text here to match your business — the ToS and Privacy text below are
/// a reasonable starting template, not legal advice; have them reviewed
/// before you rely on them.
class SupportContent {
  const SupportContent._();

  /// Where "Contact support" and the 90-day appeal email are sent.
  /// PLACEHOLDER — change this to your real support inbox before launch.
  static const supportEmail = 'support@shorivo.app';

  /// The number customers can call for help. Shown on the Support tab and
  /// used for tap-to-call.
  /// PLACEHOLDER — change this to your real support line before launch.
  static const supportPhone = '+1 (246) 555-0100';

  /// Bump this whenever the Terms/Privacy text below materially changes.
  /// Stored on the account at sign-up (terms_version) so you can tell who
  /// accepted which version.
  static const termsVersion = '2026-07.3';

  /// Questions a person booking an appointment would ask.
  static const customerFaq = <(String, String)>[
    (
      'Do I need an account to book?',
      'No — you can book as a guest with just your name and phone number. '
          'Creating a free account lets you see all your bookings, save '
          'favourites, and keep your details across devices.',
    ),
    (
      'How do I book an appointment?',
      'Open a business, pick a service and (if offered) a staff member, then '
          'choose an available time and confirm. You\'ll get a confirmation '
          'and a reminder before your appointment.',
    ),
    (
      'Where do I see my bookings?',
      'Tap My bookings. Bookings you made as a guest on this device show up '
          'there too, matched by your phone number.',
    ),
    (
      'How do I cancel or reschedule?',
      'Open the booking from My bookings and tap Cancel or Reschedule. '
          'Cancelling within the business\'s allowed window carries no '
          'penalty; late cancellations and no-shows can affect your trust '
          'score.',
    ),
    (
      'Why was I asked for a deposit?',
      'Some businesses require a deposit to confirm a booking. A refundable '
          'deposit may also be requested automatically if your trust score is '
          'low. Deposits and payments are arranged directly between you and '
          'the business.',
    ),
    (
      'What is my trust score?',
      'Your trust score (0–100) is based only on booking behaviour — '
          'completed bookings raise it; no-shows and late cancellations lower '
          'it. A low score can mean a deposit is required or booking is '
          'briefly paused; reliable behaviour restores it over time. It never '
          'uses your device or location.',
    ),
    (
      'How do I save a business I like?',
      'Tap the heart on a business to add it to your Favourites, so it\'s easy '
          'to find and rebook later.',
    ),
    (
      'How do I change my password or delete my account?',
      'Go to Profile → Account & security. From there you can change your '
          'password (we email a secure link) or delete your account, which is '
          'permanent and confirmed by a code we email you.',
    ),
  ];

  /// Questions a business owner or staff member would ask.
  static const vendorFaq = <(String, String)>[
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
      'How do I make myself bookable as the owner?',
      'Go to More → Staff and tap "Make myself available". This adds you as a '
          'bookable pro so clients can book with you and you show as On duty. '
          'Set your own hours in More → Availability.',
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
      'What is a customer\'s trust score / reputation?',
      'Each customer has a trust score (0–100) based only on booking '
          'behaviour — completed bookings raise it; no-shows and late '
          'cancellations lower it. Low scores can require a deposit or '
          'temporarily pause booking; reliable behaviour restores trust over '
          'time. It never uses their device or location.',
    ),
    (
      'How do I manage my account or change my password?',
      'Everything account-related lives in More → Account & security. From '
          'there you can edit your profile, change your password (we email a '
          'secure link), switch account, or log out.',
    ),
    (
      'How do I delete my account?',
      'Go to More → Account & security → Delete account. You type DELETE and '
          'confirm with a code we email you. Deletion is permanent, and for a '
          'business owner it also removes the business and all of its data.',
    ),
  ];

  static const termsOfService = '''
Welcome to Shorivo. By creating an account or using the app you agree to these terms.

Shorivo has two kinds of user, and this agreement is organised so you can see which parts speak to you:
• VENDORS — business owners and their staff who manage a business, its services, and its bookings.
• CUSTOMERS — people who book appointments with a business.
Sections that apply to everyone come first, followed by vendor-only and customer-only terms.


■ FOR EVERYONE (vendors & customers)

1. Your account
You are responsible for the information you enter and for keeping your login secure. You must provide accurate contact details, and vendors must also provide accurate business details.

2. Using the service
Shorivo helps vendors manage bookings, availability, staff, clients, and a public marketplace listing, and helps customers discover businesses and book appointments. You agree to use it lawfully and not to misuse, disrupt, or attempt to gain unauthorized access to the service or other users' data.

3. Bookings and payments
Appointments, prices, deposits, and any payments are agreements between the vendor and the customer. Shorivo provides the tools to schedule and track them but is not a party to those transactions and does not process payments on anyone's behalf.

4. Deleting your account
You can delete your account at any time from the app; we confirm the request by email first. Deletion is permanent. If you are a vendor who owns a business, deleting your account also permanently deletes that business and its data (services, staff, clients, bookings, images).

5. Service availability and changes
We work to keep the service running but provide it "as is", without warranties. Features may change over time. We may update these terms and will make the current version available in the app.

6. Termination
You may stop using the app at any time. We may suspend or close accounts that violate these terms.

7. Contact
Questions about these terms? Email us at the support address in the Support screen.


■ FOR VENDORS (business owners & staff)

8. Content you provide
You keep ownership of the content you upload (logo, cover image, gallery photos, descriptions, etc.). You confirm you have the right to upload it, and you grant Shorivo permission to display that content where needed to run the service, including your public marketplace listing. Do not upload unlawful, infringing, or misleading content; we may remove content that violates these terms.

9. Your marketplace listing
Publishing or requesting to be featured is optional. We may review, decline, or remove listings that are inaccurate, unlawful, or violate these terms. You are responsible for the services, prices, deposits, and cancellation rules you set for your own bookings.


■ FOR CUSTOMERS (booking appointments)

10. Attendance, cancellations and deposits
You are expected to honour the bookings you make. Cancellations made within the allowed window carry no penalty. Late cancellations and no-shows may affect your reputation (see section 11), and a refundable deposit may be required before some bookings are confirmed.

11. Reputation and no-show protection
To keep the marketplace reliable, each customer has a trust score based ONLY on booking behaviour (completed bookings, late cancellations, and no-shows) and on actions taken by our team. Reliable behaviour raises the score over time. Repeated no-shows may lower it and can lead to a deposit requirement, a need for vendor approval, or a temporary suspension of booking ability. Suspensions are temporary. Permanent bans are never automatic — they are only applied after manual review, and you may appeal a restriction by contacting support. This system does not use your device information or your location (see the Privacy notice).
''';

  static const privacyPolicy = '''
This explains what Shorivo collects and how it is used. Shorivo is used by vendors (businesses and their staff) and by customers (people booking appointments). This notice covers both, and where it matters we label whether a detail applies to vendors or to customers.


■ WHAT WE COLLECT

From vendors (businesses):
• Account details: your name and email address when you sign up.
• Business profile: business name, category, description, phone, email, address, social links, logo, cover image, and gallery photos that you enter.
• Client contacts you add: the customer names, phone numbers, WhatsApp numbers, and emails you save for your bookings.
• Bookings you manage: appointment times, services, staff, prices, deposit status, and notes.

From customers:
• Account details: your name and email address when you sign up.
• Booking details you provide: the name, phone, WhatsApp, and email you enter when booking.
• Reputation data: the outcome of your bookings (completed, cancelled, late-cancelled, no-show) and any related actions by our team, used to calculate your trust score.
• Location (optional): your approximate location, only when you use "Near me" or directions.

From everyone:
• Usage: basic technical information needed to operate and secure the app.


■ HOW WE USE IT

For vendors:
• To provide the booking, scheduling, staff, and marketplace features.
• To show your public listing and booking page to the customers you share it with.

For customers:
• To let you discover businesses, book appointments, and manage your bookings.
• To calculate a trust score that reduces repeat no-shows (see the Terms).

For everyone:
• To keep the service secure and troubleshoot problems.


■ FOR CUSTOMERS: HOW WE USE YOUR LOCATION
Location is used ONLY to help you find nearby businesses, show distance, and open directions. It is never used to calculate your trust score, determine suspensions, or track you.


■ FOR EVERYONE

What we do NOT use
We do not use device fingerprinting, and we do not collect or use hardware identifiers (IMEI, MAC address, serial numbers) or advertising IDs — for trust calculations or for anything else.

Where it's stored
Your data is stored securely in our database, and images are kept in cloud file storage. A vendor's public listing details (business name, category, description, images, and the map pin they set) are visible to anyone with the booking link or through the marketplace if the vendor enables it. The specific service providers we rely on to host and secure your data are available on request from support.

Sharing
We do not sell your data. Client contact details a vendor enters are used only to run that vendor's bookings and are not shared with other businesses.

Your choices and deletion
You can edit most details anytime in the app. You can permanently delete your account — and, for a vendor who owns a business, the business and all its data — from the app; we confirm by email first. To request a copy of your data, contact support from the Support screen.

Contact
For any privacy question, email the support address shown in the Support screen.
''';
}
