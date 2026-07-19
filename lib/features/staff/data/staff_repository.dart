import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_exception.dart';
import '../../../models/availability_models.dart';
import '../../../models/staff_profile.dart';

class StaffRepository {
  final SupabaseClient _client;

  StaffRepository(this._client);

  Future<List<StaffProfile>> fetchAll(String businessId) async {
    try {
      final data = await _client
          .from('staff_profiles')
          .select()
          .eq('business_id', businessId)
          .order('display_order', ascending: true);
      return (data as List)
          .map((e) => StaffProfile.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<StaffProfile> fetchById(String id) async {
    try {
      final data =
          await _client.from('staff_profiles').select().eq('id', id).single();
      return StaffProfile.fromJson(data);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Creates a bookable staff profile for the owner/admin themselves,
  /// linked to their membership via member_id so it shows as "you" and
  /// resolves onto [ActiveMembership.staffProfileId]. Used by the
  /// "make yourself available" action.
  Future<void> addSelfAsStaff({
    required String businessId,
    required String memberId,
    required String name,
  }) async {
    try {
      await _client.from('staff_profiles').insert({
        'business_id': businessId,
        'member_id': memberId,
        'name': name.trim().isEmpty ? 'Me' : name.trim(),
        'is_active': true,
        'is_bookable': true,
      });
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> create(StaffProfile staff, String businessId) async {
    try {
      await _client
          .from('staff_profiles')
          .insert(staff.toInsertJson(businessId));
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> update(String id, StaffProfile staff, String businessId) async {
    try {
      await _client
          .from('staff_profiles')
          .update(staff.toInsertJson(businessId))
          .eq('id', id);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> toggleActive(String id, bool isActive) async {
    try {
      await _client
          .from('staff_profiles')
          .update({
            'is_active': isActive,
            if (!isActive) 'is_bookable': false,
          })
          .eq('id', id);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<List<StaffAvailability>> fetchAvailability(String staffId) async {
    try {
      final data = await _client
          .from('staff_availability')
          .select()
          .eq('staff_id', staffId)
          .order('day_of_week', ascending: true);
      return (data as List)
          .map((e) => StaffAvailability.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
