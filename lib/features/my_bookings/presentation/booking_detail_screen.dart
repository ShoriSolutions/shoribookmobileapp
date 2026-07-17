import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/status_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_time_formatters.dart';
import '../../../core/utils/timezone_offsets.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../models/appointment.dart';
import '../../auth/application/auth_providers.dart';
import '../application/my_bookings_providers.dart';
import '../data/my_bookings_repository.dart';

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
        showAppSnackBar(context, message: 'Could not cancel booking', isError: true);
      }
    }
  }

  Future<void> _reschedule(
    BuildContext context,
    WidgetRef ref,
    Appointment appt,
  ) async {
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
          showAppSnackBar(
            context,
            message: 'That time is no longer available',
            isError: true,
          );
          break;
        case ManageBookingStatus.unchanged:
          showAppSnackBar(
            context,
            message: 'This booking can no longer be rescheduled',
            isError: true,
          );
          break;
      }
    } catch (e) {
      if (context.mounted) {
        showAppSnackBar(
          context,
          message: 'Could not reschedule booking',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apptAsync = ref.watch(bookingDetailProvider(bookingId));

    return Scaffold(
      appBar: AppBar(title: const Text('Booking')),
      body: apptAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => ErrorRetryView(
          message: 'Could not load this booking.',
          onRetry: () => ref.invalidate(bookingDetailProvider(bookingId)),
        ),
        data: (appt) {
          final tz = appt.businessTimezone ?? 'America/Barbados';
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              StatusBadge(
                label: StatusColors.appointmentStatusLabel(appt.status),
                color: StatusColors.appointmentStatus(appt.status),
                filled: true,
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appt.businessName ?? 'Business',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 12),
                      _row('Service', appt.serviceName ?? '—'),
                      _row('Staff', appt.staffName ?? 'Any available'),
                      _row('Date', DateTimeFormatters.fullDate(appt.startTime, tz)),
                      _row(
                        'Time',
                        DateTimeFormatters.timeRange(
                          appt.startTime,
                          appt.endTime,
                          tz,
                        ),
                      ),
                      _row('Price', formatCurrency(appt.price, appt.currency)),
                      if (appt.depositRequired)
                        _row(
                          'Deposit',
                          '${formatCurrency(appt.depositAmount, appt.currency)} · '
                              '${StatusColors.depositStatusLabel(appt.depositStatus)}',
                        ),
                    ],
                  ),
                ),
              ),
              if ((appt.notes ?? '').isNotEmpty) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Notes', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 6),
                        Text(appt.notes!),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              if (appt.businessPhone != null || appt.businessWhatsapp != null)
                Row(
                  children: [
                    if (appt.businessPhone != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              launchUrl(Uri.parse('tel:${appt.businessPhone}')),
                          icon: const Icon(Icons.call_outlined),
                          label: const Text('Call'),
                        ),
                      ),
                    if (appt.businessPhone != null &&
                        appt.businessWhatsapp != null)
                      const SizedBox(width: 10),
                    if (appt.businessWhatsapp != null)
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            final digits = appt.businessWhatsapp!.replaceAll(
                              RegExp(r'[^0-9+]'),
                              '',
                            );
                            launchUrl(
                              Uri.parse('https://wa.me/$digits'),
                              mode: LaunchMode.externalApplication,
                            );
                          },
                          icon: const Icon(Icons.chat_outlined),
                          label: const Text('WhatsApp'),
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 10),
              if (appt.isActive &&
                  ref.watch(authStatusProvider) ==
                      AuthStatus.authenticated) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => _reschedule(context, ref, appt),
                    child: const Text('Reschedule'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                    ),
                    onPressed: () => _cancel(context, ref),
                    child: const Text('Cancel booking'),
                  ),
                ),
              ] else if (appt.isActive) ...[
                Text(
                  'To change or cancel this booking, contact the business '
                  'using the details above.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.muted),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: const TextStyle(color: AppColors.muted)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
