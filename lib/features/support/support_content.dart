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
  static const termsVersion = '2026-07.4';

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
Last updated 29 July 2026.


1. Acceptance of these terms
These Terms of Service ("Terms") govern access to and use of Shorivo (the "Service"), operated by Shori Solutions ("Shorivo", "we", "us"). By creating an account, setting up a business profile, booking an appointment, or otherwise using the Service, you agree to these Terms. If you don't agree, please don't use the Service.
If you use the Service on behalf of a business, you're confirming you have the authority to bind that business to these Terms, and "you" refers to that business as well as you personally.

2. What Shorivo is
Shorivo is a booking platform that lets independent service businesses (salons, barbers, trainers, and similar) list their services and manage appointments, and lets customers discover those businesses and book with them — with or without creating an account.
Shorivo is not the business you book with. Each business on the platform is an independent operator responsible for the services it provides, the prices and policies it sets, and the quality of the appointment itself. We provide the scheduling, messaging, and booking infrastructure; we are not a party to the service arrangement between you and the business.

3. Accounts and guest bookings
Businesses must create an account to list on Shorivo. Customers may book as a guest, without an account, using their name, phone number, and (optionally) email — or may register an account to keep a booking history, leave reviews, and message businesses directly.
• You're responsible for the accuracy of the information you provide, and for keeping your login credentials confidential.
• You're responsible for activity that happens under your account, including team member accounts a business owner adds.
• Accounts are for real people and real businesses — no impersonation, and no accounts created for someone else without their knowledge.

4. Bookings, deposits, and payment
Each business sets its own service prices, deposit requirements, and cancellation policy, shown to you before you confirm a booking. Booking through Shorivo is an agreement between you and that business.
Shorivo records deposit and payment status that businesses report (for example, cash, bank transfer, or card handled directly with the business) so both sides have an accurate record. Shorivo does not currently process payments or hold funds — any exchange of money happens directly between you and the business, on whatever terms that business states.
A confirmed booking reserves a time slot with a specific business; it does not obligate Shorivo to perform the service, and it isn't a guarantee against a business cancelling, rescheduling, or closing.

5. Cancellations and no-shows
Cancellation windows, late-cancellation fees, and no-show fees are set by each business and shown at booking time. Disputes about a specific cancellation, fee, or no-show are between you and the business — we encourage resolving them directly first, and we may assist where we reasonably can, but Shorivo doesn't adjudicate individual service disputes or issue refunds on a business's behalf.

6. Reviews
Customers may leave a rating and written review after an appointment has taken place. Reviews must reflect a genuine experience with that business — no fake reviews, no reviews for appointments that didn't happen, and no review left or removed in exchange for payment or favors.
Businesses may not create fake customer accounts or bookings to inflate their own rating, and may not offer incentives conditioned on a positive review.

7. Messaging
Signed-in customers can message a business directly through the Service. Messages should stay relevant to bookings and service inquiries. Harassment, spam, unsolicited promotional messages, and abusive language are not allowed on either side, and may result in suspension.

8. Acceptable use
You agree not to:
• Scrape, harvest, or bulk-extract data from the Service.
• Attempt to bypass security controls, rate limits, or access restrictions.
• Use the Service for fraud, harassment, or any unlawful purpose.
• Interfere with another user's account or booking.
• Reverse-engineer or resell the Service without our written permission.
We may suspend or terminate access for violating these Terms, including repeated cancellations, no-shows, abusive behavior toward a business or customer, or fraudulent bookings — reflected in the trust and account-standing tools built into the Service.

9. Business responsibilities
Businesses listing on Shorivo are responsible for:
• Holding any license, permit, or certification required to legally provide their listed services.
• Keeping their service list, pricing, hours, and availability accurate.
• Honoring confirmed bookings, or cancelling/rescheduling with reasonable notice.
• Their own tax, insurance, and regulatory obligations — Shorivo is not a party to these.

10. Intellectual property
The Shorivo name, logo, and software are owned by Shori Solutions. Businesses retain all rights to their own content — service descriptions, photos, and business name — uploaded to their profile, and grant us a license to display it on the Service for the purpose of operating the marketplace.

11. Third-party services
Shorivo relies on third-party infrastructure to operate — including Supabase for hosting, authentication, and the database, and an SMTP email provider for transactional email delivery. Their handling of data is described in our Privacy Policy.

12. Disclaimers and limitation of liability
The Service is provided "as is", without warranties of any kind. We don't guarantee the quality, safety, timeliness, or legality of services offered by businesses on the platform, and we're not liable for disputes, injuries, or losses arising from an appointment itself.
To the fullest extent permitted by law, Shorivo's total liability for any claim relating to the Service is limited to the amount (if any) you paid us directly in the twelve months before the claim arose.

13. Termination
You may stop using the Service and delete your account at any time from your Account page. We may suspend or terminate an account for violating these Terms. Deleting an account does not remove appointment records held by a business you booked with — those remain part of that business's records, unlinked from your account.

14. Changes to these terms
We may update these Terms from time to time. We'll update the "Last updated" date above when we do, and material changes will be communicated to registered users. Continuing to use the Service after an update means you accept the revised Terms.

15. Governing law
These Terms are governed by the laws of Barbados, without regard to conflict-of-law principles, and any dispute not resolved informally will be subject to the exclusive jurisdiction of the courts of Barbados.

16. Contact
Questions about these Terms? Reach us at contact@shorisolutions.com.
''';

  static const privacyPolicy = '''
Last updated 29 July 2026.


1. Scope
This Privacy Policy explains how Shori Solutions ("Shorivo", "we", "us") handles information when you use the Service — as a business, a registered customer, or a guest booking an appointment. It should be read alongside the Terms of Service.

2. Information we collect
Account information. Name and email for registered users; business name, category, location, and contact details for business profiles.
Booking information. When you book an appointment — as a guest or a registered customer — the business you book with collects your name, phone number, and (optionally) email and notes, so they can provide the service. This information belongs to that business's customer records.
Messages. Content you send through the messaging feature, stored so both sides of the conversation can see it.
Reviews. The name, rating, and written review you choose to submit after a completed appointment.
Usage information. Basic technical data such as IP address and request timing, used for security, rate limiting, and abuse prevention.

3. How we use it
• To create and manage bookings between customers and businesses.
• To send booking confirmations, deposit and payment status updates, cancellation and reschedule notices, and (where relevant) reminders.
• To operate messaging and reviews between customers and businesses.
• To secure accounts — for example, detecting repeated failed login attempts — and to prevent fraud, spam, and abuse.
• To maintain, troubleshoot, and improve the Service.

4. How information is shared
We don't sell your information. Information is shared only as follows:
• With the specific business you book, message, or review — that's the point of the Service.
• With service providers who help us operate the Service under contract: Supabase (application hosting, authentication, and database) and our SMTP email provider (delivery of transactional email). They're only permitted to use it to provide that service to us.
• When required by law, or to protect the rights, safety, or property of Shorivo, our users, or the public.

5. Data retention
We keep information for as long as needed to provide the Service and meet legal and record-keeping obligations. Appointment records are retained by the business you booked with as part of their own customer history, even after you delete your account.
Deleting your account does not delete a business you own — an owner must transfer ownership or close the business first, so a business's data isn't lost as a side effect of one person leaving.

6. Your rights and choices
From your Account page, you can:
• View the email associated with your account.
• Permanently delete your account, which requires re-entering your password and — for business owners — resolving business ownership first.
To request a copy of, correct, or ask questions about information a business holds about you as a customer, contact that business directly, or reach us at contact@shorisolutions.com and we'll help route the request.

7. Security
Access to business and customer data is scoped by database-level access controls, so a business can only see its own customers, appointments, and messages, and a customer can only see their own bookings and conversations. Sensitive tokens (like single-use review links for guests) are stored as cryptographic hashes rather than in plain text.
No system is completely immune to risk, but we design access controls at the database layer specifically so that one business or customer can never read another's data through the Service.

8. Cookies and similar technologies
We use a session token to keep you signed in, set by our authentication provider (Supabase). We don't use third-party advertising cookies or cross-site tracking.

9. Children's privacy
The Service is not directed at children, and we don't knowingly collect information from anyone under 16. If you believe a child has provided us with information, contact us and we'll remove it.

10. International data transfers
Our infrastructure providers may process and store data in locations outside your own country. Wherever your information is processed, we require our service providers to protect it consistently with this Policy.

11. Changes to this policy
We may update this Policy from time to time. We'll update the "Last updated" date above when we do, and material changes will be communicated to registered users.

12. Contact
Questions about this Policy or your information? Reach us at contact@shorisolutions.com.


— SHORIVO MOBILE APP ADDENDUM —

Location. The Shorivo mobile app can use your device's approximate location, only when you tap "Near me" or open directions to a business, to show nearby businesses and distances. It is never used to profile you, calculate any trust or reputation score, or track you across the app, and you can decline the permission and still use the rest of the app.
''';

  // Mirrors the Refund Policy published at shorivo.com/refund-policy.
  static const refundPolicy = '''
Last updated 29 July 2026.

This policy covers two separate things: the subscription fees vendors pay Shorivo, and the deposits customers pay to a business. Because Shorivo does not process customer payments, these are handled differently.


■ SHORIVO SUBSCRIPTION FEES (vendors)
Every plan starts with a 14-day free trial. Valid card details are required at signup, but nothing is charged until the trial ends — cancel before then and you are never billed.
• You can cancel a paid subscription at any time; your access continues until the end of the period you have already paid for.
• We do not provide partial-period refunds, credit for unused time, or refunds for features you did not use.
• Genuine billing errors — duplicate charges, charges after cancellation, or other billing mistakes — are refunded. Contact support with the details.


■ CUSTOMER DEPOSITS & PAYMENTS TO A BUSINESS
Payments between a customer and a business happen directly (cash, transfer, or card) outside Shorivo. Shorivo only tracks deposit status — it never processes or holds these funds.
• Whether a deposit is refundable follows that business's own cancellation policy, which is shown to you before you confirm a booking.
• To request a refund, contact the business directly using their stated policy. Shorivo cannot issue refunds on a business's behalf.
• If a business breaks its own stated policy, or you believe you were charged unfairly, contact Shorivo and we will investigate and may take action on the account.


■ HOW TO REQUEST A REFUND
• Subscription issues: email contact@shorisolutions.com with your account email and the charge details.
• Business payment disputes: contact the business first, then escalate anything unresolved to the same address.


■ CHANGES TO THIS POLICY
We may update this policy from time to time; the date above reflects the latest version. See the Terms of Service and Privacy Policy for more information.
''';
}
