/// A messaging thread between a business and a customer. Either a
/// pre-booking 'enquiry' or a 'booking' conversation tied to an
/// appointment. Per-side state (archive/mute/last-read) lets each party
/// manage their own view. `businessName`/`businessLogoUrl` are joined for
/// the customer's list view; `customerDisplayName` is denormalised for the
/// vendor's.
class Conversation {
  final String id;
  final String businessId;
  final String? customerId;
  final String? customerUserId;
  final String customerDisplayName;
  final String? appointmentId;
  final String type; // 'enquiry' | 'booking'
  final DateTime? lastMessageAt;
  final String? lastMessagePreview;
  final String? lastMessageSender; // 'vendor' | 'customer' | 'system'
  final bool vendorArchived;
  final bool customerArchived;
  final bool vendorMuted;
  final bool customerMuted;
  final DateTime? vendorLastReadAt;
  final DateTime? customerLastReadAt;
  final bool blockedByVendor;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined display fields (populated when the query selects them).
  final String? businessName;
  final String? businessLogoUrl;

  const Conversation({
    required this.id,
    required this.businessId,
    this.customerId,
    this.customerUserId,
    required this.customerDisplayName,
    this.appointmentId,
    required this.type,
    this.lastMessageAt,
    this.lastMessagePreview,
    this.lastMessageSender,
    this.vendorArchived = false,
    this.customerArchived = false,
    this.vendorMuted = false,
    this.customerMuted = false,
    this.vendorLastReadAt,
    this.customerLastReadAt,
    this.blockedByVendor = false,
    required this.createdAt,
    required this.updatedAt,
    this.businessName,
    this.businessLogoUrl,
  });

  bool get isBooking => type == 'booking';

  /// The other party's display name from the given viewer's perspective.
  String titleFor({required bool asVendor}) =>
      asVendor ? customerDisplayName : (businessName ?? 'Business');

  bool archivedFor({required bool asVendor}) =>
      asVendor ? vendorArchived : customerArchived;

  bool mutedFor({required bool asVendor}) =>
      asVendor ? vendorMuted : customerMuted;

  /// Whether there's an unread inbound message for this viewer.
  bool unreadFor({required bool asVendor}) {
    if (lastMessageAt == null) return false;
    final mySide = asVendor ? 'vendor' : 'customer';
    if (lastMessageSender == mySide) return false;
    final lastRead = asVendor ? vendorLastReadAt : customerLastReadAt;
    return lastRead == null || lastMessageAt!.isAfter(lastRead);
  }

  static DateTime? _dt(dynamic v) =>
      v == null ? null : DateTime.parse(v as String);

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final business = json['businesses'] as Map<String, dynamic>?;
    return Conversation(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      customerId: json['customer_id'] as String?,
      customerUserId: json['customer_user_id'] as String?,
      customerDisplayName: json['customer_display_name'] as String? ?? 'Customer',
      appointmentId: json['appointment_id'] as String?,
      type: json['type'] as String? ?? 'enquiry',
      lastMessageAt: _dt(json['last_message_at']),
      lastMessagePreview: json['last_message_preview'] as String?,
      lastMessageSender: json['last_message_sender'] as String?,
      vendorArchived: json['vendor_archived'] as bool? ?? false,
      customerArchived: json['customer_archived'] as bool? ?? false,
      vendorMuted: json['vendor_muted'] as bool? ?? false,
      customerMuted: json['customer_muted'] as bool? ?? false,
      vendorLastReadAt: _dt(json['vendor_last_read_at']),
      customerLastReadAt: _dt(json['customer_last_read_at']),
      blockedByVendor: json['blocked_by_vendor'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      businessName: business?['name'] as String?,
      businessLogoUrl: business?['logo_url'] as String?,
    );
  }
}
