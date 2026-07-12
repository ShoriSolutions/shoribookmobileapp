import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      appBar: AppBar(title: const Text('Reports')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Wrap(
              spacing: 8,
              children: [
                for (final r in ReportRange.values)
                  ChoiceChip(
                    label: Text(r.label),
                    selected: range == r,
                    onSelected: (_) =>
                        ref.read(reportRangeProvider.notifier).state = r,
                  ),
              ],
            ),
          ),
          Expanded(
            child: summaryAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, st) => ErrorRetryView(
                message: 'Could not load reports.',
                onRetry: () => ref.invalidate(reportSummaryProvider),
              ),
              data: (summary) => ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.7,
                    children: [
                      _Tile('Total bookings', '${summary.totalAppointments}'),
                      _Tile('Completed', '${summary.completedCount}'),
                      _Tile('Revenue', formatCurrency(summary.totalRevenue, currency)),
                      _Tile(
                        'Deposits collected',
                        formatCurrency(summary.depositsCollected, currency),
                      ),
                      _Tile('Cancelled', '${summary.cancelledCount}'),
                      _Tile('No-shows', '${summary.noShowCount}'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  if (summary.revenueByDay.isNotEmpty) ...[
                    Text(
                      'Revenue trend',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 180,
                      child: _RevenueLineChart(
                        summary: summary,
                        currency: currency,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  if (summary.appointmentsByDay.isNotEmpty &&
                      summary.appointmentsByDay.length <= 31) ...[
                    Text(
                      'Bookings by day',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    SizedBox(height: 160, child: _BookingsBarChart(summary: summary)),
                    const SizedBox(height: 24),
                  ],
                  if (summary.topServices.isNotEmpty) ...[
                    Text(
                      'Top services',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 10),
                    for (final s in summary.topServices)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(child: Text(s.name)),
                            Text(
                              '${s.count}',
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                  ],
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final String label;
  final String value;

  const _Tile(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
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

class _BookingsBarChart extends StatelessWidget {
  final ReportSummary summary;

  const _BookingsBarChart({required this.summary});

  @override
  Widget build(BuildContext context) {
    final days = summary.appointmentsByDay;
    final maxCount = days
        .map((d) => d.count)
        .fold<int>(1, (a, b) => a > b ? a : b);

    return BarChart(
      BarChartData(
        maxY: (maxCount + 1).toDouble(),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: const FlTitlesData(
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        barGroups: [
          for (int i = 0; i < days.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: days[i].count.toDouble(),
                  color: AppColors.sage,
                  width: 12,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
