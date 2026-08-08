import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../core/widgets/app_snackbar.dart';
import '../../../../models/deposit_submission.dart';
import '../../application/deposit_verification_providers.dart';
import '../deposit_reject_sheet.dart';

/// Shows the proof of payment a customer uploaded for a booking, inline on the
/// booking's detail screen. Used on both sides:
///  * customer (showActions: false) -- sees their upload + verification status,
///    and the rejection reason if it was rejected;
///  * vendor (showActions: true) -- can tap to zoom and Approve / Reject.
///
/// The image is loaded through a short-lived signed URL from the private
/// deposit-proofs bucket (never a public URL); RLS keeps it visible only to the
/// submitting customer, the owning business and Shorivo admins.
class ProofOfPaymentSection extends ConsumerWidget {
  const ProofOfPaymentSection({
    super.key,
    required this.appointmentId,
    this.paymentMethod,
    this.showActions = false,
    this.onChanged,
  });

  final String appointmentId;

  /// The booking's payment method (shown as "Method" when present).
  final String? paymentMethod;

  /// Vendor side: show Approve / Reject on a pending submission.
  final bool showActions;

  /// Called after an approve/reject so the parent can refresh its own state.
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(appointmentDepositSubmissionProvider(appointmentId));
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (sub) {
        // Nothing uploaded yet: the vendor sees a hint; the customer sees
        // nothing here (they still get the "Pay deposit" action elsewhere).
        if (sub == null || sub.proofPath.isEmpty) {
          if (!showActions) return const SizedBox.shrink();
          return _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _Header(),
                SizedBox(height: 8),
                Text('No proof of payment uploaded yet.',
                    style: TextStyle(fontSize: 13.5, color: AppColors.muted)),
              ],
            ),
          );
        }
        return _ProofCard(
          submission: sub,
          paymentMethod: paymentMethod,
          showActions: showActions,
          onChanged: onChanged,
        );
      },
    );
  }
}

class _ProofCard extends ConsumerStatefulWidget {
  const _ProofCard({
    required this.submission,
    required this.paymentMethod,
    required this.showActions,
    required this.onChanged,
  });

  final DepositSubmission submission;
  final String? paymentMethod;
  final bool showActions;
  final VoidCallback? onChanged;

  @override
  ConsumerState<_ProofCard> createState() => _ProofCardState();
}

class _ProofCardState extends ConsumerState<_ProofCard> {
  late Future<String> _urlFuture;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _urlFuture = _signedUrl();
  }

  @override
  void didUpdateWidget(covariant _ProofCard old) {
    super.didUpdateWidget(old);
    if (old.submission.proofPath != widget.submission.proofPath) {
      _urlFuture = _signedUrl();
    }
  }

  Future<String> _signedUrl() => ref
      .read(depositVerificationRepositoryProvider)
      .signedProofUrl(widget.submission.proofPath);

  Future<void> _openFullscreen() async {
    String url;
    try {
      url = await _urlFuture;
    } catch (_) {
      if (mounted) {
        showAppSnackBar(context,
            message: 'Could not open the image.', isError: true);
      }
      return;
    }
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            InteractiveViewer(
              minScale: 0.5,
              maxScale: 5,
              child: Center(
                child: Image.network(url,
                    errorBuilder: (_, __, ___) => const Padding(
                          padding: EdgeInsets.all(32),
                          child: Text('Could not load the image.',
                              style: TextStyle(color: Colors.white)),
                        )),
              ),
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

  Future<void> _approve() async {
    setState(() => _busy = true);
    try {
      final ok = await ref
          .read(depositVerificationRepositoryProvider)
          .approve(widget.submission.id);
      _refresh();
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
      await ref
          .read(depositVerificationRepositoryProvider)
          .reject(widget.submission.id, result.reason, result.notes);
      _refresh();
      if (mounted) showAppSnackBar(context, message: 'Deposit rejected');
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context,
            message: AppException.from(e).message, isError: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _refresh() {
    ref.invalidate(
        appointmentDepositSubmissionProvider(widget.submission.appointmentId));
    ref.invalidate(pendingDepositsProvider);
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.submission;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Header(),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: _openFullscreen,
                child: _Thumb(future: _urlFuture),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MetaRow(
                        label: 'Uploaded',
                        value: DateFormat('MMM d, yyyy \'at\' h:mm a')
                            .format(s.createdAt.toLocal())),
                    if (s.amount != null)
                      _MetaRow(
                          label: 'Amount',
                          value: formatCurrency(s.amount, s.currency)),
                    if ((widget.paymentMethod ?? '').isNotEmpty)
                      _MetaRow(label: 'Method', value: widget.paymentMethod!),
                    if ((s.referenceNumber ?? '').isNotEmpty)
                      _MetaRow(label: 'Reference', value: s.referenceNumber!),
                  ],
                ),
              ),
            ],
          ),
          if ((s.customerNotes ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('"${s.customerNotes}"',
                style: const TextStyle(
                    fontSize: 12.5,
                    fontStyle: FontStyle.italic,
                    color: AppColors.muted)),
          ],
          const SizedBox(height: 12),
          _StatusChip(status: s.status, reason: s.rejectReason),
          if (s.status == 'rejected' && (s.rejectNotes ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(s.rejectNotes!,
                style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
          ],
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: _openFullscreen,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: AppColors.sageDark,
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.zoom_in, size: 18),
            label: const Text('View full image',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          if (widget.showActions && s.status == 'submitted') ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 46,
                    child: FilledButton(
                      onPressed: _busy ? null : _approve,
                      style:
                          FilledButton.styleFrom(backgroundColor: AppColors.sage),
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
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();
  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Icon(Icons.receipt_long_outlined, size: 18, color: AppColors.sageDark),
        SizedBox(width: 8),
        Text('Proof of payment',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.ink)),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.parchment),
      ),
      child: child,
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 13.5, color: AppColors.ink),
          children: [
            TextSpan(
                text: '$label: ',
                style: const TextStyle(color: AppColors.muted)),
            TextSpan(
                text: value,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, this.reason});
  final String status;
  final String? reason;

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Color bg;
    late final Color fg;
    IconData? icon;
    switch (status) {
      case 'approved':
        label = 'Deposit Verified';
        bg = AppColors.successBg;
        fg = AppColors.successText;
        icon = Icons.check_circle;
        break;
      case 'rejected':
        label = (reason ?? '').isNotEmpty
            ? 'Deposit Rejected · $reason'
            : 'Deposit Rejected';
        bg = const Color(0xFFF7ECE9);
        fg = AppColors.danger;
        icon = Icons.cancel;
        break;
      case 'expired':
        label = 'Expired';
        bg = AppColors.closedBg;
        fg = AppColors.closedText;
        icon = Icons.schedule;
        break;
      case 'superseded':
        label = 'Replaced by a newer upload';
        bg = AppColors.closedBg;
        fg = AppColors.closedText;
        break;
      default: // submitted
        label = 'Pending Verification';
        bg = AppColors.terracottaTint;
        fg = AppColors.terracottaDeep;
        icon = Icons.hourglass_top;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: fg),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(label,
                style: TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w700, color: fg)),
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
        width: 76,
        height: 76,
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
