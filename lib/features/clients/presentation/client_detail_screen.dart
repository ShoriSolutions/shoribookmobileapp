import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../routing/route_paths.dart';
import '../../appointments/presentation/widgets/appointment_card.dart';
import '../../business_context/application/active_business_provider.dart';
import '../../business_context/application/permissions.dart';
import '../application/clients_providers.dart';

class ClientDetailScreen extends ConsumerWidget {
  final String clientId;

  const ClientDetailScreen({super.key, required this.clientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(clientDetailProvider(clientId));
    final membership = ref.watch(activeMembershipProvider).valueOrNull;
    final canEdit = membership != null &&
        can(membership.role, Permission.manageClients);
    final tz = membership?.business.timezone ?? 'America/Barbados';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Client'),
        actions: [
          if (canEdit)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () =>
                  context.push(RoutePaths.clientEdit(clientId)),
            ),
        ],
      ),
      body: asyncData.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => ErrorRetryView(
          message: 'Could not load this client.',
          onRetry: () => ref.invalidate(clientDetailProvider(clientId)),
        ),
        data: (data) {
          final customer = data.customer;
          final stats = data.stats;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              customer.fullName,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(
                              customer.phone,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.muted),
                            ),
                            if (customer.email?.isNotEmpty == true)
                              Text(
                                customer.email!,
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: AppColors.muted),
                              ),
                          ],
                        ),
                      ),
                      IconButton.filledTonal(
                        onPressed: () =>
                            launchUrl(Uri.parse('tel:${customer.phone}')),
                        icon: const Icon(Icons.call_outlined),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filledTonal(
                        onPressed: () {
                          final target =
                              customer.whatsappNumber ?? customer.phone;
                          final digits = target.replaceAll(
                            RegExp(r'[^0-9+]'),
                            '',
                          );
                          launchUrl(
                            Uri.parse('https://wa.me/$digits'),
                            mode: LaunchMode.externalApplication,
                          );
                        },
                        icon: const Icon(Icons.chat_outlined),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.3,
                children: [
                  _StatTile('Visits', '${stats.completedAppointments}'),
                  _StatTile(
                    'Spent',
                    formatCurrency(stats.totalSpent, membership?.business.currency),
                  ),
                  _StatTile('No-shows', '${stats.noShowAppointments}'),
                ],
              ),
              if (customer.tags.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final tag in customer.tags)
                      Chip(
                        label: Text(tag),
                        backgroundColor: AppColors.sageLight,
                      ),
                  ],
                ),
              ],
              if ((customer.notes ?? '').isNotEmpty) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Notes',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(customer.notes!),
                      ],
                    ),
                  ),
                ),
              ],
              if (canEdit) ...[
                const SizedBox(height: 12),
                _AddNoteField(clientId: clientId),
              ],
              const SizedBox(height: 20),
              Text(
                'Booking history',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              if (data.history.isEmpty)
                Text(
                  'No appointments yet.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                )
              else
                ...data.history.map(
                  (appt) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppointmentCard(
                      appointment: appt,
                      timezone: tz,
                      onTap: () => context.push(
                        RoutePaths.appointmentDetailPath(appt.id),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;

  const _StatTile(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddNoteField extends ConsumerStatefulWidget {
  final String clientId;

  const _AddNoteField({required this.clientId});

  @override
  ConsumerState<_AddNoteField> createState() => _AddNoteFieldState();
}

class _AddNoteFieldState extends ConsumerState<_AddNoteField> {
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_controller.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(clientsRepositoryProvider)
          .appendNote(widget.clientId, _controller.text.trim());
      _controller.clear();
      ref.invalidate(clientDetailProvider(widget.clientId));
      if (mounted) showAppSnackBar(context, message: 'Note added');
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context, message: 'Could not add note', isError: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            decoration: const InputDecoration(hintText: 'Add a note…'),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          onPressed: _saving ? null : _submit,
          icon: const Icon(Icons.send),
        ),
      ],
    );
  }
}
