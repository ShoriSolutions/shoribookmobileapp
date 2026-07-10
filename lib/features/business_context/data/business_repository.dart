import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_exception.dart';
import '../../../models/business.dart';
import '../../../models/business_role.dart';
import 'active_membership.dart';

class BusinessRepository {
  final SupabaseClient _client;

  BusinessRepository(this._client);

  /// Mirrors the web's getActiveMembership: the first ACTIVE membership
  /// by created_at. The web app has no multi-business switcher either
  /// (it just takes the first row), so this matches it for parity —
  /// only ACTIVE (not INVITED) memberships resolve to a usable context.
  Future<ActiveMembership?> getActiveMembership(String userId) async {
    try {
      final data = await _client
          .from('business_members')
          .select('id, role, status, businesses(*)')
          .eq('user_id', userId)
          .eq('status', 'ACTIVE')
          .order('created_at', ascending: true)
          .limit(1)
          .maybeSingle();

      if (data == null) return null;

      final businessJson = data['businesses'] as Map<String, dynamic>?;
      if (businessJson == null) return null;

      final membershipId = data['id'] as String;
      final role = BusinessRole.fromString(data['role'] as String);
      final business = Business.fromJson(businessJson);

      final staffProfileId = await _findLinkedStaffProfileId(
        businessId: business.id,
        memberId: membershipId,
      );

      return ActiveMembership(
        membershipId: membershipId,
        role: role,
        business: business,
        staffProfileId: staffProfileId,
      );
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// All ACTIVE memberships for this user — used only for a future
  /// multi-business switcher; the MVP always uses the first one.
  Future<List<Map<String, dynamic>>> getAllMemberships(String userId) async {
    try {
      final data = await _client
          .from('business_members')
          .select('id, role, status, businesses(*)')
          .eq('user_id', userId)
          .eq('status', 'ACTIVE')
          .order('created_at', ascending: true);
      return (data as List).cast<Map<String, dynamic>>();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<String?> _findLinkedStaffProfileId({
    required String businessId,
    required String memberId,
  }) async {
    final row = await _client
        .from('staff_profiles')
        .select('id')
        .eq('business_id', businessId)
        .eq('member_id', memberId)
        .maybeSingle();
    return row?['id'] as String?;
  }
}
