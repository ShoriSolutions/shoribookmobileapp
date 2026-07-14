import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_snackbar.dart';
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

  int? _buffer;
  final _perDay = TextEditingController();
  final _perHour = TextEditingController();
  final _simultaneous = TextEditingController();
  bool _seeded = false;
  bool _saving = false;

  @override
  void dispose() {
    _perDay.dispose();
    _perHour.dispose();
    _simultaneous.dispose();
    super.dispose();
  }

  void _seed(int buffer, int? perDay, int? perHour, int? simultaneous) {
    _buffer = buffer;
    _perDay.text = perDay?.toString() ?? '';
    _perHour.text = perHour?.toString() ?? '';
    _simultaneous.text = simultaneous?.toString() ?? '';
    _seeded = true;
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
      _seed(biz.bufferMinutes, biz.maxBookingsPerDay, biz.maxBookingsPerHour,
          biz.maxSimultaneousBookings);
    }

    final bufferOptions = {..._bufferPresets, _buffer ?? 0}.toList()..sort();

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
