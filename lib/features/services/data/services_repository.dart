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

  Future<void> create(Service service, String businessId) async {
    try {
      await _client.from('services').insert(service.toInsertJson(businessId));
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
