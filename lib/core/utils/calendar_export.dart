import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';

String _calFmt(DateTime d) =>
    DateFormat("yyyyMMdd'T'HHmmss'Z'").format(d.toUtc());

/// A Google Calendar "add event" template URL, pre-filled with the booking.
/// Opening it lets the user save the event (and set reminders) in Google
/// Calendar — the same flow as the website. Times are UTC so Google shows them
/// at the correct local moment.
Uri buildGoogleCalendarUri({
  required String title,
  required DateTime startUtc,
  required DateTime endUtc,
  String? location,
  String? description,
}) {
  return Uri.https('calendar.google.com', '/calendar/render', {
    'action': 'TEMPLATE',
    'text': title,
    'dates': '${_calFmt(startUtc)}/${_calFmt(endUtc)}',
    if (description != null && description.trim().isNotEmpty)
      'details': description,
    if (location != null && location.trim().isNotEmpty) 'location': location,
  });
}

/// Bottom-sheet chooser: add the appointment to Google Calendar (reminders),
/// or export a .ics for Apple Calendar / Outlook / any other app.
Future<void> showAddToCalendarSheet(
  BuildContext context, {
  required String title,
  required DateTime startUtc,
  required DateTime endUtc,
  String? location,
  String? description,
  String? timeZone,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.event_available, color: AppColors.sage),
            title: const Text('Google Calendar'),
            subtitle: const Text('Save the event and get reminders'),
            onTap: () async {
              Navigator.pop(ctx);
              final uri = buildGoogleCalendarUri(
                title: title,
                startUtc: startUtc,
                endUtc: endUtc,
                location: location,
                description: description,
              );
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            },
          ),
          ListTile(
            leading:
                const Icon(Icons.calendar_today_outlined, color: AppColors.sage),
            title: const Text('Other calendar'),
            subtitle: const Text('Apple Calendar, Outlook or a .ics file'),
            onTap: () {
              Navigator.pop(ctx);
              addAppointmentToCalendar(
                title: title,
                startUtc: startUtc,
                endUtc: endUtc,
                location: location,
                description: description,
                timeZone: timeZone,
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

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
