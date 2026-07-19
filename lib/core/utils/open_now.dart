import '../../models/availability_models.dart';
import 'timezone_offsets.dart';

/// Whether a business is open right now, from its weekly [hours] and its
/// [timezone]. Returns null when we can't tell (no hours on record) so
/// callers can hide the status chip rather than assert "Closed" falsely.
bool? isOpenNow(List<BusinessHours> hours, String timezone) {
  if (hours.isEmpty) return null;
  final local = utcToBusinessLocal(DateTime.now().toUtc(), timezone);
  // BusinessHours.dayOfWeek: 0=Sunday..6=Saturday; DateTime.weekday:
  // 1=Monday..7=Sunday — convert to the 0=Sunday convention.
  final dayOfWeek = local.weekday % 7;
  final today = hours.where((h) => h.dayOfWeek == dayOfWeek);
  if (today.isEmpty) return false;
  final entry = today.first;
  if (entry.isClosed || entry.openTime == null || entry.closeTime == null) {
    return false;
  }
  final nowMin = local.hour * 60 + local.minute;
  final open = entry.openTime!.split(':');
  final close = entry.closeTime!.split(':');
  final openMin = int.parse(open[0]) * 60 + int.parse(open[1]);
  final closeMin = int.parse(close[0]) * 60 + int.parse(close[1]);
  return nowMin >= openMin && nowMin < closeMin;
}
