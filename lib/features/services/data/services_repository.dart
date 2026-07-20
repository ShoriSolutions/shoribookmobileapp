import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_exception.dart';
import '../../../models/service.dart';

class ServicesRepository {
  final SupabaseClient _client;

  ServicesRepository(this._client);

  Future<List<Service>> fetchAll(String businessId, {bool onlyActive = false}) async {
    try {
      var query = _client
          .from('services')
          .select()
          .eq('business_id', businessId);
      if (onlyActive) query = query.eq('is_active', true);
      final data = await query.order('sort_order', ascending: true);
      return (data as List)
          .map((e) => Service.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<Service> fetchById(String id) async {
    try {
      final data = await _client.from('services').select().eq('id', id).single();
      return Service.fromJson(data);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Creates a service and returns its new id (needed to link staff).
  Future<String> create(Service service, String businessId) async {
    try {
      final row = await _client
          .from('services')
          .insert(service.toInsertJson(businessId))
          .select('id')
          .single();
      return row['id'] as String;
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Staff profile ids assigned to a service (empty = any active staff can
  /// perform it, matching the booking flow's serviceAssignedStaffIds logic).
  Future<Set<String>> fetchAssignedStaffIds(String serviceId) async {
    try {
      final data = await _client
          .from('service_staff')
          .select('staff_profile_id')
          .eq('service_id', serviceId);
      return (data as List)
          .map((e) => e['staff_profile_id'] as String)
          .toSet();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Replaces the set of staff assigned to a service. An empty [staffIds]
  /// clears all links (→ any active staff can perform it).
  Future<void> setAssignedStaff(String serviceId, Set<String> staffIds) async {
    try {
      await _client.from('service_staff').delete().eq('service_id', serviceId);
      if (staffIds.isNotEmpty) {
        await _client.from('service_staff').insert([
          for (final id in staffIds)
            {'service_id': serviceId, 'staff_profile_id': id},
        ]);
      }
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> update(String id, Service service, String businessId) async {
    try {
      await _client
          .from('services')
          .update(service.toInsertJson(businessId))
          .eq('id', id);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> toggleActive(String id, bool isActive) async {
    try {
      await _client
          .from('services')
          .update({'is_active': isActive})
          .eq('id', id);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<void> delete(String id) async {
    try {
      await _client.from('services').delete().eq('id', id);
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
