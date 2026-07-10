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
      final todayLocal = utcToBusinessLocal(now, timezone);

      final weekStartLocal = todayLocal.subtract(
        Duration(days: todayLocal.weekday % 7),
      ); // Sunday-start week, matches day_of_week 0=Sunday convention
      final monthStartLocal = DateTime(todayLocal.year, todayLocal.month, 1);
      final monthEndLocal = DateTime(todayLocal.year, todayLocal.month + 1, 0);

      final rangeStartLocal = weekStartLocal.isBefore(monthStartLocal)
          ? weekStartLocal
          : monthStartLocal;

      final rangeStartDate = _isoDate(rangeStartLocal);
      final rangeEndDate = _isoDate(monthEndLocal);

      final rangeStartUtc = businessLocalToUtc(
        date: rangeStartDate,
        time: '00:00',
        timezone: timezone,
      );
      final rangeEndUtc = businessLocalToUtc(
        date: rangeEndDate,
        time: '23:59',
        timezone: timezone,
      );

      var rangeQuery = _client
          .from('appointments')
          .select('status, price, start_time, deposit_status')
          .eq('business_id', businessId)
          .gte('start_time', rangeStartUtc.toIso8601String())
          .lte('start_time', rangeEndUtc.toIso8601String());
      if (staffProfileId != null) {
        rangeQuery = rangeQuery.eq('staff_profile_id', staffProfileId);
      }
      final rangeRows = await rangeQuery as List;

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

      final weekStartDate = _isoDate(weekStartLocal);
      final monthStartDate = _isoDate(monthStartLocal);

      int bookingsToday = 0;
      int bookingsThisWeek = 0;
      int completedThisMonth = 0;
      double revenueThisMonth = 0;
      int noShowsThisMonth = 0;

      for (final row in rangeRows) {
        final map = row as Map<String, dynamic>;
        final startUtc = DateTime.parse(map['start_time'] as String);
        final localDate = businessLocalDateString(startUtc, timezone);
        final status = map['status'] as String;

        if (localDate == todayDate) bookingsToday++;
        if (localDate.compareTo(weekStartDate) >= 0) bookingsThisWeek++;

        if (localDate.compareTo(monthStartDate) >= 0) {
          if (status == AppointmentStatus.completed) {
            completedThisMonth++;
            final price = (map['price'] as num?)?.toDouble() ?? 0;
            revenueThisMonth += price;
          }
          if (status == AppointmentStatus.noShow) noShowsThisMonth++;
        }
      }

      return DashboardStats(
        bookingsToday: bookingsToday,
        bookingsThisWeek: bookingsThisWeek,
        completedThisMonth: completedThisMonth,
        revenueThisMonth: revenueThisMonth,
        noShowsThisMonth: noShowsThisMonth,
        pendingDepositsCount: pendingDepositRows.length,
      );
    } catch (e) {
      throw AppException.from(e);
    }
  }

  String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
