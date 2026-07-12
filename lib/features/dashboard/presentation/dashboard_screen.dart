import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/timezone_offsets.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../models/business.dart';
import '../../../routing/route_paths.dart';
import '../../appointments/presentation/widgets/appointment_card.dart';
import '../../booking_link/presentation/booking_share_sheet.dart';
import '../../business_context/application/active_business_provider.dart';
import '../../business_context/application/permissions.dart';
import '../application/dashboard_controller.dart';
import '../application/dashboard_prefs.dart';
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => showBookingShareSheet(context, business),
        backgroundColor: AppColors.sage,
        foregroundColor: Colors.white,
        tooltip: 'Share booking link',
        child: const Icon(Icons.share),
      ),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
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
                _HeroHeader(
                  business: business,
                  stats: data.stats,
                  timezone: timezone,
                  canViewReports:
                      can(membership.role, Permission.viewReports),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () =>
                          _showCustomizeSheet(context),
                      icon: const Icon(Icons.tune, size: 18),
                      label: const Text('Customize'),
                    ),
                  ],
                ),
                _StatCards(
                  stats: data.stats,
                  enabled: ref.watch(dashboardStatsPrefsProvider),
                ),
                const SizedBox(height: 20),
                _QuickActions(
                  canManage: can(membership.role, Permission.manageClients) ||
                      membership.role.value == 'STAFF',
                  canViewClients: canViewClientContact(membership.role),
                  slug: business.slug,
                ),
                const SizedBox(height: 24),
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
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  final Business business;
  final DashboardStats stats;
  final String timezone;
  final bool canViewReports;

  const _HeroHeader({
    required this.business,
    required this.stats,
    required this.timezone,
    required this.canViewReports,
  });

  @override
  Widget build(BuildContext context) {
    final now = utcToBusinessLocal(DateTime.now().toUtc(), timezone);
    final greeting = now.hour < 12
        ? 'Good morning'
        : now.hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.sageDark, AppColors.sage],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.sageDark.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      greeting,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      business.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (canViewReports)
                TextButton(
                  onPressed: () => context.push(RoutePaths.reports),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.18),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                  ),
                  child: const Text('Reports'),
                ),
            ],
          ),
          Text(
            DateFormat('EEEE, MMM d').format(now),
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Revenue today',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatCurrency(stats.revenueToday, business.currency),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${stats.bookingsToday}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Text(
                    'bookings',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

void _showCustomizeSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Consumer(
          builder: (ctx, ref, _) {
            final enabled = ref.watch(dashboardStatsPrefsProvider);
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Show on Home', style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  'Choose which stats appear on your dashboard.',
                  style: Theme.of(ctx).textTheme.bodySmall
                      ?.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: 8),
                for (final entry in dashboardStatCards.entries)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(entry.value),
                    value: enabled.contains(entry.key),
                    onChanged: (v) => ref
                        .read(dashboardStatsPrefsProvider.notifier)
                        .setEnabled(entry.key, v),
                  ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class _StatCards extends StatelessWidget {
  final DashboardStats stats;
  final Set<String> enabled;

  const _StatCards({required this.stats, required this.enabled});

  @override
  Widget build(BuildContext context) {
    final defs = <String, (IconData, Color, String)>{
      'completed': (
        Icons.check_circle_outline,
        AppColors.sage,
        '${stats.completedToday}',
      ),
      'noShows': (
        Icons.person_off_outlined,
        AppColors.danger,
        '${stats.noShowsToday}',
      ),
      'cancelled': (
        Icons.cancel_outlined,
        AppColors.terracotta,
        '${stats.cancelledToday}',
      ),
      'pendingDeposits': (
        Icons.account_balance_wallet_outlined,
        AppColors.sageDark,
        '${stats.pendingDepositsCount}',
      ),
      'staffOnDuty': (
        Icons.badge_outlined,
        AppColors.sage,
        '${stats.staffOnDuty}/${stats.staffTotal}',
      ),
    };
    final items = [
      for (final entry in dashboardStatCards.entries)
        if (enabled.contains(entry.key))
          (
            defs[entry.key]!.$1,
            entry.value,
            defs[entry.key]!.$3,
            defs[entry.key]!.$2,
          ),
    ];

    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          'No stats selected. Tap Customize to choose what shows here.',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: AppColors.muted),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.5,
      children: [
        for (final it in items)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: it.$4.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(it.$1, size: 20, color: it.$4),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          it.$3,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          it.$2,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.muted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
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
