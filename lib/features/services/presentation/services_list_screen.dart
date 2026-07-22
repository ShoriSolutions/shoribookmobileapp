import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../models/service.dart';
import '../../../routing/route_paths.dart';
import '../../business_context/application/active_business_provider.dart';
import '../../business_context/application/permissions.dart';
import '../../subscription/application/plan_caps.dart';
import '../../subscription/presentation/subscription_modal.dart';
import '../application/services_providers.dart';

Future<void> _showUpgrade(BuildContext context, int limit) async {
  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Service limit reached'),
      content: Text(
        'Your current plan includes up to $limit services. Upgrade to add '
        'more — unlimited services are available on Solo Pro and Squad.',
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not now')),
        TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('See plans')),
      ],
    ),
  );
  if (go == true && context.mounted) showSubscriptionModal(context);
}

/// V10 · Services — grouped by category with a count, price and duration,
/// deposit tag, and hidden services dimmed. Tap a row to edit.
class ServicesListScreen extends ConsumerWidget {
  const ServicesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(servicesListProvider);
    final membership = ref.watch(activeMembershipProvider).valueOrNull;
    final canManage =
        membership != null && can(membership.role, Permission.manageServices);
    final caps = ref.watch(activePlanCapsProvider);
    final count = servicesAsync.valueOrNull?.length ?? 0;
    final atCap = caps.maxServices != null && count >= caps.maxServices!;

    void addService() {
      if (atCap) {
        _showUpgrade(context, caps.maxServices!);
      } else {
        context.push(RoutePaths.serviceNew);
      }
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Services',
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: AppColors.ink)),
                  if (canManage)
                    GestureDetector(
                      onTap: addService,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                            color: AppColors.sage, shape: BoxShape.circle),
                        child: const Icon(Icons.add, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
            if (canManage && caps.maxServices != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                child: GestureDetector(
                  onTap: () => showSubscriptionModal(context),
                  child: Text(
                    atCap
                        ? '$count of ${caps.maxServices} services used · Upgrade for unlimited'
                        : '$count of ${caps.maxServices} services · your plan',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: atCap ? AppColors.terracottaDeep : AppColors.muted),
                  ),
                ),
              ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => ref.refresh(servicesListProvider.future),
                child: servicesAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, st) => ListView(children: [
                    const SizedBox(height: 80),
                    ErrorRetryView(
                      message: 'Could not load services.',
                      onRetry: () => ref.invalidate(servicesListProvider),
                    ),
                  ]),
                  data: (services) {
                    if (services.isEmpty) {
                      return ListView(children: const [
                        SizedBox(height: 60),
                        EmptyState(
                          icon: '🏷️',
                          title: 'No services yet',
                          message: 'Add the services your business offers.',
                        ),
                      ]);
                    }
                    // Group by category (uncategorised last).
                    final groups = <String, List<Service>>{};
                    for (final s in services) {
                      final key = (s.category ?? '').trim().isEmpty
                          ? 'Services'
                          : s.category!.trim();
                      (groups[key] ??= []).add(s);
                    }
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                      children: [
                        for (final entry in groups.entries) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                            child: Text(
                              '${entry.key}  ·  ${entry.value.length}',
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.3,
                                  color: AppColors.faint),
                            ),
                          ),
                          for (final s in entry.value)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _ServiceTile(
                                  service: s, canManage: canManage),
                            ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  final Service service;
  final bool canManage;

  const _ServiceTile({required this.service, required this.canManage});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: canManage
            ? () => context.push(RoutePaths.serviceEdit(service.id))
            : null,
        child: Opacity(
          opacity: service.isActive ? 1 : 0.5,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.parchment),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(service.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.ink)),
                          ),
                          if (!service.isActive) ...[
                            const SizedBox(width: 8),
                            _pill('Hidden', AppColors.closedBg,
                                AppColors.closedText),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text('${service.durationMinutes} min',
                              style: const TextStyle(
                                  fontSize: 13, color: AppColors.muted)),
                          if (service.depositRequired) ...[
                            const SizedBox(width: 8),
                            _pill('Deposit', AppColors.terracottaTint,
                                AppColors.terracottaDeep),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(formatCurrency(service.price, service.currency),
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink)),
                if (canManage) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right, color: AppColors.faint),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pill(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label,
          style:
              TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}
