import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../models/review.dart';
import '../application/reviews_providers.dart';
import 'widgets/stars.dart';

/// Extra passed to the /review/:id route.
class ReviewSubmitArgs {
  const ReviewSubmitArgs({required this.businessId, this.businessName});
  final String businessId;
  final String? businessName;
}

/// Leave or edit a review for a completed appointment. Low ratings (1-2 stars)
/// require a written explanation of a configurable minimum length, gated with a
/// live word counter.
class ReviewSubmitScreen extends ConsumerStatefulWidget {
  const ReviewSubmitScreen({
    super.key,
    required this.appointmentId,
    required this.businessId,
    this.businessName,
  });

  final String appointmentId;
  final String businessId;
  final String? businessName;

  @override
  ConsumerState<ReviewSubmitScreen> createState() => _ReviewSubmitScreenState();
}

class _ReviewSubmitScreenState extends ConsumerState<ReviewSubmitScreen> {
  int _rating = 0;
  final _body = TextEditingController();
  bool _seeded = false;
  bool _saving = false;
  Review? _existing;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  int get _wordCount {
    final t = _body.text.trim();
    if (t.isEmpty) return 0;
    return t.split(RegExp(r'\s+')).length;
  }

  bool _meetsRequirement(int minWords) {
    if (_rating == 0) return false;
    if (_rating <= 2) return _wordCount >= minWords;
    return true;
  }

  Future<void> _submit(int minWords) async {
    setState(() => _saving = true);
    try {
      final repo = ref.read(reviewsRepositoryProvider);
      final body = _body.text.trim().isEmpty ? null : _body.text.trim();
      final status = _existing != null
          ? await repo.edit(_existing!.id, _rating, body)
          : await repo.submit(widget.appointmentId, _rating, body);
      if (!mounted) return;
      switch (status) {
        case 'created':
        case 'updated':
          ref.invalidate(businessReviewsProvider(widget.businessId));
          ref.invalidate(reviewForAppointmentProvider(widget.appointmentId));
          ref.invalidate(vendorReviewsProvider);
          showAppSnackBar(context, message: 'Thanks for your review!');
          context.pop();
        case 'needs_detail':
          showAppSnackBar(context,
              message: 'Please add at least $minWords words for a low rating.',
              isError: true);
        case 'not_completed':
          showAppSnackBar(context,
              message: 'You can review once the appointment is completed.',
              isError: true);
        case 'already_reviewed':
          showAppSnackBar(context,
              message: "You've already reviewed this appointment.",
              isError: true);
        case 'window_closed':
          showAppSnackBar(context,
              message: 'The edit window for this review has closed.',
              isError: true);
        default:
          showAppSnackBar(context,
              message: 'Could not save your review.', isError: true);
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context,
            message: AppException.from(e).message, isError: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final minWords = ref.watch(reviewMinWordsProvider).valueOrNull ?? 75;
    final existingAsync =
        ref.watch(reviewForAppointmentProvider(widget.appointmentId));

    // Prefill in edit mode, once.
    final existing = existingAsync.valueOrNull;
    if (!_seeded && existing != null) {
      _existing = existing;
      _rating = existing.rating;
      _body.text = existing.body ?? '';
      _seeded = true;
    } else if (!_seeded && existingAsync.hasValue) {
      _seeded = true; // no existing review -> fresh
    }

    final lowRating = _rating >= 1 && _rating <= 2;
    final canSubmit = _meetsRequirement(minWords) && !_saving;

    return Scaffold(
      appBar: AppBar(
          title: Text(_existing != null ? 'Edit review' : 'Leave a review')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            widget.businessName != null
                ? 'How was your appointment with ${widget.businessName}?'
                : 'How was your appointment?',
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.ink),
          ),
          const SizedBox(height: 4),
          const Text(
            'Share your experience to help other customers and support quality '
            'service on Shorivo.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          StarRatingInput(
            value: _rating,
            onChanged: (v) => setState(() => _rating = v),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _body,
            maxLines: 6,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: lowRating
                  ? 'Please tell us more about your experience…'
                  : 'Write a review (optional)…',
              border: const OutlineInputBorder(),
            ),
          ),
          if (lowRating) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.terracottaTint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text('Please tell us more about your experience.',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.terracottaDeep)),
                      ),
                      Text('$_wordCount / $minWords words',
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: _wordCount >= minWords
                                  ? AppColors.sageDark
                                  : AppColors.terracottaDeep)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Low ratings can significantly affect a business, so we ask '
                    'for enough detail to help them understand the issue and to '
                    'help our team investigate if necessary.',
                    style: TextStyle(fontSize: 12, color: AppColors.terracottaDeep),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: canSubmit ? () => _submit(minWords) : null,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(_existing != null ? 'Update review' : 'Submit review',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }
}
