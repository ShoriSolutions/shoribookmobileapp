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
import '../application/services_providers.dart';

class ServicesListScreen extends ConsumerWidget {
  const ServicesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(servicesListProvider);
    final membership = ref.watch(activeMembershipProvider).valueOrNull;
    final canManage =
        membership != null && can(membership.role, Permission.manageServices);

    return Scaffold(
      appBar: AppBar(title: const Text('Services')),
      floatingActionButton: canManage
          ? FloatingActionButton(
              backgroundColor: AppColors.terracotta,
              onPressed: () => context.push(RoutePaths.serviceNew),
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(servicesListProvider.future),
        child: servicesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, st) => ListView(
            children: [
              const SizedBox(height: 80),
              ErrorRetryView(
                message: 'Could not load services.',
                onRetry: () => ref.invalidate(servicesListProvider),
              ),
            ],
          ),
          data: (services) {
            if (services.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 60),
                  EmptyState(
                    icon: '✦',
                    title: 'No services yet',
                    message: 'Add the services your business offers.',
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: services.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) => _ServiceTile(
                service: services[i],
                canManage: canManage,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ServiceTile extends ConsumerWidget {
  final Service service;
  final bool canManage;

  const _ServiceTile({required this.service, required this.canManage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: canManage
            ? () => context.push(RoutePaths.serviceEdit(service.id))
            : null,
        child: Opacity(
          opacity: service.isActive ? 1 : 0.5,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${service.durationMinutes} min · ${formatCurrency(service.price, service.currency)}'
                        '${service.depositRequired ? ' · deposit required' : ''}',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                if (!service.isActive)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Text(
                      'Inactive',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                if (canManage) const Icon(Icons.chevron_right, color: AppColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
