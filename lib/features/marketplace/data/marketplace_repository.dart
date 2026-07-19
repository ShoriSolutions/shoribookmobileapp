import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_exception.dart';
import '../../../models/availability_models.dart';
import '../../../models/business.dart';
import '../../../models/service.dart';
import '../../../models/staff_profile.dart';

class MarketplaceRepository {
  final SupabaseClient _client;

  MarketplaceRepository(this._client);

  /// Live, real search — replaces the web homepage's hardcoded fake
  /// provider list. Only businesses accepting bookings are discoverable.
  Future<List<Business>> search({
    String? query,
    String? category,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      var q = _client
          .from('businesses')
          .select()
          .eq('booking_enabled', true)
          .neq('status', 'not_accepting_bookings');

      if (category != null && category.isNotEmpty) {
        q = q.eq('category', category);
      }
      if (query != null && query.trim().isNotEmpty) {
        final term = query.trim();
        q = q.or('name.ilike.%$term%,category.ilike.%$term%,address.ilike.%$term%');
      }

      final data = await q
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);
      return (data as List)
          .map((e) => Business.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<Business?> fetchBySlug(String slug) async {
    try {
      final data = await _client
          .from('businesses')
          .select()
          .eq('slug', slug)
          .maybeSingle();
      return data == null ? null : Business.fromJson(data);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<List<Service>> fetchServices(String businessId) async {
    try {
      final data = await _client
          .from('services')
          .select()
          .eq('business_id', businessId)
          .eq('is_active', true)
          .order('sort_order', ascending: true);
      return (data as List)
          .map((e) => Service.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<List<StaffProfile>> fetchStaff(String businessId) async {
    try {
      final data = await _client
          .from('staff_profiles')
          .select()
          .eq('business_id', businessId)
          .eq('is_active', true)
          .order('display_order', ascending: true);
      return (data as List)
          .map((e) => StaffProfile.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// serviceId -> set of staff_profile_ids who can perform it. An empty
  /// set for a service (no rows at all) means "any active staff can
  /// perform it", mirroring the web's BookingFlow.tsx
  /// serviceAssignedStaffIds logic.
  Future<Map<String, Set<String>>> fetchServiceStaffLinks(
    String businessId,
  ) async {
    try {
      final data = await _client
          .from('service_staff')
          .select('service_id, staff_profile_id, services!inner(business_id)')
          .eq('services.business_id', businessId);
      final result = <String, Set<String>>{};
      for (final row in (data as List).cast<Map<String, dynamic>>()) {
        final serviceId = row['service_id'] as String;
        final staffId = row['staff_profile_id'] as String;
        (result[serviceId] ??= {}).add(staffId);
      }
      return result;
    } catch (e) {
      throw AppException.from(e);
    }
  }

  /// Weekly hours for several businesses in one query, grouped by
  /// business id — used to compute "Open now" on marketplace lists
  /// without an N+1 fetch per card.
  Future<Map<String, List<BusinessHours>>> fetchHoursForBusinessIds(
    List<String> businessIds,
  ) async {
    if (businessIds.isEmpty) return {};
    try {
      final data = await _client
          .from('business_hours')
          .select()
          .inFilter('business_id', businessIds);
      final result = <String, List<BusinessHours>>{};
      for (final row in (data as List).cast<Map<String, dynamic>>()) {
        final biz = row['business_id'] as String;
        (result[biz] ??= []).add(BusinessHours.fromJson(row));
      }
      return result;
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<List<BusinessHours>> fetchBusinessHours(String businessId) async {
    try {
      final data = await _client
          .from('business_hours')
          .select()
          .eq('business_id', businessId)
          .order('day_of_week', ascending: true);
      return (data as List)
          .map((e) => BusinessHours.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<SpecialBusinessDay?> fetchSpecialDay(
    String businessId,
    String date,
  ) async {
    try {
      final data = await _client
          .from('special_business_days')
          .select()
          .eq('business_id', businessId)
          .eq('date', date)
          .maybeSingle();
      return data == null ? null : SpecialBusinessDay.fromJson(data);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<List<StaffAvailability>> fetchStaffAvailabilityForStaffIds(
    List<String> staffIds,
  ) async {
    if (staffIds.isEmpty) return [];
    try {
      final data = await _client
          .from('staff_availability')
          .select()
          .inFilter('staff_id', staffIds);
      return (data as List)
          .map((e) => StaffAvailability.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<List<StaffBreak>> fetchStaffBreaksForStaffIds(
    List<String> staffIds,
  ) async {
    if (staffIds.isEmpty) return [];
    try {
      final data = await _client
          .from('staff_breaks')
          .select()
          .inFilter('staff_id', staffIds);
      return (data as List)
          .map((e) => StaffBreak.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<List<BookedRange>> fetchBookedRanges({
    required String businessId,
    required DateTime rangeStartUtc,
    required DateTime rangeEndUtc,
  }) async {
    try {
      final data = await _client.rpc(
        'get_booked_appointment_ranges',
        params: {
          'p_business_id': businessId,
          'p_range_start_utc': rangeStartUtc.toIso8601String(),
          'p_range_end_utc': rangeEndUtc.toIso8601String(),
        },
      );
      return (data as List)
          .map((e) => BookedRange.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<List<BlockedRange>> fetchBlockedRanges({
    required String businessId,
    required DateTime rangeStartUtc,
    required DateTime rangeEndUtc,
  }) async {
    try {
      final data = await _client.rpc(
        'get_blocked_time_ranges',
        params: {
          'p_business_id': businessId,
          'p_range_start_utc': rangeStartUtc.toIso8601String(),
          'p_range_end_utc': rangeEndUtc.toIso8601String(),
        },
      );
      return (data as List)
          .map((e) => BlockedRange.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
