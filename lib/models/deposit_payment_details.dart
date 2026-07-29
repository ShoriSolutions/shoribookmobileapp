/// The business's FirstPay payment details + deposit summary shown to a
/// customer who owns a pending-deposit booking (from get_deposit_payment_details).
/// [status] is 'ok' | 'not_pending' | 'no_payment_method'.
class DepositPaymentDetails {
  final String status;
  final String? provider;
  final double? depositAmount;
  final String? currency;
  final String? serviceName;
  final String? businessName;
  final DateTime? startTime;
  final DateTime? depositDeadline;
  final String? accountNumber;
  final String? accountHolderName;
  final String? email;
  final String? depositInstructions;

  const DepositPaymentDetails({
    required this.status,
    this.provider,
    this.depositAmount,
    this.currency,
    this.serviceName,
    this.businessName,
    this.startTime,
    this.depositDeadline,
    this.accountNumber,
    this.accountHolderName,
    this.email,
    this.depositInstructions,
  });

  bool get isReady => status == 'ok';

  factory DepositPaymentDetails.fromJson(Map<String, dynamic> json) {
    DateTime? dt(String k) =>
        json[k] != null ? DateTime.tryParse(json[k] as String) : null;
    return DepositPaymentDetails(
      status: json['status'] as String? ?? 'no_payment_method',
      provider: json['provider'] as String?,
      depositAmount: (json['deposit_amount'] as num?)?.toDouble(),
      currency: json['currency'] as String?,
      serviceName: json['service_name'] as String?,
      businessName: json['business_name'] as String?,
      startTime: dt('start_time'),
      depositDeadline: dt('deposit_deadline'),
      accountNumber: json['account_number'] as String?,
      accountHolderName: json['account_holder_name'] as String?,
      email: json['email'] as String?,
      depositInstructions: json['deposit_instructions'] as String?,
    );
  }
}
