import 'dart:io';

import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

/// Builds a standard .ics calendar event for an appointment and opens the
/// share sheet so the user can add it to whichever calendar they use.
/// Deliberately uses an .ics file (no calendar permission / no extra native
/// plugin) so it works the same on iOS and Android.
///
/// Times are written in **UTC** (the `Z` suffix), which every calendar app
/// converts to the viewer's own local time — so the event appears at the
/// correct wall-clock moment regardless of where it's imported. [timeZone]
/// (the business's IANA zone) is attached as calendar metadata so the
/// event also carries its "home" zone.
Future<void> addAppointmentToCalendar({
  required String title,
  required DateTime startUtc,
  required DateTime endUtc,
  String? location,
  String? description,
  String? timeZone,
}) async {
  String fmt(DateTime d) => DateFormat("yyyyMMdd'T'HHmmss'Z'").format(d.toUtc());
  String esc(String s) => s
      .replaceAll('\\', '\\\\')
      .replaceAll(';', '\\;')
      .replaceAll(',', '\\,')
      .replaceAll('\n', '\\n');

  final stamp = fmt(DateTime.now());
  final lines = <String>[
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Shorivo//Booking//EN',
    'CALSCALE:GREGORIAN',
    if (timeZone != null && timeZone.trim().isNotEmpty)
      'X-WR-TIMEZONE:${esc(timeZone)}',
    'BEGIN:VEVENT',
    'UID:${startUtc.microsecondsSinceEpoch}@shorivo',
    'DTSTAMP:$stamp',
    'DTSTART:${fmt(startUtc)}',
    'DTEND:${fmt(endUtc)}',
    'SUMMARY:${esc(title)}',
    if (location != null && location.trim().isNotEmpty)
      'LOCATION:${esc(location)}',
    if (description != null && description.trim().isNotEmpty)
      'DESCRIPTION:${esc(description)}',
    'END:VEVENT',
    'END:VCALENDAR',
  ];

  final file = File('${Directory.systemTemp.path}/shorivo_appointment.ics');
  await file.writeAsString(lines.join('\r\n'));
  await Share.shareXFiles(
    [XFile(file.path, mimeType: 'text/calendar')],
    subject: title,
  );
}
