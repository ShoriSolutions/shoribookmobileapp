import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/utils/timezone_offsets.dart';
import '../../../models/appointment.dart';
import 'dashboard_stats.dart';

class DashboardRepository {
  final SupabaseClient _client;

  DashboardRepository(this._client);

  Future<List<Appointment>> fetchTodayAppointments({
    required String businessId,
    required String timezone,
    String? staffProfileId,
  }) async {
    try {
      final now = DateTime.now().toUtc();
      final todayDate = businessLocalDateString(now, timezone);
      final startUtc = businessLocalToUtc(
        date: todayDate,
        time: '00:00',
        timezone: timezone,
      );
      final endUtc = businessLocalToUtc(
        date: todayDate,
        time: '23:59',
        timezone: timezone,
      );

      var query = _client
          .from('appointments')
          .select(appointmentSelectColumns)
          .eq('business_id', businessId)
          .gte('start_time', startUtc.toIso8601String())
          .lte('start_time', endUtc.toIso8601String());

      if (staffProfileId != null) {
        query = query.eq('staff_profile_id', staffProfileId);
      }

      final data = await query.order('start_time', ascending: true);
      return (data as List)
          .map((e) => Appointment.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<Appointment?> fetchNextUpcoming({
    required String businessId,
    String? staffProfileId,
  }) async {
    try {
      var query = _client
          .from('appointments')
          .select(appointmentSelectColumns)
          .eq('business_id', businessId)
          .inFilter('status', [AppointmentStatus.pending, AppointmentStatus.confirmed])
          .gt('start_time', DateTime.now().toUtc().toIso8601String());

      if (staffProfileId != null) {
        query = query.eq('staff_profile_id', staffProfileId);
      }

      final data = await query
          .order('start_time', ascending: true)
          .limit(1)
          .maybeSingle();

      return data == null ? null : Appointment.fromJson(data);
    } catch (e) {
      throw AppException.from(e);
    }
  }

  Future<DashboardStats> fetchStats({
    required String businessId,
    required String timezone,
    String? staffProfileId,
  }) async {
    try {
      final now = DateTime.now().toUtc();
      final todayDate = businessLocalDateString(now, timezone);
      final startUtc = businessLocalToUtc(
        date: todayDate,
        time: '00:00',
        timezone: timezone,
      );
      final endUtc = businessLocalToUtc(
        date: todayDate,
        time: '23:59',
        timezone: timezone,
      );

      var todayQuery = _client
          .from('appointments')
          .select('status, price')
          .eq('business_id', businessId)
          .gte('start_time', startUtc.toIso8601String())
          .lte('start_time', endUtc.toIso8601String());
      if (staffProfileId != null) {
        todayQuery = todayQuery.eq('staff_profile_id', staffProfileId);
      }
      final todayRows = await todayQuery as List;

      var pendingDepositQuery = _client
          .from('appointments')
          .select('id')
          .eq('business_id', businessId)
          .eq('deposit_status', 'PENDING');
      if (staffProfileId != null) {
        pendingDepositQuery = pendingDepositQuery.eq(
          'staff_profile_id',
          staffProfileId,
        );
      }
      final pendingDepositRows = await pendingDepositQuery as List;

      // Staff on duty right now = active/bookable staff whose availability
      // window covers the current business-local time.
      final localNow = utcToBusinessLocal(now, timezone);
      final dow = localNow.weekday % 7; // 0=Sunday..6=Saturday
      final nowMin = localNow.hour * 60 + localNow.minute;

      final staffRows = await _client
          .from('staff_profiles')
          .select('id')
          .eq('business_id', businessId)
          .eq('is_active', true)
          .eq('is_bookable', true) as List;
      final staffIds =
          staffRows.map((e) => (e as Map)['id'] as String).toList();
      final staffTotal = staffIds.length;
      var staffOnDuty = 0;
      if (staffIds.isNotEmpty) {
        final availRows = await _client
            .from('staff_availability')
            .select('staff_id, day_of_week, start_time, end_time, is_available')
            .inFilter('staff_id', staffIds) as List;
        final onDuty = <String>{};
        for (final r in availRows) {
          final m = r as Map<String, dynamic>;
          if ((m['day_of_week'] as int?) != dow) continue;
          if (m['is_available'] == false) continue;
          final s = _toMin(m['start_time'] as String?);
          final e = _toMin(m['end_time'] as String?);
          if (s == null || e == null) continue;
          if (nowMin >= s && nowMin < e) onDuty.add(m['staff_id'] as String);
        }
        staffOnDuty = onDuty.length;
      }

      int bookingsToday = 0;
      int completedToday = 0;
      double revenueToday = 0;
      int noShowsToday = 0;
      int cancelledToday = 0;

      for (final row in todayRows) {
        final map = row as Map<String, dynamic>;
        bookingsToday++;
        final status = map['status'] as String;
        if (status == AppointmentStatus.completed) {
          completedToday++;
          revenueToday += (map['price'] as num?)?.toDouble() ?? 0;
        } else if (status == AppointmentStatus.noShow) {
          noShowsToday++;
        } else if (status == AppointmentStatus.cancelled) {
          cancelledToday++;
        }
      }

      return DashboardStats(
        bookingsToday: bookingsToday,
        completedToday: completedToday,
        revenueToday: revenueToday,
        noShowsToday: noShowsToday,
        cancelledToday: cancelledToday,
        pendingDepositsCount: pendingDepositRows.length,
        staffOnDuty: staffOnDuty,
        staffTotal: staffTotal,
      );
    } catch (e) {
      throw AppException.from(e);
    }
  }

  int? _toMin(String? hhmmss) {
    if (hhmmss == null) return null;
    final parts = hhmmss.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return h * 60 + m;
  }
}
