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

    final blocked = asyncData.valueOrNull?.customer.isBlocked ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Client'),
        actions: [
          if (canEdit)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => context.push(RoutePaths.clientEdit(clientId)),
            ),
          if (canEdit)
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'block') {
                  _blockCustomer(context, ref);
                } else if (v == 'unblock') {
                  _setBlocked(context, ref, false);
                }
              },
              itemBuilder: (ctx) => [
                if (blocked)
                  const PopupMenuItem(
                      value: 'unblock', child: Text('Unblock customer'))
                else
                  const PopupMenuItem(
                    value: 'block',
                    child: Text('Block customer',
                        style: TextStyle(color: AppColors.danger)),
                  ),
              ],
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
            padding: const EdgeInsets.all(20),
            children: [
              if (customer.isBlocked) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7ECE9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFECCDC4)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.block, size: 18, color: AppColors.danger),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Blocked from future bookings',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.danger)),
                            if ((customer.blockedReason ?? '').isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(customer.blockedReason!,
                                  style: const TextStyle(
                                      fontSize: 13, color: AppColors.danger)),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.sage,
                    foregroundColor: Colors.white,
                    child: Text(
                      customer.firstName.isNotEmpty
                          ? customer.firstName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          fontSize: 30, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(customer.fullName,
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink)),
                  const SizedBox(height: 2),
                  Text(
                    'Client since ${customer.createdAt.year} · ${customer.phone}',
                    style: const TextStyle(fontSize: 13.5, color: AppColors.muted),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _ActionBtn(
                      icon: Icons.chat_bubble_outline,
                      label: 'Message',
                      bg: AppColors.whatsapp,
                      fg: Colors.white,
                      onTap: () {
                        final target = customer.whatsappNumber ?? customer.phone;
                        launchUrl(
                          Uri.parse(
                              'https://wa.me/${target.replaceAll(RegExp(r'[^0-9+]'), '')}'),
                          mode: LaunchMode.externalApplication,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionBtn(
                      icon: Icons.add,
                      label: 'New booking',
                      bg: AppColors.sageLight,
                      fg: AppColors.sageDark,
                      onTap: () => context.push(RoutePaths.bookingNew),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.3,
                children: [
                  _StatTile('Visits', '${stats.completedAppointments}',
                      AppColors.ink),
                  _StatTile(
                      'Spent',
                      formatCurrency(
                          stats.totalSpent, membership?.business.currency),
                      AppColors.sageDark),
                  _StatTile('No-shows', '${stats.noShowAppointments}',
                      AppColors.danger),
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

  Future<void> _blockCustomer(BuildContext context, WidgetRef ref) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Block this customer?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "They won't be able to make new bookings with your business. "
              'Existing bookings are unaffected, and this only applies to you.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason (optional, private)',
              ),
              minLines: 1,
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Block'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _setBlocked(context, ref, true,
        reason: reasonController.text.trim().isEmpty
            ? null
            : reasonController.text.trim());
  }

  Future<void> _setBlocked(BuildContext context, WidgetRef ref, bool blocked,
      {String? reason}) async {
    try {
      await ref
          .read(clientsRepositoryProvider)
          .setBlocked(clientId, blocked, reason: reason);
      ref.invalidate(clientDetailProvider(clientId));
      ref.invalidate(clientsListProvider);
      if (context.mounted) {
        showAppSnackBar(context,
            message: blocked ? 'Customer blocked' : 'Customer unblocked');
      }
    } catch (e) {
      if (context.mounted) {
        showAppSnackBar(context,
            message: 'Could not update. Only owners/admins can block.',
            isError: true);
      }
    }
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatTile(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.parchment),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.bg,
    required this.fg,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700, color: fg)),
            ],
          ),
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
