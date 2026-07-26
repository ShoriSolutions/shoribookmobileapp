import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../routing/route_paths.dart';
import '../../../business_context/application/active_business_provider.dart';
import '../../../business_context/application/permissions.dart';

/// Booking rules (Availability → Rules): a buffer between appointments and
/// per-day / per-hour / simultaneous booking limits. These feed the
/// server-side smart-scheduling validator (check_slot_available), so a
/// customer can never book past them. OWNER/ADMIN edit; others read-only.
class BookingRulesTab extends ConsumerStatefulWidget {
  const BookingRulesTab({super.key});

  @override
  ConsumerState<BookingRulesTab> createState() => _BookingRulesTabState();
}

class _BookingRulesTabState extends ConsumerState<BookingRulesTab> {
  static const _bufferPresets = [0, 10, 15, 30, 60];

  // Confirmation-window duration presets, in minutes.
  static const _windowPresets = <int>[15, 30, 60, 120, 240, 360, 720, 1440];

  int? _buffer;
  final _perDay = TextEditingController();
  final _perHour = TextEditingController();
  final _simultaneous = TextEditingController();
  bool _requireConfirmation = false;
  int _confirmationWindow = 120;
  bool _waitlistEnabled = false;
  bool _seeded = false;
  bool _saving = false;

  @override
  void dispose() {
    _perDay.dispose();
    _perHour.dispose();
    _simultaneous.dispose();
    super.dispose();
  }

  void _seed(
    int buffer,
    int? perDay,
    int? perHour,
    int? simultaneous,
    bool requireConfirmation,
    int confirmationWindow,
    bool waitlistEnabled,
  ) {
    _buffer = buffer;
    _perDay.text = perDay?.toString() ?? '';
    _perHour.text = perHour?.toString() ?? '';
    _simultaneous.text = simultaneous?.toString() ?? '';
    _requireConfirmation = requireConfirmation;
    _confirmationWindow = confirmationWindow;
    _waitlistEnabled = waitlistEnabled;
    _seeded = true;
  }

  /// Human label for a window given in minutes (e.g. 90 -> "1h 30m").
  static String windowLabel(int minutes) {
    if (minutes % 1440 == 0) {
      final d = minutes ~/ 1440;
      return d == 1 ? '24 hours' : '$d days';
    }
    if (minutes % 60 == 0) {
      final h = minutes ~/ 60;
      return h == 1 ? '1 hour' : '$h hours';
    }
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h}h ${m}m';
  }

  Future<void> _addCustomWindow() async {
    final valueCtrl = TextEditingController();
    var unit = 60; // 1=min, 60=hour
    final added = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Custom window'),
          content: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: valueCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Amount'),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<int>(
                value: unit,
                items: const [
                  DropdownMenuItem(value: 1, child: Text('minutes')),
                  DropdownMenuItem(value: 60, child: Text('hours')),
                ],
                onChanged: (v) => setD(() => unit = v ?? 60),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final n = int.tryParse(valueCtrl.text.trim());
                if (n != null && n > 0) Navigator.pop(ctx, n * unit);
              },
              child: const Text('Set'),
            ),
          ],
        ),
      ),
    );
    valueCtrl.dispose();
    // Clamp to the server's 5 min .. 7 day range.
    if (added != null) {
      setState(() => _confirmationWindow = added.clamp(5, 10080));
    }
  }

  int? _parseLimit(TextEditingController c) {
    final t = c.text.trim();
    if (t.isEmpty) return null;
    final n = int.tryParse(t);
    if (n == null || n <= 0) return null;
    return n;
  }

  Future<void> _save(String businessId) async {
    setState(() => _saving = true);
    try {
      await ref.read(businessRepositoryProvider).saveBookingRules(
            businessId: businessId,
            bufferMinutes: _buffer ?? 0,
            maxPerDay: _parseLimit(_perDay),
            maxPerHour: _parseLimit(_perHour),
            maxSimultaneous: _parseLimit(_simultaneous),
            requireConfirmation: _requireConfirmation,
            confirmationWindowMinutes: _confirmationWindow,
            waitlistEnabled: _waitlistEnabled,
          );
      ref.invalidate(activeMembershipProvider);
      if (mounted) showAppSnackBar(context, message: 'Booking rules saved');
    } catch (e) {
      if (mounted) {
        showAppSnackBar(
          context,
          message: AppException.from(e).message,
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final membership = ref.watch(activeMembershipProvider).valueOrNull;
    if (membership == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final canManage = can(membership.role, Permission.manageSettings);
    final biz = membership.business;
    if (!_seeded) {
      _seed(
        biz.bufferMinutes,
        biz.maxBookingsPerDay,
        biz.maxBookingsPerHour,
        biz.maxSimultaneousBookings,
        biz.requireConfirmation,
        biz.confirmationWindowMinutes,
        biz.waitlistEnabled,
      );
    }

    final bufferOptions = {..._bufferPresets, _buffer ?? 0}.toList()..sort();
    final windowOptions = {..._windowPresets, _confirmationWindow}.toList()
      ..sort();

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                canManage
                    ? 'These rules are enforced when customers book — the '
                        'scheduling engine will not let anyone book past them.'
                    : 'Only an owner or admin can change booking rules.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 20),

              // Buffer between appointments
              _SectionLabel('Buffer between appointments'),
              const SizedBox(height: 4),
              Text(
                'Extra padding kept free before and after every appointment '
                '(e.g. clean-up or travel).',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  for (final m in bufferOptions)
                    ChoiceChip(
                      label: Text(m == 0 ? 'None' : '$m min'),
                      selected: (_buffer ?? 0) == m,
                      onSelected: canManage
                          ? (_) => setState(() => _buffer = m)
                          : null,
                    ),
                ],
              ),
              const SizedBox(height: 24),

              // Booking limits
              _SectionLabel('Booking limits'),
              const SizedBox(height: 4),
              Text(
                'Leave a field blank for no limit.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              _LimitField(
                controller: _perDay,
                enabled: canManage,
                label: 'Max appointments per day',
                suffix: 'per day',
              ),
              const SizedBox(height: 12),
              _LimitField(
                controller: _perHour,
                enabled: canManage,
                label: 'Max appointments per hour',
                suffix: 'per hour',
              ),
              const SizedBox(height: 12),
              _LimitField(
                controller: _simultaneous,
                enabled: canManage,
                label: 'Max simultaneous bookings',
                suffix: 'at once',
              ),
              const SizedBox(height: 24),

              // Booking confirmation window
              _SectionLabel('Booking confirmation window'),
              const SizedBox(height: 4),
              Text(
                'Require customers to confirm an online booking within a set '
                'time. If they do not, it is automatically cancelled and the '
                'slot reopens. Deposit and vendor-created bookings are never '
                'affected.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 10),
              Card(
                margin: EdgeInsets.zero,
                child: SwitchListTile(
                  title: const Text('Require customer confirmation'),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12),
                  value: _requireConfirmation,
                  onChanged: canManage
                      ? (v) => setState(() => _requireConfirmation = v)
                      : null,
                ),
              ),
              if (_requireConfirmation) ...[
                const SizedBox(height: 14),
                Text(
                  'Customers must confirm within',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final m in windowOptions)
                      ChoiceChip(
                        label: Text(windowLabel(m)),
                        selected: _confirmationWindow == m,
                        onSelected: canManage
                            ? (_) => setState(() => _confirmationWindow = m)
                            : null,
                      ),
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 18),
                      label: const Text('Custom'),
                      onPressed: canManage ? _addCustomWindow : null,
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 24),

              // Waitlist
              _SectionLabel('Waitlist'),
              const SizedBox(height: 4),
              Text(
                'Let customers join a waitlist when their time is taken. When a '
                'slot frees up (a cancellation, no-show, or unconfirmed '
                'booking), matching customers are notified automatically.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 10),
              Card(
                margin: EdgeInsets.zero,
                child: SwitchListTile(
                  title: const Text('Enable waitlist notifications'),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12),
                  value: _waitlistEnabled,
                  onChanged: canManage
                      ? (v) => setState(() => _waitlistEnabled = v)
                      : null,
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => context.push(RoutePaths.waitlist),
                  icon: const Icon(Icons.event_seat_outlined, size: 18),
                  label: const Text('View waitlist'),
                ),
              ),
            ],
          ),
        ),
        if (canManage)
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : () => _save(biz.id),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save rules'),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w700),
      );
}

class _LimitField extends StatelessWidget {
  const _LimitField({
    required this.controller,
    required this.enabled,
    required this.label,
    required this.suffix,
  });

  final TextEditingController controller;
  final bool enabled;
  final String label;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        hintText: 'No limit',
        suffixText: suffix,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
