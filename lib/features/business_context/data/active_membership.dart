import '../../../models/business.dart';
import '../../../models/business_role.dart';

/// The resolved "who am I, in which business, as what role" context
/// every screen depends on — the Dart equivalent of the web's
/// BusinessMembership type from src/lib/business.ts.
class ActiveMembership {
  final String membershipId;
  final BusinessRole role;
  final Business business;

  /// Non-null only if this user is also a bookable staff_profiles entry
  /// (staff_profiles.member_id -> this membership's id). Used to scope
  /// a STAFF user's own appointments.
  final String? staffProfileId;

  const ActiveMembership({
    required this.membershipId,
    required this.role,
    required this.business,
    this.staffProfileId,
  });
}
