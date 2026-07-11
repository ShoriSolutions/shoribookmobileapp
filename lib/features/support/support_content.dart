/// Static copy for the Support / Help screens. Edit the email and legal
/// text here to match your business — the ToS and Privacy text below are
/// a reasonable starting template, not legal advice; have them reviewed
/// before you rely on them.
class SupportContent {
  const SupportContent._();

  /// Where "Contact support" and the 90-day appeal email are sent.
  /// TODO: change this to your real support inbox.
  static const supportEmail = 'support@shorisolutions.com';

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
          'between you and your client.',
    ),
  ];

  static const termsOfService = '''
Welcome to BetterBooking. By creating an account or using the app you agree to these terms.

1. Your account
You are responsible for the information you enter and for keeping your login secure. You must provide accurate business and contact details.

2. Using the service
BetterBooking helps you manage bookings, availability, staff, clients, and a public marketplace listing. You agree to use it lawfully and not to misuse, disrupt, or attempt to gain unauthorized access to the service or other businesses' data.

3. Bookings and payments
Appointments, prices, deposits, and any payments are agreements between your business and your clients. BetterBooking provides the tools to schedule and track them but is not a party to those transactions and does not process payments on your behalf.

4. Content you provide
You keep ownership of the content you upload (logo, cover image, descriptions, etc.). You grant BetterBooking permission to display that content where needed to run the service, including your public marketplace listing.

5. Marketplace listing
Publishing or requesting to be featured is optional. We may review, decline, or remove listings that are inaccurate, unlawful, or violate these terms.

6. Availability and changes
We work to keep the service running but provide it "as is", without warranties. Features may change over time. We may update these terms and will make the current version available in the app.

7. Termination
You may stop using the app at any time. We may suspend or close accounts that violate these terms.

8. Contact
Questions about these terms? Email us at the support address in the Support screen.
''';

  static const privacyPolicy = '''
This explains what BetterBooking collects and how it is used.

What we collect
• Account details: your name and email address when you sign up.
• Business profile: business name, category, description, phone, email, address, social links, logo, and cover image that you enter.
• Client contacts: the customer names, phone numbers, WhatsApp numbers, and emails you add or that clients provide when booking.
• Bookings: appointment times, services, staff, prices, deposit status, and notes.
• Usage: basic technical information needed to operate and secure the app.

How we use it
• To provide the booking, scheduling, staff, and marketplace features.
• To show your public listing and booking page to clients you share it with.
• To keep the service secure and troubleshoot problems.

Where it's stored
Your data is stored using Supabase (our backend and database provider). Public listing details (business name, category, description, images) are visible to anyone with your booking link or through the marketplace if you enable it.

Sharing
We do not sell your data. Client contact details you enter are used only to run your bookings and are not shared with other businesses.

Your choices
You can edit most details anytime in the app. To request a copy of your data or to have your account and data deleted, contact support from the Support screen.

Contact
For any privacy question, email the support address shown in the Support screen.
''';
}
