/// Payment provider identifiers (matches payment_profiles.provider). Only
/// FirstPay is implemented for deposits today; the rest are placeholders so the
/// module can grow without changing the interface.
class PaymentProvider {
  static const firstpay = 'firstpay';
  static const wipay = 'wipay';
  static const bankTransfer = 'bank_transfer';
  static const card = 'card';

  static String label(String provider) {
    switch (provider) {
      case firstpay:
        return 'FirstPay';
      case wipay:
        return 'WiPay';
      case bankTransfer:
        return 'Bank Transfer';
      case card:
        return 'Card Payments';
      default:
        return provider;
    }
  }
}

/// Configuration status of a payment method.
enum PaymentStatus { notConfigured, setupRequired, ready }

extension PaymentStatusX on PaymentStatus {
  String get label => switch (this) {
        PaymentStatus.notConfigured => 'Not configured',
        PaymentStatus.setupRequired => 'Setup required',
        PaymentStatus.ready => 'Ready',
      };
}

/// A business's payment profile for one provider. Provider-specific fields live
/// in [details]; FirstPay exposes typed getters below.
class PaymentProfile {
  final String provider;
  final Map<String, dynamic> details;
  final String? depositInstructions;
  final String? paymentNotes;

  const PaymentProfile({
    required this.provider,
    this.details = const {},
    this.depositInstructions,
    this.paymentNotes,
  });

  // FirstPay fields.
  String? get accountHolderName => _str('account_holder_name');
  String? get accountNumber => _str('account_number');
  String? get email => _str('email');

  String? _str(String key) {
    final v = details[key];
    if (v is String && v.trim().isNotEmpty) return v.trim();
    return null;
  }

  /// Whether the required fields for this provider are all present.
  bool get isReady {
    switch (provider) {
      case PaymentProvider.firstpay:
        return accountHolderName != null &&
            accountNumber != null &&
            email != null;
      default:
        return false;
    }
  }

  PaymentStatus get status =>
      isReady ? PaymentStatus.ready : PaymentStatus.setupRequired;

  factory PaymentProfile.fromJson(Map<String, dynamic> json) => PaymentProfile(
        provider: json['provider'] as String,
        details: (json['details'] as Map?)?.cast<String, dynamic>() ?? const {},
        depositInstructions: json['deposit_instructions'] as String?,
        paymentNotes: json['payment_notes'] as String?,
      );

  /// The status for a possibly-absent profile: null → not configured.
  static PaymentStatus statusFor(PaymentProfile? profile) =>
      profile == null ? PaymentStatus.notConfigured : profile.status;

  /// Masks all but the last 4 characters of an account number for display.
  static String maskAccount(String? account) {
    final a = account?.trim() ?? '';
    if (a.isEmpty) return '';
    if (a.length <= 4) return '****';
    return '•••• ${a.substring(a.length - 4)}';
  }
}
