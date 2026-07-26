import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../models/waitlist_entry.dart';
import '../../business_context/application/active_business_provider.dart';
import '../application/waitlist_providers.dart';

/// Vendor view of the business's active waitlist — who's waiting, for what,
/// and whether they've been notified of an opening. Notifications are
/// automatic when a slot frees; this is a read view.
class WaitlistScreen extends ConsumerWidget {
  const WaitlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membership = ref.watch(activeMembershipProvider).valueOrNull;
    final businessId = membership?.business.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Waitlist')),
      body: businessId == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(businessWaitlistProvider(businessId)),
              child: ref.watch(businessWaitlistProvider(businessId)).when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) => ErrorRetryView(
                      message: AppException.from(e).message,
                      onRetry: () =>
                          ref.invalidate(businessWaitlistProvider(businessId)),
                    ),
                    data: (entries) {
                      if (entries.isEmpty) {
                        return ListView(
                          children: const [
                            SizedBox(height: 120),
                            Icon(Icons.event_seat_outlined,
                                size: 48, color: AppColors.faint),
                            SizedBox(height: 12),
                            Center(
                              child: Text(
                                'No one is on the waitlist right now.',
                                style: TextStyle(color: AppColors.muted),
                              ),
                            ),
                          ],
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: entries.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) => _WaitlistTile(entry: entries[i]),
                      );
                    },
                  ),
            ),
    );
  }
}

class _WaitlistTile extends StatelessWidget {
  const _WaitlistTile({required this.entry});
  final WaitlistEntry entry;

  @override
  Widget build(BuildContext context) {
    final prefs = <String>[
      entry.serviceName ?? 'Any service',
      if (entry.staffName != null) 'with ${entry.staffName}',
      if (entry.preferredDate != null)
        DateFormat('EEE, d MMM').format(entry.preferredDate!),
      if (entry.preferredTime != null)
        _fmt(entry.preferredTime!)
      else if (entry.preferredTimeStart != null &&
          entry.preferredTimeEnd != null)
        '${_fmt(entry.preferredTimeStart!)}-${_fmt(entry.preferredTimeEnd!)}',
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.parchment),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(entry.customerName,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink)),
              ),
              if (entry.notifiedAt != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.sageLight,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text('Notified',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppColors.sageDark)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(prefs.join(' · '),
              style: const TextStyle(fontSize: 13, color: AppColors.muted)),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.phone_outlined,
                  size: 14, color: AppColors.faint),
              const SizedBox(width: 4),
              Text(entry.customerPhone,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
              const Spacer(),
              Text('Joined ${DateFormat('d MMM').format(entry.createdAt)}',
                  style: const TextStyle(fontSize: 12, color: AppColors.faint)),
            ],
          ),
        ],
      ),
    );
  }

  static String _fmt(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length < 2) return hhmm;
    final h = int.tryParse(parts[0]) ?? 0;
    final ampm = h >= 12 ? 'PM' : 'AM';
    final hour = h % 12 == 0 ? 12 : h % 12;
    return '$hour:${parts[1]} $ampm';
  }
}
