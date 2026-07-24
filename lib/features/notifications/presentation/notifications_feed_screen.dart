import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_time_formatters.dart';
import '../../../core/utils/timezone_offsets.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../models/appointment.dart';
import '../../../routing/route_paths.dart';
import '../../marketplace/application/marketplace_providers.dart';
import '../../my_bookings/application/my_bookings_providers.dart';

enum _NotifType { reminder, confirmed, depositDue, newInArea }

class _NotifItem {
  final _NotifType type;
  final String title;
  final String body;
  final String timeLabel;
  final bool unread;
  const _NotifItem(this.type, this.title, this.body, this.timeLabel,
      {this.unread = false});
}

/// C13 · Notifications — the customer's activity feed. Derived from their
/// real bookings (confirmations, reminders, deposit prompts) plus the
/// newest business in the marketplace, so nothing here is fabricated.
class NotificationsFeedScreen extends ConsumerWidget {
  const NotificationsFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(myBookingsProvider);
    final newest = ref.watch(searchResultsProvider).valueOrNull;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 20, 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.ink),
                    onPressed: () => context.canPop()
                        ? context.pop()
                        : context.go(RoutePaths.account),
                  ),
                  const SizedBox(width: 4),
                  const Text('Notifications',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink)),
                ],
              ),
            ),
            Expanded(
              child: bookingsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Center(
                    child: Text('Could not load notifications.')),
                data: (bookings) {
                  final items = _build(bookings, newest);
                  if (items.isEmpty) {
                    return const EmptyState(
                      icon: '🔔',
                      title: 'Nothing yet',
                      message:
                          'Reminders and confirmations for your bookings show up here.',
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (c, i) => _NotifCard(item: items[i]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_NotifItem> _build(List<Appointment> bookings, List? newest) {
    final now = DateTime.now().toUtc();
    final items = <_NotifItem>[];

    final upcoming = bookings
        .where((b) => b.isActive && b.startTime.isAfter(now))
        .toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));

    for (final b in upcoming) {
      final tz = b.businessTimezone ?? 'America/Barbados';
      final within48h = b.startTime.difference(now).inHours <= 48;
      if (within48h) {
        items.add(_NotifItem(
          _NotifType.reminder,
          'Reminder · ${_dayLabel(b.startTime, tz)} at ${DateTimeFormatters.time(b.startTime, tz)}',
          'Your ${b.serviceName ?? 'appointment'} '
              '${b.staffName != null ? 'with ${b.staffName} ' : ''}'
              'at ${b.businessName ?? 'the business'}.',
          _ago(b.updatedAt),
          unread: true,
        ));
      }
      if (b.depositRequired && !b.depositPaid) {
        items.add(_NotifItem(
          _NotifType.depositDue,
          'Deposit due to hold your spot',
          '${b.businessName ?? 'The business'} will contact you to arrange a '
              '${formatCurrency(b.depositAmount, b.currency)} deposit.',
          _ago(b.createdAt),
          unread: true,
        ));
      } else {
        items.add(_NotifItem(
          _NotifType.confirmed,
          'Booking confirmed',
          '${b.businessName ?? 'The business'} · '
              '${DateTimeFormatters.weekdayDate(b.startTime, tz)} · '
              '${DateTimeFormatters.time(b.startTime, tz)}.',
          _ago(b.createdAt),
        ));
      }
    }

    if (newest != null && newest.isNotEmpty) {
      final b = newest.first;
      final area = (b.address as String?)?.trim();
      items.add(_NotifItem(
        _NotifType.newInArea,
        'New in your area',
        '${b.name} just joined Shorivo'
            '${area != null && area.isNotEmpty ? ' in $area' : ''}.',
        _ago(b.createdAt),
      ));
    }

    return items;
  }

  String _dayLabel(DateTime utc, String tz) {
    final local = utcToBusinessLocal(utc, tz);
    final nowLocal = utcToBusinessLocal(DateTime.now().toUtc(), tz);
    final diff = DateTime(local.year, local.month, local.day)
        .difference(DateTime(nowLocal.year, nowLocal.month, nowLocal.day))
        .inDays;
    if (diff == 0) return 'today';
    if (diff == 1) return 'tomorrow';
    return DateFormat('EEE, d MMM').format(local);
  }

  String _ago(DateTime utc) {
    final d = DateTime.now().toUtc().difference(utc);
    if (d.inMinutes < 60) return '${d.inMinutes.clamp(1, 59)}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays == 1) return 'Yesterday';
    if (d.inDays < 7) return '${d.inDays}d ago';
    return DateFormat('d MMM').format(utc.toLocal());
  }
}

class _NotifCard extends StatelessWidget {
  const _NotifCard({required this.item});
  final _NotifItem item;

  @override
  Widget build(BuildContext context) {
    final (icon, tint, color) = _visual(item.type);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.parchment),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 19, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink)),
                const SizedBox(height: 2),
                Text(item.body,
                    style: const TextStyle(
                        fontSize: 14, height: 1.35, color: AppColors.muted)),
                const SizedBox(height: 8),
                Text(item.timeLabel,
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.faint)),
              ],
            ),
          ),
          if (item.unread)
            Container(
              margin: const EdgeInsets.only(top: 4, left: 6),
              width: 9,
              height: 9,
              decoration: const BoxDecoration(
                color: AppColors.terracotta,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }

  (IconData, Color, Color) _visual(_NotifType t) {
    switch (t) {
      case _NotifType.reminder:
        return (Icons.notifications_none, AppColors.sageLight,
            AppColors.sageDark);
      case _NotifType.confirmed:
        return (Icons.check, AppColors.successBg, AppColors.successText);
      case _NotifType.depositDue:
        return (Icons.attach_money, AppColors.terracottaTint,
            AppColors.terracottaDeep);
      case _NotifType.newInArea:
        return (Icons.storefront_outlined, const Color(0xFFE7F2F8),
            const Color(0xFF3E7A96));
    }
  }
}
