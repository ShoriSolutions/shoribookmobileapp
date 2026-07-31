import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../models/review.dart';
import '../../business_context/application/active_business_provider.dart';
import '../application/reviews_providers.dart';
import 'widgets/review_card.dart';
import 'widgets/stars.dart';

/// Vendor "Customer Feedback": average rating, totals, negative-review ratio,
/// and the review list with a public reply action.
class CustomerFeedbackScreen extends ConsumerWidget {
  const CustomerFeedbackScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final business = ref.watch(activeMembershipProvider).valueOrNull?.business;
    final async = ref.watch(vendorReviewsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Customer feedback')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(vendorReviewsProvider.future),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [
            const SizedBox(height: 80),
            ErrorRetryView(
              message: AppException.from(e).message,
              onRetry: () => ref.invalidate(vendorReviewsProvider),
            ),
          ]),
          data: (reviews) {
            final avg = business?.ratingAvg ?? 0;
            final count = business?.ratingCount ?? 0;
            final neg = business?.ratingNegativeCount ?? 0;
            final nrr = count > 0 ? (neg / count * 100).round() : 0;
            final qualityBanner = _qualityBanner(business?.qualityStatus);
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (qualityBanner != null) ...[
                  qualityBanner,
                  const SizedBox(height: 16),
                ],
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.parchment),
                  ),
                  child: Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(avg.toStringAsFixed(1),
                              style: const TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink)),
                          StarsRow(rating: avg, size: 16),
                        ],
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _stat('Total reviews', '$count'),
                            const SizedBox(height: 6),
                            _stat('Negative ratio',
                                count > 0 ? '$nrr%' : '—'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (reviews.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 60),
                    child: Center(
                      child: Text('No reviews yet.',
                          style: TextStyle(color: AppColors.muted)),
                    ),
                  )
                else
                  for (final r in reviews) ...[
                    ReviewCard(
                      review: r,
                      trailing: TextButton.icon(
                        onPressed: () => _reply(context, ref, r),
                        icon: const Icon(Icons.reply, size: 18),
                        label: Text(r.hasReply ? 'Edit reply' : 'Reply'),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
              ],
            );
          },
        ),
      ),
    );
  }

  /// Warning surface for the business when its quality status is elevated.
  Widget? _qualityBanner(String? status) {
    if (status == null || status == 'excellent') return null;
    final (title, body) = switch (status) {
      'warning' => (
          "We've noticed an increase in negative feedback",
          'Please review your recent appointments and reviews. Continued '
              'negative feedback may result in an administrative review.'
        ),
      'under_review' => (
          'Your account is under administrative review',
          'Recent feedback triggered a review by our team. Keep serving '
              'customers well while we look into it.'
        ),
      _ => (
          'Account restrictions applied',
          'An administrator has applied restrictions to your account. Please '
              'contact support.'
        ),
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.terracottaTint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.terracottaTintBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 20, color: AppColors.terracottaDeep),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.terracottaDeep)),
                const SizedBox(height: 3),
                Text(body,
                    style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: AppColors.terracottaDeep)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(fontSize: 13.5, color: AppColors.muted)),
        ),
        Text(value,
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.ink)),
      ],
    );
  }

  Future<void> _reply(BuildContext context, WidgetRef ref, Review r) async {
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ReplySheet(initial: r.businessReply ?? ''),
    );
    if (text == null || text.isEmpty) return;
    try {
      await ref.read(reviewsRepositoryProvider).reply(r.id, text);
      ref.invalidate(vendorReviewsProvider);
      if (context.mounted) showAppSnackBar(context, message: 'Reply posted');
    } catch (e) {
      if (context.mounted) {
        showAppSnackBar(context,
            message: AppException.from(e).message, isError: true);
      }
    }
  }
}

/// The reply bottom sheet owns its controller so it's disposed with the sheet
/// (not while it's still animating out).
class _ReplySheet extends StatefulWidget {
  const _ReplySheet({required this.initial});
  final String initial;

  @override
  State<_ReplySheet> createState() => _ReplySheetState();
}

class _ReplySheetState extends State<_ReplySheet> {
  late final TextEditingController _c =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Reply to review',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink)),
            const SizedBox(height: 12),
            TextField(
              controller: _c,
              maxLines: 4,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Write a public response…',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: () => Navigator.pop(context, _c.text.trim()),
                child: const Text('Post reply'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
