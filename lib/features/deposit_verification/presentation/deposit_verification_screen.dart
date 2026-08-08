import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../models/deposit_submission.dart';
import '../application/deposit_verification_providers.dart';
import 'deposit_reject_sheet.dart';

/// Vendor Deposit Verification — review proof-of-payment submissions and
/// approve (confirm the booking) or reject (with a reason).
class DepositVerificationScreen extends ConsumerWidget {
  const DepositVerificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pendingDepositsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Deposit verification')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(pendingDepositsProvider.future),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [
            const SizedBox(height: 80),
            ErrorRetryView(
              message: AppException.from(e).message,
              onRetry: () => ref.invalidate(pendingDepositsProvider),
            ),
          ]),
          data: (subs) {
            if (subs.isEmpty) {
              return ListView(children: const [
                SizedBox(height: 120),
                Icon(Icons.verified_outlined, size: 48, color: AppColors.faint),
                SizedBox(height: 12),
                Center(
                  child: Text('No deposits waiting for review.',
                      style: TextStyle(color: AppColors.muted)),
                ),
              ]);
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: subs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _DepositCard(submission: subs[i]),
            );
          },
        ),
      ),
    );
  }
}

class _DepositCard extends ConsumerStatefulWidget {
  const _DepositCard({required this.submission});
  final DepositSubmission submission;

  @override
  ConsumerState<_DepositCard> createState() => _DepositCardState();
}

class _DepositCardState extends ConsumerState<_DepositCard> {
  bool _busy = false;

  Future<void> _approve() async {
    setState(() => _busy = true);
    try {
      final ok = await ref
          .read(depositVerificationRepositoryProvider)
          .approve(widget.submission.id);
      ref.invalidate(pendingDepositsProvider);
      if (mounted) {
        showAppSnackBar(context,
            message: ok ? 'Deposit approved — booking confirmed' : 'No change',
            isError: !ok);
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context,
            message: AppException.from(e).message, isError: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reject() async {
    final result = await showDepositRejectSheet(context);
    if (result == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(depositVerificationRepositoryProvider).reject(
          widget.submission.id, result.reason, result.notes);
      ref.invalidate(pendingDepositsProvider);
      if (mounted) {
        showAppSnackBar(context, message: 'Deposit rejected');
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context,
            message: AppException.from(e).message, isError: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _viewImage() async {
    final url = await ref
        .read(depositVerificationRepositoryProvider)
        .signedProofUrl(widget.submission.proofPath);
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Center(child: Image.network(url)),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.submission;
    final when = s.startTime != null
        ? '${DateFormat('EEE, d MMM').format(s.startTime!.toLocal())} · '
            '${DateFormat('h:mm a').format(s.startTime!.toLocal())}'
        : null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.parchment),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: _viewImage,
                child: _Thumb(
                  future: ref
                      .read(depositVerificationRepositoryProvider)
                      .signedProofUrl(s.proofPath),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.customerName ?? 'Customer',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink)),
                    const SizedBox(height: 2),
                    Text(
                      [s.serviceName, when]
                          .where((e) => e != null && e.isNotEmpty)
                          .join(' · '),
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.muted),
                    ),
                    const SizedBox(height: 6),
                    Text(formatCurrency(s.amount, s.currency),
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.terracottaDeep)),
                    Text(
                      'Submitted ${DateFormat('d MMM, h:mm a').format(s.createdAt.toLocal())}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.faint),
                    ),
                    if ((s.referenceNumber ?? '').isNotEmpty)
                      Text('Ref: ${s.referenceNumber}',
                          style: const TextStyle(
                              fontSize: 12.5, color: AppColors.muted)),
                    if ((s.customerNotes ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text('"${s.customerNotes}"',
                          style: const TextStyle(
                              fontSize: 12.5,
                              fontStyle: FontStyle.italic,
                              color: AppColors.muted)),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: FilledButton(
                    onPressed: _busy ? null : _approve,
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.sage),
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Approve'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: OutlinedButton(
                    onPressed: _busy ? null : _reject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.danger,
                      side: const BorderSide(color: Color(0xFFECCDC4)),
                    ),
                    child: const Text('Reject'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.future});
  final Future<String> future;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 64,
        height: 64,
        child: FutureBuilder<String>(
          future: future,
          builder: (context, snap) {
            if (snap.hasData) {
              return Image.network(snap.data!, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => _placeholder());
            }
            return _placeholder();
          },
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        color: AppColors.fieldMuted,
        child: const Icon(Icons.receipt_long_outlined,
            color: AppColors.muted, size: 24),
      );
}
