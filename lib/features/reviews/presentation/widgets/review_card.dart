import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../models/review.dart';
import 'stars.dart';

/// A single review: stars, reviewer, date, body, and the business's public
/// reply (if any). Optional [trailing] lets the vendor add a Reply action.
class ReviewCard extends StatelessWidget {
  const ReviewCard({super.key, required this.review, this.trailing});

  final Review review;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final r = review;
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
              StarsRow(rating: r.rating.toDouble(), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  r.reviewerName ?? 'Customer',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink),
                ),
              ),
              Text(DateFormat('d MMM').format(r.createdAt.toLocal()),
                  style: const TextStyle(fontSize: 12, color: AppColors.faint)),
            ],
          ),
          if ((r.body ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(r.body!,
                style: const TextStyle(
                    fontSize: 14, height: 1.4, color: AppColors.ink)),
          ],
          if (!r.isVisible) ...[
            const SizedBox(height: 6),
            Text(
              r.status == 'reported'
                  ? 'Reported'
                  : r.status == 'flagged'
                      ? 'Flagged for review'
                      : 'Not shown publicly',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.muted),
            ),
          ],
          if (r.hasReply) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.sageLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Response from the business',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppColors.sageDark)),
                  const SizedBox(height: 3),
                  Text(r.businessReply!,
                      style: const TextStyle(
                          fontSize: 13.5, color: AppColors.ink)),
                ],
              ),
            ),
          ],
          if (trailing != null) ...[
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerRight, child: trailing!),
          ],
        ],
      ),
    );
  }
}
