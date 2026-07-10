import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_time_formatters.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../models/appointment.dart';
import '../../../routing/route_paths.dart';
import '../../appointments/application/appointments_providers.dart';
import '../../business_context/application/active_business_provider.dart';
import '../application/deposits_providers.dart';

class DepositsListScreen extends ConsumerWidget {
  const DepositsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final depositsAsync = ref.watch(pendingDepositsProvider);
    final membership = ref.watch(activeMembershipProvider).valueOrNull;
    final tz = membership?.business.timezone ?? 'America/Barbados';

    return Scaffold(
      appBar: AppBar(title: const Text('Pending deposits')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(pendingDepositsProvider.future),
        child: depositsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, st) => ListView(
            children: [
              const SizedBox(height: 80),
              ErrorRetryView(
                message: 'Could not load pending deposits.',
                onRetry: () => ref.invalidate(pendingDepositsProvider),
              ),
            ],
          ),
          data: (appointments) {
            if (appointments.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 60),
                  EmptyState(
                    icon: '◇',
                    title: 'No pending deposits',
                    message: "You're all caught up.",
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: appointments.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) => _DepositTile(
                appointment: appointments[i],
                timezone: tz,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DepositTile extends ConsumerWidget {
  final Appointment appointment;
  final String timezone;

  const _DepositTile({required this.appointment, required this.timezone});

  Future<void> _markPaid(BuildContext context, WidgetRef ref) async {
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
    try {
      await ref
          .read(appointmentsRepositoryProvider)
          .markDepositPaid(
            appointment.id,
            paymentMethod: method,
            paymentReference: referenceController.text,
            autoConfirmIfPending: appointment.status == AppointmentStatus.pending,
          );
      ref.invalidate(pendingDepositsProvider);
      if (context.mounted) {
        showAppSnackBar(context, message: 'Deposit marked as paid');
      }
    } catch (e) {
      if (context.mounted) {
        showAppSnackBar(context, message: 'Could not update deposit', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(RoutePaths.appointmentDetailPath(appointment.id)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appointment.customerName ?? 'Walk-in client',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        Text(
                          '${appointment.serviceName ?? ''} · ${DateTimeFormatters.weekdayDate(appointment.startTime, timezone)}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    formatCurrency(appointment.depositAmount, appointment.currency),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.terracotta,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _markPaid(context, ref),
                  child: const Text('Mark as paid'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
