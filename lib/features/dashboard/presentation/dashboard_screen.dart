import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../routing/route_paths.dart';
import '../../appointments/presentation/widgets/appointment_card.dart';
import '../../business_context/application/active_business_provider.dart';
import '../../business_context/application/permissions.dart';
import 'package:flutter/services.dart';
import '../application/dashboard_controller.dart';
import '../data/dashboard_stats.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership = ref.watch(activeMembershipProvider).valueOrNull;
    final dataAsync = ref.watch(dashboardDataProvider);

    if (membership == null) return const SizedBox.shrink();
    final business = membership.business;
    final timezone = business.timezone;

    return Scaffold(
      appBar: AppBar(title: Text(business.name)),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(dashboardDataProvider.future),
        child: dataAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, st) => ListView(
            children: [
              const SizedBox(height: 80),
              ErrorRetryView(
                message: 'Could not load your dashboard.',
                onRetry: () => ref.invalidate(dashboardDataProvider),
              ),
            ],
          ),
          data: (data) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _StatsGrid(stats: data.stats, currency: business.currency),
              const SizedBox(height: 20),
              _QuickActions(
                canManage: can(membership.role, Permission.manageClients) ||
                    membership.role.value == 'STAFF',
                canViewClients: canViewClientContact(membership.role),
                slug: business.slug,
              ),
              const SizedBox(height: 20),
              Text(
                "Today's appointments",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              if (data.todayAppointments.isEmpty)
                const EmptyState(
                  icon: '📅',
                  title: 'Nothing on the books today',
                  message: 'New bookings will show up here as they come in.',
                )
              else
                ...data.todayAppointments.map(
                  (a) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: AppointmentCard(
                      appointment: a,
                      timezone: timezone,
                      onTap: () => context.push(
                        RoutePaths.appointmentDetailPath(a.id),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final DashboardStats stats;
  final String currency;

  const _StatsGrid({required this.stats, required this.currency});

  @override
  Widget build(BuildContext context) {
    final tiles = [
      ('Today', '${stats.bookingsToday}', AppColors.sage),
      ('This week', '${stats.bookingsThisWeek}', AppColors.terracotta),
      ('Completed (mo.)', '${stats.completedThisMonth}', AppColors.ink),
      (
        'Revenue (mo.)',
        formatCurrency(stats.revenueThisMonth, currency),
        AppColors.sageDark,
      ),
      ('No-shows (mo.)', '${stats.noShowsThisMonth}', AppColors.danger),
      ('Pending deposits', '${stats.pendingDepositsCount}', AppColors.terracotta),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.6,
      children: [
        for (final t in tiles)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    t.$1,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    t.$2,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: t.$3,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  final bool canManage;
  final bool canViewClients;
  final String slug;

  const _QuickActions({
    required this.canManage,
    required this.canViewClients,
    required this.slug,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        if (canManage)
          _ActionChip(
            icon: '＋',
            label: 'Add Booking',
            onTap: () => context.push(RoutePaths.bookingNew),
          ),
        _ActionChip(
          icon: '⊞',
          label: 'View Calendar',
          onTap: () => context.go(RoutePaths.calendar),
        ),
        _ActionChip(
          icon: '⎘',
          label: 'Copy Booking Link',
          onTap: () async {
            final url = 'https://betterbooking.app/book/$slug';
            await Clipboard.setData(ClipboardData(text: url));
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Link copied')));
            }
          },
        ),
        if (canViewClients)
          _ActionChip(
            icon: '○',
            label: 'View Clients',
            onTap: () => context.go(RoutePaths.clients),
          ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String icon;
  final String label;
  final VoidCallback onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.sageLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.sageDark,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
