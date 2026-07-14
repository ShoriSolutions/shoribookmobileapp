/// A customer's trust / reputation snapshot, read from their own profile.
/// All values are computed and written server-side (see the trust_system
/// migration) — the app only ever reads these.
class CustomerTrust {
  final int trustScore;
  final int noShowCount;
  final int warningCount;
  final bool depositRequired;
  final DateTime? suspensionUntil;
  final bool permanentBan;

  const CustomerTrust({
    required this.trustScore,
    required this.noShowCount,
    required this.warningCount,
    required this.depositRequired,
    this.suspensionUntil,
    required this.permanentBan,
  });

  factory CustomerTrust.fromJson(Map<String, dynamic> json) => CustomerTrust(
    trustScore: json['trust_score'] as int? ?? 100,
    noShowCount: json['no_show_count'] as int? ?? 0,
    warningCount: json['warning_count'] as int? ?? 0,
    depositRequired: json['deposit_required'] as bool? ?? false,
    suspensionUntil: json['suspension_until'] == null
        ? null
        : DateTime.parse(json['suspension_until'] as String),
    permanentBan: json['permanent_ban'] as bool? ?? false,
  );

  bool get isSuspended =>
      suspensionUntil != null && suspensionUntil!.isAfter(DateTime.now());

  /// Excellent / Good / Fair / Poor / Restricted — mirrors the server's
  /// trust_reputation() bands.
  String get reputation {
    if (trustScore >= 80) return 'Excellent';
    if (trustScore >= 60) return 'Good';
    if (trustScore >= 40) return 'Fair';
    if (trustScore >= 20) return 'Poor';
    return 'Restricted';
  }
}
