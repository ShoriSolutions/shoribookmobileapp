import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../business_context/application/active_business_provider.dart';
import '../application/reports_providers.dart';
import '../data/report_summary.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(reportSummaryProvider);
    final range = ref.watch(reportRangeProvider);
    final currency =
        ref.watch(activeMembershipProvider).valueOrNull?.business.currency;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 20, 8),
              child: Row(
                children: [
                  if (context.canPop())
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: AppColors.ink),
                      onPressed: () => context.pop(),
                    )
                  else
                    const SizedBox(width: 12),
                  const Text('Reports',
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: AppColors.ink)),
                  const Spacer(),
                  _PeriodChip(range: range, ref: ref),
                ],
              ),
            ),
            Expanded(
              child: summaryAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (err, st) => ErrorRetryView(
                  message: 'Could not load reports.',
                  onRetry: () => ref.invalidate(reportSummaryProvider),
                ),
                data: (summary) {
                  final avgTicket = summary.totalAppointments > 0
                      ? summary.totalRevenue / summary.totalAppointments
                      : 0.0;
                  final noShowRate = summary.totalAppointments > 0
                      ? (summary.noShowCount / summary.totalAppointments * 100)
                          .round()
                      : 0;
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    children: [
                      // Revenue card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.parchment),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Revenue · ${range.label}',
                                style: const TextStyle(
                                    fontSize: 14, color: AppColors.muted)),
                            const SizedBox(height: 6),
                            Text(
                              formatCurrency(summary.totalRevenue, currency),
                              style: const TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1,
                                  color: AppColors.ink),
                            ),
                            if (summary.revenueByDay.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 150,
                                child: _RevenueLineChart(
                                    summary: summary, currency: currency),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 1.55,
                        children: [
                          _Tile('Bookings', '${summary.totalAppointments}',
                              AppColors.ink),
                          _Tile('Avg ticket',
                              formatCurrency(avgTicket, currency),
                              AppColors.ink),
                          _Tile('Completed', '${summary.completedCount}',
                              AppColors.sageDark),
                          _Tile('No-show rate', '$noShowRate%',
                              AppColors.danger),
                        ],
                      ),
                      if (summary.topServices.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const Text('Top services',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink)),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.parchment),
                          ),
                          child: Column(
                            children: [
                              for (var i = 0;
                                  i < summary.topServices.length;
                                  i++) ...[
                                if (i > 0)
                                  const Divider(
                                      height: 1, color: AppColors.divider),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(summary.topServices[i].name,
                                            style: const TextStyle(
                                                fontSize: 15.5,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.ink)),
                                      ),
                                      Text('${summary.topServices[i].count}',
                                          style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.muted)),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      const _ConfirmationAnalyticsSection(),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({required this.range, required this.ref});
  final ReportRange range;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showModalBottomSheet<ReportRange>(
          context: context,
          showDragHandle: true,
          builder: (ctx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final r in ReportRange.values)
                  ListTile(
                    title: Text(r.label),
                    trailing: r == range
                        ? const Icon(Icons.check, color: AppColors.sage)
                        : null,
                    onTap: () => Navigator.pop(ctx, r),
                  ),
              ],
            ),
          ),
        );
        if (picked != null) {
          ref.read(reportRangeProvider.notifier).state = picked;
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.sageLight,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(range.label,
                style: const TextStyle(
                    fontWeight: FontWeight.w700, color: AppColors.sageDark)),
            const Icon(Icons.keyboard_arrow_down,
                size: 18, color: AppColors.sageDark),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _Tile(this.label, this.value, this.color);

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
                  fontSize: 24,
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

/// Confirmation-window + waitlist metrics. Hidden when there's no activity in
/// the period, so it never clutters a business that uses neither feature.
class _ConfirmationAnalyticsSection extends ConsumerWidget {
  const _ConfirmationAnalyticsSection();

  static String _pct(double? r) => r == null ? '—' : '${(r * 100).round()}%';

  static String _avg(double? m) {
    if (m == null) return '—';
    if (m < 60) return '${m.round()}m';
    final h = m ~/ 60;
    final min = (m % 60).round();
    return min == 0 ? '${h}h' : '${h}h ${min}m';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(confirmationAnalyticsProvider);
    return async.maybeWhen(
      data: (a) {
        if (a.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Confirmations & waitlist',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink)),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.55,
              children: [
                _Tile('Confirmation rate', _pct(a.confirmationRate),
                    AppColors.sageDark),
                _Tile('Expired', '${a.expiredTotal}', AppColors.danger),
                _Tile('Avg confirm time', _avg(a.avgConfirmationMinutes),
                    AppColors.ink),
                _Tile('Waitlist conversion', _pct(a.waitlistConversionRate),
                    AppColors.sageDark),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.parchment),
              ),
              child: Column(
                children: [
                  _ContextRow(
                      label: 'Confirmed',
                      value:
                          '${a.confirmedTotal} of ${a.confirmationRequiredTotal}'),
                  const Divider(height: 1, color: AppColors.divider),
                  _ContextRow(
                      label: 'On waitlist',
                      value: a.waitlistNotified > 0
                          ? '${a.waitlistTotal} · ${a.waitlistNotified} notified'
                          : '${a.waitlistTotal}'),
                  const Divider(height: 1, color: AppColors.divider),
                  _ContextRow(
                      label: 'Rebooked after expiry',
                      value: a.expiredCustomers == 0
                          ? 'No expiries'
                          : '${a.rebookedCustomers} of ${a.expiredCustomers} '
                              '(${_pct(a.rebookRate)})'),
                ],
              ),
            ),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _ContextRow extends StatelessWidget {
  const _ContextRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 15, color: AppColors.ink)),
          ),
          Text(value,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted)),
        ],
      ),
    );
  }
}

class _RevenueLineChart extends StatelessWidget {
  final ReportSummary summary;
  final String? currency;

  const _RevenueLineChart({required this.summary, required this.currency});

  @override
  Widget build(BuildContext context) {
    final data = summary.revenueByDay;
    final spots = [
      for (int i = 0; i < data.length; i++)
        FlSpot(i.toDouble(), data[i].revenue),
    ];
    final maxRevenue = data
        .map((d) => d.revenue)
        .fold<double>(0, (a, b) => a > b ? a : b);
    // Show ~4 date labels across the range.
    final labelStep = (data.length / 4).ceil().clamp(1, data.length);

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxRevenue <= 0 ? 1 : maxRevenue * 1.2,
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: labelStep.toDouble(),
              getTitlesWidget: (value, meta) {
                final i = value.round();
                if (i < 0 || i >= data.length) {
                  return const SizedBox.shrink();
                }
                final parts = data[i].date.split('-');
                if (parts.length < 3) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${parts[1]}/${parts[2]}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.muted,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touched) => touched.map((s) {
              final i = s.x.round();
              final dateStr =
                  (i >= 0 && i < data.length) ? data[i].date : '';
              return LineTooltipItem(
                '$dateStr\n${formatCurrency(s.y, currency)}',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              );
            }).toList(),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: AppColors.sageDark,
            barWidth: 2,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.sage.withValues(alpha: 0.25),
                  AppColors.sage.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
