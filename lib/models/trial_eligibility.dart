enum TrialStatus { eligible, pending, ineligible, trialing, unknown }

/// Result of the server-side trial check (check_trial_eligibility) and of
/// starting a trial (start_trial). The app never decides eligibility
/// itself — it only reads this.
class TrialEligibility {
  final TrialStatus status;
  final String message;
  final DateTime? trialEndsAt;

  const TrialEligibility({
    required this.status,
    required this.message,
    this.trialEndsAt,
  });

  bool get isEligible => status == TrialStatus.eligible;
  bool get isPending => status == TrialStatus.pending;

  static TrialStatus _parse(String? s) {
    switch (s) {
      case 'eligible':
        return TrialStatus.eligible;
      case 'pending':
        return TrialStatus.pending;
      case 'ineligible':
        return TrialStatus.ineligible;
      case 'trialing':
        return TrialStatus.trialing;
      default:
        return TrialStatus.unknown;
    }
  }

  factory TrialEligibility.fromJson(Map<String, dynamic> json) =>
      TrialEligibility(
        status: _parse(json['status'] as String?),
        message: json['message'] as String? ?? '',
        trialEndsAt: json['trial_ends_at'] == null
            ? null
            : DateTime.tryParse(json['trial_ends_at'] as String),
      );
}
