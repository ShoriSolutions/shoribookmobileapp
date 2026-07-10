import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../models/appointment.dart';
import '../../appointments/application/appointments_providers.dart';
import '../../business_context/application/active_business_provider.dart';

/// The currently-selected agenda date, defaulting to "today". Kept as
/// plain UI state (not persisted) since re-opening the app should
/// always land back on today.
final selectedCalendarDateProvider = StateProvider<DateTime>((ref) {
  return DateTime.now();
});

String _isoDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

final calendarAppointmentsProvider = FutureProvider.autoDispose<
  List<Appointment>
>((ref) async {
  final membership = await ref.watch(activeMembershipProvider.future);
  if (membership == null) return [];

  final date = ref.watch(selectedCalendarDateProvider);
  final dateStr = _isoDate(date);
  final staffProfileId = membership.role.value == 'STAFF'
      ? membership.staffProfileId
      : null;

  return ref
      .watch(appointmentsRepositoryProvider)
      .fetchForDateRange(
        businessId: membership.business.id,
        fromDate: dateStr,
        toDate: dateStr,
        timezone: membership.business.timezone,
        staffProfileId: staffProfileId,
      );
});
