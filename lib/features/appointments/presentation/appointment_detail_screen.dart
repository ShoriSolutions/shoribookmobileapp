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
import '../../business_context/application/active_business_provider.dart';
import '../../business_context/application/permissions.dart';
import '../application/appointment_detail_controller.dart';

class AppointmentDetailScreen extends ConsumerWidget {
  final String appointmentId;

  const AppointmentDetailScreen({super.key, required this.appointmentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncAppt = ref.watch(
      appointmentDetailControllerProvider(appointmentId),
    );
    final membership = ref.watch(activeMembershipProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Appointment')),
      body: asyncAppt.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => ErrorRetryView(
          message: 'Could not load this appointment.',
          onRetry: () => ref.invalidate(
            appointmentDetailControllerProvider(appointmentId),
          ),
        ),
        data: (appt) {
          if (membership == null) return const SizedBox.shrink();
          final tz = membership.business.timezone;
          final isAssignedToViewer =
              membership.staffProfileId != null &&
              membership.staffProfileId == appt.staffProfileId;
          final canUpdateStatus = canUpdateAppointmentStatus(
            membership.role,
            isAssignedToViewer: isAssignedToViewer,
          );
          final canEdit = canCreateOrEditBooking(membership.role);
          final canMarkDeposit = can(membership.role, Permission.markDeposits);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Wrap(
                spacing: 8,
                children: [
                  StatusBadge(
                    label: StatusColors.appointmentStatusLabel(appt.status),
                    color: StatusColors.appointmentStatus(appt.status),
                    filled: true,
                  ),
                  if (appt.depositRequired)
                    StatusBadge(
                      label: StatusColors.depositStatusLabel(
                        appt.depositStatus,
                      ),
                      color: StatusColors.depositStatus(appt.depositStatus),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _ClientCard(appointment: appt),
              const SizedBox(height: 12),
              _DetailsCard(appointment: appt, timezone: tz),
              if (appt.depositRequired) ...[
                const SizedBox(height: 12),
                _DepositCard(
                  appointment: appt,
                  canMarkDeposit: canMarkDeposit,
                  onMarkPaid: () => _showMarkDepositPaid(context, ref, appt),
                ),
              ],
              if ((appt.notes ?? '').isNotEmpty) ...[
                const SizedBox(height: 12),
                _NotesCard(title: 'Customer notes', text: appt.notes!),
              ],
              const SizedBox(height: 12),
              _InternalNotesCard(
                appointment: appt,
                canEdit: canEdit,
                onAddNote: (note) async {
                  final ok = await ref
                      .read(
                        appointmentDetailControllerProvider(
                          appointmentId,
                        ).notifier,
                      )
                      .addInternalNote(note);
                  if (context.mounted) {
                    showAppSnackBar(
                      context,
                      message: ok ? 'Note added' : 'Could not add note',
                      isError: !ok,
                    );
                  }
                },
              ),
              const SizedBox(height: 20),
              if (canUpdateStatus)
                _StatusActions(
                  appointment: appt,
                  onSetStatus: (status) =>
                      _setStatus(context, ref, appt, status),
                ),
              if (canEdit && appt.isActive) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => _showRescheduleSheet(context, ref, appt, tz),
                    child: const Text('Reschedule'),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _setStatus(
    BuildContext context,
    WidgetRef ref,
    Appointment appt,
    String status,
  ) async {
    if (status == AppointmentStatus.cancelled ||
        status == AppointmentStatus.noShow) {
      final label = status == AppointmentStatus.cancelled
          ? 'cancel this appointment'
          : 'mark this appointment as a no-show';
      final confirmed = await showConfirmDialog(
        context,
        title: 'Are you sure?',
        message: 'This will $label. This action can be reviewed later in '
            "the appointment's history but won't undo automatically.",
        confirmLabel: status == AppointmentStatus.cancelled
            ? 'Cancel appointment'
            : 'Mark no-show',
      );
      if (!confirmed) return;
    }
    final ok = await ref
        .read(appointmentDetailControllerProvider(appointmentId).notifier)
        .updateStatus(status);
    if (context.mounted) {
      showAppSnackBar(
        context,
        message: ok ? 'Appointment updated' : 'Could not update appointment',
        isError: !ok,
      );
    }
  }

  Future<void> _showMarkDepositPaid(
    BuildContext context,
    WidgetRef ref,
    Appointment appt,
  ) async {
    final referenceController = TextEditingController();
    String method = 'CASH';

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: StatefulBuilder(
          builder: (ctx, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Mark deposit paid', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: method,
                decoration: const InputDecoration(labelText: 'Payment method'),
                items: PaymentMethod.all
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (v) => setState(() => method = v ?? method),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: referenceController,
                decoration: const InputDecoration(
                  labelText: 'Payment reference (optional)',
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Mark as paid'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) return;
    final ok = await ref
        .read(appointmentDetailControllerProvider(appointmentId).notifier)
        .markDepositPaid(
          paymentMethod: method,
          paymentReference: referenceController.text,
        );
    if (context.mounted) {
      showAppSnackBar(
        context,
        message: ok ? 'Deposit marked as paid' : 'Could not update deposit',
        isError: !ok,
      );
    }
  }

  Future<void> _showRescheduleSheet(
    BuildContext context,
    WidgetRef ref,
    Appointment appt,
    String timezone,
  ) async {
    final localStart = utcToBusinessLocal(appt.startTime, timezone);
    DateTime pickedDate = localStart;
    TimeOfDay pickedTime = TimeOfDay(
      hour: localStart.hour,
      minute: localStart.minute,
    );

    final date = await showDatePicker(
      context: context,
      initialDate: localStart,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !context.mounted) return;
    pickedDate = date;

    final time = await showTimePicker(context: context, initialTime: pickedTime);
    if (time == null || !context.mounted) return;
    pickedTime = time;

    final durationMinutes = appt.endTime.difference(appt.startTime).inMinutes;
    final newStartUtc = businessLocalToUtc(
      date:
          '${pickedDate.year.toString().padLeft(4, '0')}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}',
      time:
          '${pickedTime.hour.toString().padLeft(2, '0')}:${pickedTime.minute.toString().padLeft(2, '0')}',
      timezone: timezone,
    );
    final newEndUtc = newStartUtc.add(Duration(minutes: durationMinutes));

    final error = await ref
        .read(appointmentDetailControllerProvider(appointmentId).notifier)
        .reschedule(newStartUtc: newStartUtc, newEndUtc: newEndUtc);

    if (!context.mounted) return;
    showAppSnackBar(
      context,
      message: error ?? 'Appointment rescheduled',
      isError: error != null,
    );
  }
}

class _ClientCard extends StatelessWidget {
  final Appointment appointment;

  const _ClientCard({required this.appointment});

  @override
  Widget build(BuildContext context) {
    final phone = appointment.customerPhone;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appointment.customerName?.trim().isNotEmpty == true
                        ? appointment.customerName!
                        : 'Walk-in client',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (phone != null && phone.isNotEmpty)
                    Text(
                      phone,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                    ),
                ],
              ),
            ),
            if (phone != null && phone.isNotEmpty) ...[
              IconButton.filledTonal(
                onPressed: () => launchUrl(Uri.parse('tel:$phone')),
                icon: const Icon(Icons.call_outlined),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: () {
                  final digits = phone.replaceAll(RegExp(r'[^0-9+]'), '');
                  launchUrl(
                    Uri.parse('https://wa.me/$digits'),
                    mode: LaunchMode.externalApplication,
                  );
                },
                icon: const Icon(Icons.chat_outlined),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  final Appointment appointment;
  final String timezone;

  const _DetailsCard({required this.appointment, required this.timezone});

  @override
  Widget build(BuildContext context) {
    final duration = appointment.endTime.difference(appointment.startTime).inMinutes;
    final rows = <(String, String)>[
      ('Service', appointment.serviceName ?? '—'),
      ('Staff', appointment.staffName ?? 'Any available'),
      ('Date', DateTimeFormatters.fullDate(appointment.startTime, timezone)),
      (
        'Time',
        DateTimeFormatters.timeRange(
          appointment.startTime,
          appointment.endTime,
          timezone,
        ),
      ),
      ('Duration', '$duration min'),
      ('Price', formatCurrency(appointment.price, appointment.currency)),
      ('Booking source', BookingSource.label(appointment.bookingSource)),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            for (final r in rows) _InfoRow(label: r.$1, value: r.$2),
          ],
        ),
      ),
    );
  }
}

class _DepositCard extends StatelessWidget {
  final Appointment appointment;
  final bool canMarkDeposit;
  final VoidCallback onMarkPaid;

  const _DepositCard({
    required this.appointment,
    required this.canMarkDeposit,
    required this.onMarkPaid,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Deposit', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _InfoRow(
              label: 'Amount',
              value: formatCurrency(
                appointment.depositAmount,
                appointment.currency,
              ),
            ),
            _InfoRow(
              label: 'Status',
              value: StatusColors.depositStatusLabel(appointment.depositStatus),
            ),
            if (appointment.paymentMethod != null)
              _InfoRow(label: 'Method', value: appointment.paymentMethod!),
            if (appointment.paymentReference?.isNotEmpty == true)
              _InfoRow(label: 'Reference', value: appointment.paymentReference!),
            if (canMarkDeposit && appointment.depositStatus != DepositStatus.paid) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onMarkPaid,
                  child: const Text('Mark deposit paid'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NotesCard extends StatelessWidget {
  final String title;
  final String text;

  const _NotesCard({required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(text),
          ],
        ),
      ),
    );
  }
}

class _InternalNotesCard extends StatefulWidget {
  final Appointment appointment;
  final bool canEdit;
  final ValueChanged<String> onAddNote;

  const _InternalNotesCard({
    required this.appointment,
    required this.canEdit,
    required this.onAddNote,
  });

  @override
  State<_InternalNotesCard> createState() => _InternalNotesCardState();
}

class _InternalNotesCardState extends State<_InternalNotesCard> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Internal notes', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            if ((widget.appointment.internalNotes ?? '').isNotEmpty)
              Text(widget.appointment.internalNotes!)
            else
              Text(
                'No internal notes yet.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
              ),
            if (widget.canEdit) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _controller,
                decoration: const InputDecoration(hintText: 'Add a note…'),
                minLines: 1,
                maxLines: 3,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    if (_controller.text.trim().isEmpty) return;
                    widget.onAddNote(_controller.text.trim());
                    _controller.clear();
                  },
                  child: const Text('Add note'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusActions extends StatelessWidget {
  final Appointment appointment;
  final ValueChanged<String> onSetStatus;

  const _StatusActions({required this.appointment, required this.onSetStatus});

  @override
  Widget build(BuildContext context) {
    if (!appointment.isActive) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (appointment.status == AppointmentStatus.pending)
          ElevatedButton(
            onPressed: () => onSetStatus(AppointmentStatus.confirmed),
            child: const Text('Confirm'),
          ),
        ElevatedButton(
          onPressed: () => onSetStatus(AppointmentStatus.completed),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.sage),
          child: const Text('Mark completed'),
        ),
        OutlinedButton(
          onPressed: () => onSetStatus(AppointmentStatus.noShow),
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
          child: const Text('No-show'),
        ),
        OutlinedButton(
          onPressed: () => onSetStatus(AppointmentStatus.cancelled),
          child: const Text('Cancel appointment'),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
