import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/time/customer_time_zone.dart';
import '../../../core/time/time_zone_service.dart';
import '../../../core/utils/calendar_export.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_time_formatters.dart';
import '../../../core/utils/timezone_offsets.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../core/widgets/osm_map.dart';
import '../../../models/appointment.dart';
import '../../auth/application/auth_providers.dart';
import '../../marketplace/presentation/widgets/category_visuals.dart';
import '../application/my_bookings_providers.dart';
import '../data/my_bookings_repository.dart';

/// C12 · Booking detail — status banner, business + details cards, a
/// static map, and Reschedule / Cancel / Add to calendar actions.
class BookingDetailScreen extends ConsumerWidget {
  final String bookingId;

  const BookingDetailScreen({super.key, required this.bookingId});

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Cancel this booking?',
      message: 'This cannot be undone from the app — contact the business '
          'directly if you need to rebook.',
      confirmLabel: 'Cancel booking',
    );
    if (!confirmed) return;
    try {
      final result =
          await ref.read(myBookingsRepositoryProvider).cancel(bookingId);
      ref.invalidate(bookingDetailProvider(bookingId));
      ref.invalidate(myBookingsProvider);
      if (context.mounted) {
        showAppSnackBar(
          context,
          message: result.status == ManageBookingStatus.ok
              ? 'Booking cancelled'
              : 'This booking can no longer be cancelled',
        );
      }
    } catch (e) {
      if (context.mounted) {
        showAppSnackBar(context,
            message: 'Could not cancel booking', isError: true);
      }
    }
  }

  Future<void> _reschedule(
      BuildContext context, WidgetRef ref, Appointment appt) async {
    final tz = appt.businessTimezone ?? 'America/Barbados';
    final localStart = utcToBusinessLocal(appt.startTime, tz);

    final date = await showDatePicker(
      context: context,
      initialDate: localStart,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !context.mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: localStart.hour, minute: localStart.minute),
    );
    if (time == null || !context.mounted) return;

    final newStartUtc = businessLocalToUtc(
      date:
          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      time:
          '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
      timezone: tz,
    );

    try {
      final result = await ref
          .read(myBookingsRepositoryProvider)
          .reschedule(bookingId, newStartUtc);
      ref.invalidate(bookingDetailProvider(bookingId));
      ref.invalidate(myBookingsProvider);
      if (!context.mounted) return;
      switch (result.status) {
        case ManageBookingStatus.ok:
          showAppSnackBar(context, message: 'Booking rescheduled');
          break;
        case ManageBookingStatus.conflict:
          showAppSnackBar(context,
              message: 'That time is no longer available', isError: true);
          break;
        case ManageBookingStatus.unchanged:
          showAppSnackBar(context,
              message: 'This booking can no longer be rescheduled',
              isError: true);
          break;
      }
    } catch (e) {
      if (context.mounted) {
        showAppSnackBar(context,
            message: 'Could not reschedule booking', isError: true);
      }
    }
  }

  void _addToCalendar(Appointment a) {
    addAppointmentToCalendar(
      title: '${a.serviceName ?? 'Appointment'} at ${a.businessName ?? ''}',
      startUtc: a.startTime,
      endUtc: a.endTime,
      location: a.businessAddress,
      description: 'Booking reference ${_ref(a)}',
    );
  }

  static String _ref(Appointment a) =>
      a.id.length >= 8 ? a.id.substring(0, 8).toUpperCase() : a.id.toUpperCase();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apptAsync = ref.watch(bookingDetailProvider(bookingId));
    final signedIn =
        ref.watch(authStatusProvider) == AuthStatus.authenticated;

    return Scaffold(
      body: SafeArea(
        child: apptAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, st) => ErrorRetryView(
            message: 'Could not load this booking.',
            onRetry: () => ref.invalidate(bookingDetailProvider(bookingId)),
          ),
          data: (appt) {
            final tz = appt.businessTimezone ?? 'America/Barbados';
            // Customer-facing: show times in the viewer's local zone, with the
            // business time alongside when they differ (DST-aware).
            final custZone = ref.watch(customerTimeZoneProvider).valueOrNull;
            final viewerZone = custZone ?? tz;
            final tzDiffer = custZone != null &&
                TimeZoneService.zonesDiffer(appt.startTime, tz, custZone);
            final visual = CategoryVisual.of(appt.businessCategory);
            final hasCoords = appt.businessLatitude != null &&
                appt.businessLongitude != null;
            final (label, bg, fg, icon) = _banner(appt);

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: AppColors.ink),
                      onPressed: () => context.pop(),
                    ),
                    const SizedBox(width: 4),
                    const Text('Your booking',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink)),
                  ],
                ),
                const SizedBox(height: 12),
                // Status banner
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(icon, color: fg, size: 22),
                      const SizedBox(width: 10),
                      Text(label,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: fg)),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Business card
                _card(
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: visual.gradient,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child:
                            Icon(visual.icon, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(appt.businessName ?? 'Business',
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.ink)),
                            const SizedBox(height: 2),
                            Text(
                              [
                                appt.serviceName,
                                appt.staffName != null
                                    ? 'with ${appt.staffName}'
                                    : 'Any pro',
                              ]
                                  .where((s) => s != null && s.isNotEmpty)
                                  .join(' · '),
                              style: const TextStyle(
                                  fontSize: 14, color: AppColors.muted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Details card
                _card(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      _detailRow(
                          Icons.calendar_today_outlined,
                          '${DateTimeFormatters.weekdayDate(appt.startTime, viewerZone)} · '
                          '${DateTimeFormatters.time(appt.startTime, viewerZone)}'),
                      if (tzDiffer) ...[
                        const Divider(color: AppColors.divider, height: 1),
                        _detailRow(
                            Icons.storefront_outlined,
                            '${DateTimeFormatters.time(appt.startTime, tz)} · '
                            '${TimeZoneService.friendlyName(tz)} time',
                            muted: true),
                      ],
                      const Divider(color: AppColors.divider, height: 1),
                      _detailRow(
                          Icons.access_time,
                          '${appt.endTime.difference(appt.startTime).inMinutes} min'
                          '${appt.price != null ? ' · ${formatCurrency(appt.price, appt.currency)}' : ''}'),
                      const Divider(color: AppColors.divider, height: 1),
                      _detailRow(Icons.credit_card_outlined, 'Ref ${_ref(appt)}',
                          bold: true),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    tzDiffer
                        ? 'Times are shown in your local time'
                            ' (${TimeZoneService.friendlyName(viewerZone)}).'
                        : 'Times are shown in your local time.',
                    style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
                  ),
                ),
                if (hasCoords) ...[
                  const SizedBox(height: 16),
                  MapPreview(
                    point: LatLng(
                        appt.businessLatitude!, appt.businessLongitude!),
                    height: 160,
                  ),
                ],
                const SizedBox(height: 16),
                if (appt.isActive && signedIn) ...[
                  Row(
                    children: [
                      Expanded(
                        child: _ActionBtn(
                          label: 'Reschedule',
                          icon: Icons.autorenew,
                          bg: AppColors.sageLight,
                          fg: AppColors.sageDark,
                          onTap: () => _reschedule(context, ref, appt),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ActionBtn(
                          label: 'Cancel',
                          bg: AppColors.white,
                          fg: AppColors.danger,
                          border: const Color(0xFFECCDC4),
                          onTap: () => _cancel(context, ref),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ] else if (appt.isActive) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.sageLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'To change or cancel this booking, contact the business, '
                      'or sign in to manage it here.',
                      style: TextStyle(fontSize: 13, color: AppColors.sageDark),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                _ActionBtn(
                  label: 'Add to calendar',
                  icon: Icons.event_available_outlined,
                  bg: AppColors.white,
                  fg: AppColors.ink,
                  border: AppColors.parchment,
                  onTap: () => _addToCalendar(appt),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Free to cancel up to 24 hours before. Later cancellations '
                  'may be charged.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  (String, Color, Color, IconData) _banner(Appointment a) {
    switch (a.status) {
      case AppointmentStatus.cancelled:
        return ('Cancelled', AppColors.closedBg, AppColors.closedText,
            Icons.cancel_outlined);
      case AppointmentStatus.noShow:
        return ('No-show', const Color(0xFFF7ECE9), AppColors.danger,
            Icons.error_outline);
      case AppointmentStatus.completed:
        return ('Completed', AppColors.closedBg, AppColors.closedText,
            Icons.check_circle_outline);
      case AppointmentStatus.pending:
        return ('Pending', AppColors.terracottaTint, AppColors.terracottaDeep,
            Icons.hourglass_empty);
      default:
        if (a.depositRequired && !a.depositPaid) {
          return ('Deposit due', AppColors.terracottaTint,
              AppColors.terracottaDeep, Icons.payments_outlined);
        }
        return ('Confirmed', AppColors.successBg, AppColors.successText,
            Icons.check_circle);
    }
  }

  Widget _card({required Widget child, EdgeInsets? padding}) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.parchment),
      ),
      child: child,
    );
  }

  Widget _detailRow(IconData icon, String text,
      {bool bold = false, bool muted = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: muted ? AppColors.muted : AppColors.sage),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: TextStyle(
                    fontSize: muted ? 13.5 : 15.5,
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                    color: muted ? AppColors.muted : AppColors.ink)),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.label,
    required this.bg,
    required this.fg,
    required this.onTap,
    this.icon,
    this.border,
  });

  final String label;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? border;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: border != null ? Border.all(color: border!) : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: fg),
                  const SizedBox(width: 8),
                ],
                Text(label,
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700, color: fg)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
