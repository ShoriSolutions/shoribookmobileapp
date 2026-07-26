/// Waitlist status values, verbatim from the DB.
class WaitlistStatus {
  static const active = 'active';
  static const booked = 'booked';
  static const cancelled = 'cancelled';
  static const expired = 'expired';
}

/// A customer's request to be told when a slot opens up at a business — for a
/// service (or any), optionally a specific pro, date, and time/range. Joined
/// display fields are populated when the query/RPC selects them.
class WaitlistEntry {
  final String id;
  final String businessId;
  final String? serviceId;
  final String? staffProfileId;
  final String customerName;
  final String customerPhone;
  final String? customerEmail;
  final DateTime? preferredDate; // date-only (midnight)
  final String? preferredTime; // 'HH:MM'
  final String? preferredTimeStart;
  final String? preferredTimeEnd;
  final String status;
  final DateTime? notifiedAt;
  final DateTime createdAt;

  // Joined display fields.
  final String? serviceName;
  final String? staffName;
  final String? businessName;
  final String? businessLogoUrl;
  final String? businessSlug;
  final String? businessTimezone;
  final String? businessCategory;

  const WaitlistEntry({
    required this.id,
    required this.businessId,
    this.serviceId,
    this.staffProfileId,
    required this.customerName,
    required this.customerPhone,
    this.customerEmail,
    this.preferredDate,
    this.preferredTime,
    this.preferredTimeStart,
    this.preferredTimeEnd,
    required this.status,
    this.notifiedAt,
    required this.createdAt,
    this.serviceName,
    this.staffName,
    this.businessName,
    this.businessLogoUrl,
    this.businessSlug,
    this.businessTimezone,
    this.businessCategory,
  });

  bool get isActive => status == WaitlistStatus.active;

  factory WaitlistEntry.fromJson(Map<String, dynamic> json) {
    final service = json['services'] as Map<String, dynamic>?;
    final staff = json['staff_profiles'] as Map<String, dynamic>?;
    final business = json['businesses'] as Map<String, dynamic>?;
    return WaitlistEntry(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      serviceId: json['service_id'] as String?,
      staffProfileId: json['staff_profile_id'] as String?,
      customerName: json['customer_name'] as String? ?? '',
      customerPhone: json['customer_phone'] as String? ?? '',
      customerEmail: json['customer_email'] as String?,
      preferredDate: json['preferred_date'] != null
          ? DateTime.tryParse(json['preferred_date'] as String)
          : null,
      preferredTime: json['preferred_time'] as String?,
      preferredTimeStart: json['preferred_time_start'] as String?,
      preferredTimeEnd: json['preferred_time_end'] as String?,
      status: json['status'] as String? ?? WaitlistStatus.active,
      notifiedAt: json['notified_at'] != null
          ? DateTime.parse(json['notified_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      serviceName: service?['name'] as String?,
      staffName: staff?['name'] as String?,
      businessName: business?['name'] as String?,
      businessLogoUrl: business?['logo_url'] as String?,
      businessSlug: business?['slug'] as String?,
      businessTimezone: business?['timezone'] as String?,
      businessCategory: business?['category'] as String?,
    );
  }
}

/// Columns + joins for a waitlist read (single-FK embeds, so no
/// disambiguation needed). Matches the shape get_guest_waitlist returns.
const String waitlistSelectColumns = '''
  id, business_id, service_id, staff_profile_id,
  customer_name, customer_phone, customer_email,
  preferred_date, preferred_time, preferred_time_start, preferred_time_end,
  status, notified_at, created_at,
  services ( name ),
  staff_profiles ( name, role ),
  businesses ( name, logo_url, slug, timezone, category )
''';
