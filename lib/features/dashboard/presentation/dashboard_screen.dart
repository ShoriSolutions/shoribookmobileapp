import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/greeting.dart';
import '../../../core/utils/timezone_offsets.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../models/appointment.dart';
import '../../../models/business.dart';
import '../../../models/staff_profile.dart';
import '../../../routing/route_paths.dart';
import '../../app_mode/application/app_mode_provider.dart';
import '../../booking_link/presentation/booking_share_sheet.dart';
import '../../business_context/application/active_business_provider.dart';
import '../../staff/application/staff_providers.dart';
import '../../subscription/application/subscription_providers.dart';
import '../../subscription/presentation/subscription_modal.dart';
import '../application/dashboard_controller.dart';
import '../application/dashboard_prefs.dart';
import '../data/dashboard_stats.dart';

/// V04 · Home dashboard — greeting + trial banner, today's report cards,
/// on-duty staff and the next appointments.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership = ref.watch(activeMembershipProvider).valueOrNull;
    final dataAsync = ref.watch(dashboardDataProvider);
    if (membership == null) return const SizedBox.shrink();
    final business = membership.business;
    final tz = business.timezone;
    final fullName = ref.watch(myProfileProvider).valueOrNull?.fullName;
    final firstName = (fullName == null || fullName.trim().isEmpty)
        ? null
        : fullName.trim().split(' ').first;

    _maybeShowLaunchPromo(context, ref);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(dashboardDataProvider.future),
          child: dataAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, st) => ListView(children: [
              const SizedBox(height: 80),
              ErrorRetryView(
                message: 'Could not load your dashboard.',
                onRetry: () => ref.invalidate(dashboardDataProvider),
              ),
            ]),
            data: (data) => ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                _header(context, business, firstName),
                if (business.subscriptionStatus == 'trialing') ...[
                  const SizedBox(height: 12),
                  _trialBanner(context, business),
                ],
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Today · ${DateFormat('EEE d MMM').format(utcToBusinessLocal(DateTime.now().toUtc(), tz))}',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink)),
                    GestureDetector(
                      onTap: () => _showCustomizeSheet(context),
                      child: const Text('Edit cards',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.sageDark)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _statGrid(data.stats, business.currency),
                const SizedBox(height: 24),
                const Text('On duty',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink)),
                const SizedBox(height: 12),
                _OnDutyRow(),
                const SizedBox(height: 24),
                const Text('Next up',
                    style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink)),
                const SizedBox(height: 12),
                if (data.todayAppointments.isEmpty)
                  const EmptyState(
                    icon: '📅',
                    title: 'Nothing on the books today',
                    message: 'New bookings will show up here as they come in.',
                  )
                else
                  for (final a in data.todayAppointments)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _NextUpRow(
                        appt: a,
                        tz: tz,
                        onTap: () => context
                            .push(RoutePaths.appointmentDetailPath(a.id)),
                      ),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(BuildContext context, Business business, String? firstName) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(Greeting.full(name: firstName),
                  style: const TextStyle(fontSize: 14, color: AppColors.muted)),
              const SizedBox(height: 2),
              Text(business.name,
                  style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: AppColors.ink)),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.parchment),
          ),
          child: IconButton(
            icon: const Icon(Icons.ios_share, color: AppColors.ink, size: 20),
            onPressed: () => showBookingShareSheet(context, business),
          ),
        ),
      ],
    );
  }

  Widget _trialBanner(BuildContext context, Business business) {
    final daysLeft = business.trialEndsAt
        ?.difference(DateTime.now())
        .inDays
        .clamp(0, 99);
    return GestureDetector(
      onTap: () => showSubscriptionModal(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.terracottaTint,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.terracottaTintBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.hourglass_empty,
                size: 18, color: AppColors.terracottaDeep),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                daysLeft != null
                    ? 'Trial · $daysLeft days left'
                    : 'Free trial active',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.terracottaDeep),
              ),
            ),
            const Text('Upgrade',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.terracottaDeep)),
          ],
        ),
      ),
    );
  }

  Widget _statGrid(DashboardStats stats, String currency) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.55,
      children: [
        _StatCard(
            value: '${stats.bookingsToday}',
            label: 'Bookings today',
            color: AppColors.ink),
        _StatCard(
            value: formatCurrency(stats.revenueToday, currency),
            label: 'Revenue',
            color: AppColors.sageDark),
        _StatCard(
            value: '${stats.completedToday}',
            label: 'Completed',
            color: AppColors.ink),
        _StatCard(
            value: '${stats.noShowsToday}',
            label: 'No-show',
            color: AppColors.danger),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(
      {required this.value, required this.label, required this.color});
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.parchment),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: color)),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(fontSize: 14, color: AppColors.muted)),
        ],
      ),
    );
  }
}

class _OnDutyRow extends ConsumerWidget {
  static const _colors = [AppColors.sage, AppColors.terracotta, AppColors.shoriBlue];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(staffListProvider);
    final staff = (staffAsync.valueOrNull ?? const <StaffProfile>[])
        .where((s) => s.isBookable)
        .toList();
    return SizedBox(
      height: 82,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (var i = 0; i < staff.length; i++)
            _avatar(staff[i], _colors[i % _colors.length]),
          _add(context),
        ],
      ),
    );
  }

  Widget _avatar(StaffProfile s, Color color) {
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: color,
            foregroundColor: color == AppColors.shoriBlue
                ? AppColors.ink
                : Colors.white,
            backgroundImage:
                s.profileImageUrl != null ? NetworkImage(s.profileImageUrl!) : null,
            child: s.profileImageUrl == null
                ? Text(s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w700))
                : null,
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 64,
            child: Text(s.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
          ),
        ],
      ),
    );
  }

  Widget _add(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => context.push(RoutePaths.staff),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.fieldMuted,
              shape: BoxShape.circle,
              border: Border.all(
                  color: AppColors.parchment, style: BorderStyle.solid),
            ),
            child: const Icon(Icons.add, color: AppColors.muted),
          ),
        ),
        const SizedBox(height: 6),
        const Text('Add',
            style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
      ],
    );
  }
}

class _NextUpRow extends StatelessWidget {
  const _NextUpRow({required this.appt, required this.tz, required this.onTap});
  final Appointment appt;
  final String tz;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final local = utcToBusinessLocal(appt.startTime, tz);
    final (label, bg, fg) = _status(appt);
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.parchment),
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(DateFormat('h:mm').format(local),
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink)),
                  Text(DateFormat('a').format(local),
                      style:
                          const TextStyle(fontSize: 12, color: AppColors.muted)),
                ],
              ),
              const SizedBox(width: 12),
              Container(width: 1, height: 40, color: AppColors.divider),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(appt.customerName ?? 'Client',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink)),
                    const SizedBox(height: 1),
                    Text(
                      [appt.serviceName, appt.staffName]
                          .where((s) => s != null && s.isNotEmpty)
                          .join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                    color: bg, borderRadius: BorderRadius.circular(999)),
                child: Text(label,
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  (String, Color, Color) _status(Appointment a) {
    switch (a.status) {
      case AppointmentStatus.pending:
        return ('Pending', AppColors.terracottaTint, AppColors.terracottaDeep);
      case AppointmentStatus.completed:
        return ('Completed', AppColors.closedBg, AppColors.closedText);
      case AppointmentStatus.cancelled:
        return ('Cancelled', AppColors.closedBg, AppColors.closedText);
      case AppointmentStatus.noShow:
        return ('No-show', const Color(0xFFF7ECE9), AppColors.danger);
      default:
        return ('Confirmed', AppColors.successBg, AppColors.successText);
    }
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
                Text('Extra stats', style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text(
                  'Bookings, revenue, completed and no-show always show. '
                  'Toggle any extras to track.',
                  style: Theme.of(ctx)
                      .textTheme
                      .bodySmall
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

// Shows the subscription promo once per app launch for business owners who
// haven't chosen "Don't show again".
bool _launchPromoShown = false;

void _maybeShowLaunchPromo(BuildContext context, WidgetRef ref) {
  if (_launchPromoShown) return;
  _launchPromoShown = true;
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    final status = ref
        .read(activeMembershipProvider)
        .valueOrNull
        ?.business
        .subscriptionStatus;
    if (status == 'active' || status == 'trialing') return;
    final dismissed =
        await ref.read(subscriptionPromoPrefsProvider).dismissedForever();
    if (dismissed || !context.mounted) return;
    await Future<void>.delayed(const Duration(milliseconds: 500));
    if (context.mounted) {
      showSubscriptionModal(context, autoPromo: true);
    }
  });
}
