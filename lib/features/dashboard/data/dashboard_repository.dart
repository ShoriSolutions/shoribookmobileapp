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
      );
    } catch (e) {
      throw AppException.from(e);
    }
  }
}
