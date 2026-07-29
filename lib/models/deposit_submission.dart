/// A customer's proof-of-deposit submission, as the vendor verification list
/// sees it (joined with the appointment's customer/service/time).
class DepositSubmission {
  final String id;
  final String appointmentId;
  final double? amount;
  final String? currency;
  final String proofPath;
  final String? referenceNumber;
  final String? customerNotes;
  final String status; // submitted | approved | rejected | expired | superseded
  final DateTime createdAt;

  // Joined from the appointment.
  final String? customerName;
  final String? serviceName;
  final DateTime? startTime;

  const DepositSubmission({
    required this.id,
    required this.appointmentId,
    this.amount,
    this.currency,
    required this.proofPath,
    this.referenceNumber,
    this.customerNotes,
    required this.status,
    required this.createdAt,
    this.customerName,
    this.serviceName,
    this.startTime,
  });

  factory DepositSubmission.fromJson(Map<String, dynamic> json) {
    final appt = json['appointments'] as Map<String, dynamic>?;
    final service = appt?['services'] as Map<String, dynamic>?;
    return DepositSubmission(
      id: json['id'] as String,
      appointmentId: json['appointment_id'] as String,
      amount: (json['amount'] as num?)?.toDouble(),
      currency: json['currency'] as String?,
      proofPath: json['proof_path'] as String? ?? '',
      referenceNumber: json['reference_number'] as String?,
      customerNotes: json['customer_notes'] as String?,
      status: json['status'] as String? ?? 'submitted',
      createdAt: DateTime.parse(json['created_at'] as String),
      customerName: appt?['customer_name'] as String?,
      serviceName: service?['name'] as String?,
      startTime: appt?['start_time'] != null
          ? DateTime.tryParse(appt!['start_time'] as String)
          : null,
    );
  }
}

/// Reasons a business can pick when rejecting a deposit (spec order).
class DepositRejectReason {
  static const all = <String>[
    'Payment Not Received',
    'Incorrect Amount',
    'Image Unclear',
    'Wrong Account',
    'Other',
  ];
}
