import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../routing/route_paths.dart';
import '../../availability/application/availability_providers.dart';
import '../../business_context/application/active_business_provider.dart';
import '../../payments/application/payment_providers.dart';
import '../../services/application/services_providers.dart';
import '../../staff/application/staff_providers.dart';

/// Business setup checklist — a quick view of what's done and what still needs
/// attention. Incomplete items link straight to the section that fixes them.
class SetupChecklistScreen extends ConsumerWidget {
  const SetupChecklistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final business = ref.watch(activeMembershipProvider).valueOrNull?.business;
    final services = ref.watch(servicesListProvider).valueOrNull ?? const [];
    final staff = ref.watch(staffListProvider).valueOrNull ?? const [];
    final hours = ref.watch(businessHoursProvider).valueOrNull ?? const [];
    final depositReady = ref.watch(depositReadyProvider).valueOrNull ?? false;

    if (business == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final infoDone = (business.category?.trim().isNotEmpty ?? false) &&
        ((business.phone?.trim().isNotEmpty ?? false) ||
            (business.email?.trim().isNotEmpty ?? false));
    final addressDone = business.address?.trim().isNotEmpty ?? false;
    final servicesDone = services.isNotEmpty;
    final staffDone = staff.isNotEmpty;
    final availabilityDone =
        hours.any((h) => !h.isClosed && (h.openTime?.isNotEmpty ?? false));

    final items = <_Item>[
      _Item('Business information', infoDone, RoutePaths.editBusinessProfile),
      _Item('Business address', addressDone, RoutePaths.editBusinessProfile),
      _Item('Services', servicesDone, RoutePaths.services),
      _Item('Staff', staffDone, RoutePaths.staff),
      _Item('Payment settings', depositReady, RoutePaths.paymentSettings,
          note: 'Required for deposits'),
      _Item('Availability', availabilityDone, RoutePaths.availability),
    ];
    final done = items.where((i) => i.done).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Business setup')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('$done of ${items.length} complete',
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.ink)),
          const SizedBox(height: 4),
          Text(
            'Tap anything that still needs attention to finish it.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.parchment),
            ),
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i > 0)
                    const Divider(height: 1, color: AppColors.divider),
                  _ChecklistRow(item: items[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Item {
  final String title;
  final bool done;
  final String route;
  final String? note;
  const _Item(this.title, this.done, this.route, {this.note});
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.item});
  final _Item item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push(item.route),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(
              item.done ? Icons.check_circle : Icons.warning_amber_rounded,
              color: item.done ? AppColors.sage : AppColors.terracottaDeep,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title,
                      style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink)),
                  if (item.note != null) ...[
                    const SizedBox(height: 1),
                    Text(item.note!,
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.muted)),
                  ],
                ],
              ),
            ),
            if (!item.done)
              const Icon(Icons.chevron_right, color: AppColors.faint),
          ],
        ),
      ),
    );
  }
}
