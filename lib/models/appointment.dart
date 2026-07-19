/// Appointment status values, verbatim from the DB CHECK constraint —
/// deliberately plain strings (not a Dart enum with a differing name
/// set) so there's never a translation step between DB and UI.
class AppointmentStatus {
  static const pending = 'pending';
  static const confirmed = 'confirmed';
  static const completed = 'completed';
  static const cancelled = 'cancelled';
  static const noShow = 'no_show';

  static const all = [pending, confirmed, completed, cancelled, noShow];
}

class DepositStatus {
  static const notRequired = 'NOT_REQUIRED';
  static const pending = 'PENDING';
  static const paid = 'PAID';
  static const failed = 'FAILED';
  static const refunded = 'REFUNDED';
}

class PaymentMethod {
  static const cash = 'CASH';
  static const bankTransfer = 'BANK_TRANSFER';
  static const card = 'CARD';
  static const online = 'ONLINE';
  static const other = 'OTHER';

  static const all = [cash, bankTransfer, card, online, other];
}

/// Booking source values, verbatim from the DB CHECK constraint. Note:
/// there is deliberately no 'QR' value — the DB constraint doesn't allow
/// it, so a QR-originated booking is recorded as OTHER.
class BookingSource {
  static const online = 'ONLINE';
  static const walkIn = 'WALK_IN';
  static const whatsapp = 'WHATSAPP';
  static const instagram = 'INSTAGRAM';
  static const phone = 'PHONE';
  static const facebook = 'FACEBOOK';
  static const other = 'OTHER';

  static const all = [online, walkIn, whatsapp, instagram, phone, facebook, other];

  static String label(String value) {
    switch (value) {
      case walkIn:
        return 'Walk-in';
      case whatsapp:
        return 'WhatsApp';
      case instagram:
        return 'Instagram';
      case phone:
        return 'Phone';
      case facebook:
        return 'Facebook';
      case online:
        return 'Online';
      default:
        return 'Other';
    }
  }
}

/// An appointment row, with the optional joined fields the app's list/
/// detail queries select (service name, staff name, customer contact).
/// Joined fields are null when not selected by a given query.
class Appointment {
  final String id;
  final String businessId;
  final String? serviceId;
  final String? staffProfileId;
  final String? customerId;
  final DateTime startTime;
  final DateTime endTime;
  final String status;
  final double? price;
  final String? currency;
  final bool depositRequired;
  final double? depositAmount;
  final bool depositPaid;
  final String depositStatus;
  final String? paymentMethod;
  final String? paymentReference;
  final DateTime? depositPaidAt;
  final bool cancellationPolicyAccepted;
  final String? customerName;
  final String? customerPhone;
  final String? customerEmail;
  final String? notes;
  final String bookingSource;
  final String? internalNotes;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined display fields (populated when the query selects them)
  final String? serviceName;
  final String? staffName;
  final String? staffRole;
  final String? businessName;
  final String? businessLogoUrl;
  final String? businessSlug;
  final String? businessTimezone;
  final String? businessPhone;
  final String? businessWhatsapp;
  final String? businessCategory;
  final String? businessAddress;
  final double? businessLatitude;
  final double? businessLongitude;

  const Appointment({
    required this.id,
    required this.businessId,
    this.serviceId,
    this.staffProfileId,
    this.customerId,
    required this.startTime,
    required this.endTime,
    required this.status,
    this.price,
    this.currency,
    required this.depositRequired,
    this.depositAmount,
    required this.depositPaid,
    required this.depositStatus,
    this.paymentMethod,
    this.paymentReference,
    this.depositPaidAt,
    required this.cancellationPolicyAccepted,
    this.customerName,
    this.customerPhone,
    this.customerEmail,
    this.notes,
    required this.bookingSource,
    this.internalNotes,
    required this.createdAt,
    required this.updatedAt,
    this.serviceName,
    this.staffName,
    this.staffRole,
    this.businessName,
    this.businessLogoUrl,
    this.businessSlug,
    this.businessTimezone,
    this.businessPhone,
    this.businessWhatsapp,
    this.businessCategory,
    this.businessAddress,
    this.businessLatitude,
    this.businessLongitude,
  });

  bool get isActive =>
      status != AppointmentStatus.cancelled && status != AppointmentStatus.noShow;

  factory Appointment.fromJson(Map<String, dynamic> json) {
    final service = json['services'] as Map<String, dynamic>?;
    final staff = json['staff_profiles'] as Map<String, dynamic>?;
    final customer = json['customers'] as Map<String, dynamic>?;
    final business = json['businesses'] as Map<String, dynamic>?;

    String? joinedCustomerName;
    if (customer != null) {
      final first = customer['first_name'] as String?;
      final last = customer['last_name'] as String?;
      joinedCustomerName = [
        first,
        last,
      ].where((s) => s != null && s.isNotEmpty).join(' ');
    }

    return Appointment(
      id: json['id'] as String,
      businessId: json['business_id'] as String,
      serviceId: json['service_id'] as String?,
      staffProfileId: json['staff_profile_id'] as String?,
      customerId: json['customer_id'] as String?,
      startTime: DateTime.parse(json['start_time'] as String),
      endTime: DateTime.parse(json['end_time'] as String),
      status: json['status'] as String? ?? AppointmentStatus.confirmed,
      price: (json['price'] as num?)?.toDouble(),
      currency: json['currency'] as String?,
      depositRequired: json['deposit_required'] as bool? ?? false,
      depositAmount: (json['deposit_amount'] as num?)?.toDouble(),
      depositPaid: json['deposit_paid'] as bool? ?? false,
      depositStatus: json['deposit_status'] as String? ?? DepositStatus.notRequired,
      paymentMethod: json['payment_method'] as String?,
      paymentReference: json['payment_reference'] as String?,
      depositPaidAt: json['deposit_paid_at'] != null
          ? DateTime.parse(json['deposit_paid_at'] as String)
          : null,
      cancellationPolicyAccepted:
          json['cancellation_policy_accepted'] as bool? ?? false,
      customerName: (json['customer_name'] as String?) ?? joinedCustomerName,
      customerPhone:
          (json['customer_phone'] as String?) ?? customer?['phone'] as String?,
      customerEmail:
          (json['customer_email'] as String?) ?? customer?['email'] as String?,
      notes: json['notes'] as String?,
      bookingSource: json['booking_source'] as String? ?? BookingSource.online,
      internalNotes: json['internal_notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      serviceName: service?['name'] as String?,
      staffName: staff?['name'] as String?,
      staffRole: staff?['role'] as String?,
      businessName: business?['name'] as String?,
      businessLogoUrl: business?['logo_url'] as String?,
      businessSlug: business?['slug'] as String?,
      businessTimezone: business?['timezone'] as String?,
      businessPhone: business?['phone'] as String?,
      businessWhatsapp: business?['whatsapp_number'] as String?,
      businessCategory: business?['category'] as String?,
      businessAddress: business?['address'] as String?,
      businessLatitude: (business?['latitude'] as num?)?.toDouble(),
      businessLongitude: (business?['longitude'] as num?)?.toDouble(),
    );
  }
}

/// The set of columns + join clauses used for every appointment fetch —
/// a single source of truth so list/detail/dashboard queries never drift
/// from each other.
const String appointmentSelectColumns = '''
  id, business_id, service_id, staff_profile_id, customer_id,
  start_time, end_time, status, price, currency,
  deposit_required, deposit_amount, deposit_paid, deposit_status,
  payment_method, payment_reference, deposit_paid_at,
  cancellation_policy_accepted,
  customer_name, customer_phone, customer_email, notes,
  booking_source, internal_notes, created_at, updated_at,
  services ( name ),
  staff_profiles ( name, role ),
  customers ( first_name, last_name, phone, email, whatsapp_number )
''';

/// Extends [appointmentSelectColumns] with a businesses join — a
/// customer's booking history spans multiple businesses, unlike the
/// Owner/Staff app's queries which are always scoped to one already-known
/// business.
const String customerAppointmentSelectColumns = '''
  id, business_id, service_id, staff_profile_id, customer_id,
  start_time, end_time, status, price, currency,
  deposit_required, deposit_amount, deposit_paid, deposit_status,
  payment_method, payment_reference, deposit_paid_at,
  cancellation_policy_accepted,
  customer_name, customer_phone, customer_email, notes,
  booking_source, internal_notes, created_at, updated_at,
  services ( name ),
  staff_profiles ( name, role ),
  businesses ( name, logo_url, slug, timezone, phone, whatsapp_number, category, address, latitude, longitude )
''';
