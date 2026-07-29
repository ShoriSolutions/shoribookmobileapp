import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../models/deposit_payment_details.dart';
import '../../../routing/route_paths.dart';
import '../application/deposit_flow_providers.dart';

/// Extra passed to the /deposit/:id route (businessId is needed for the authed
/// storage upload path; guestPhone for a guest submitting without an account).
class DepositFlowArgs {
  const DepositFlowArgs({required this.businessId, this.guestPhone});
  final String businessId;
  final String? guestPhone;
}

/// Guided 4-step deposit verification: Deposit required -> Payment details ->
/// Upload proof -> Submitted. Shown after a deposit-required booking is created,
/// or re-entered from My Bookings while the booking is pending a deposit.
class DepositFlowScreen extends ConsumerStatefulWidget {
  const DepositFlowScreen({
    super.key,
    required this.appointmentId,
    required this.businessId,
    this.guestPhone,
  });

  final String appointmentId;
  final String businessId;
  final String? guestPhone;

  @override
  ConsumerState<DepositFlowScreen> createState() => _DepositFlowScreenState();
}

class _DepositFlowScreenState extends ConsumerState<DepositFlowScreen> {
  static const _totalSteps = 4;
  int _step = 0;

  Uint8List? _proofBytes;
  String _proofContentType = 'image/jpeg';
  final _reference = TextEditingController();
  final _notes = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _reference.dispose();
    _notes.dispose();
    super.dispose();
  }

  DepositDetailsArgs get _args =>
      (appointmentId: widget.appointmentId, guestPhone: widget.guestPhone);

  Future<void> _pick(ImageSource source) async {
    final x = await ImagePicker()
        .pickImage(source: source, maxWidth: 2000, imageQuality: 85);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    final lower = x.name.toLowerCase();
    setState(() {
      _proofBytes = bytes;
      _proofContentType = lower.endsWith('.png')
          ? 'image/png'
          : lower.endsWith('.webp')
              ? 'image/webp'
              : 'image/jpeg';
    });
  }

  Future<void> _submit() async {
    if (_proofBytes == null) return;
    setState(() => _submitting = true);
    try {
      final status = await ref.read(depositFlowRepositoryProvider).submitProof(
            appointmentId: widget.appointmentId,
            businessId: widget.businessId,
            bytes: _proofBytes!,
            contentType: _proofContentType,
            reference: _reference.text.trim(),
            notes: _notes.text.trim(),
            guestPhone: widget.guestPhone,
          );
      if (!mounted) return;
      if (status == 'submitted') {
        setState(() => _step = 3);
      } else if (status == 'not_pending') {
        showAppSnackBar(context,
            message: 'This booking is no longer awaiting a deposit.',
            isError: true);
      } else {
        showAppSnackBar(context,
            message: 'Could not submit your deposit. Please try again.',
            isError: true);
      }
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context,
            message: AppException.from(e).message, isError: true);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(depositPaymentDetailsProvider(_args));
    return Scaffold(
      appBar: AppBar(
        title: Text('Step ${_step + 1} of $_totalSteps'),
        leading: _step == 0 || _step == 3
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => context.canPop()
                    ? context.pop()
                    : context.go(RoutePaths.discover),
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _step -= 1),
              ),
      ),
      body: Column(
        children: [
          _ProgressBar(step: _step, total: _totalSteps),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ErrorRetryView(
                message: AppException.from(e).message,
                onRetry: () =>
                    ref.invalidate(depositPaymentDetailsProvider(_args)),
              ),
              data: (d) {
                if (_step < 3 && d.status == 'not_pending') {
                  return const _Info(
                    icon: Icons.check_circle_outline,
                    title: 'Nothing to pay',
                    message:
                        'This booking is no longer awaiting a deposit.',
                  );
                }
                if (_step < 3 && d.status != 'ok') {
                  return const _Info(
                    icon: Icons.info_outline,
                    title: 'Payment details unavailable',
                    message:
                        "This business hasn't finished its payment setup yet. "
                        'Please contact them to arrange your deposit.',
                  );
                }
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: KeyedSubtree(
                    key: ValueKey(_step),
                    child: switch (_step) {
                      0 => _stepRequired(d),
                      1 => _stepPaymentDetails(d),
                      2 => _stepUpload(),
                      _ => _stepSubmitted(d),
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 1 ────────────────────────────────────────────────────────────────
  Widget _stepRequired(DepositPaymentDetails d) {
    final rows = <(IconData, String)>[
      if (d.businessName != null) (Icons.storefront_outlined, d.businessName!),
      if (d.serviceName != null) (Icons.local_offer_outlined, d.serviceName!),
      if (d.startTime != null)
        (
          Icons.event_outlined,
          '${DateFormat('EEE, d MMM').format(d.startTime!.toLocal())} · '
              '${DateFormat('h:mm a').format(d.startTime!.toLocal())}'
        ),
    ];
    return _StepBody(
      icon: Icons.receipt_long_outlined,
      title: 'Deposit required',
      subtitle:
          'A deposit is required to secure your appointment before it can be '
          'confirmed.',
      content: [
        _AmountCard(amount: d.depositAmount, currency: d.currency),
        const SizedBox(height: 16),
        _DetailCard(rows: rows),
      ],
      button: 'Continue',
      onButton: () => setState(() => _step = 1),
    );
  }

  // ── Step 2 ────────────────────────────────────────────────────────────────
  Widget _stepPaymentDetails(DepositPaymentDetails d) {
    return _StepBody(
      icon: Icons.account_balance_wallet_outlined,
      title: 'Payment details',
      subtitle:
          'Send your ${formatCurrency(d.depositAmount, d.currency)} deposit '
          'using the FirstPay details below, then continue.',
      content: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.parchment),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Image.asset('assets/branding/CIBC-Logo.png', height: 24),
                  const SizedBox(width: 8),
                  const Text('FirstPay',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink)),
                ],
              ),
              const SizedBox(height: 12),
              _CopyRow(
                  label: 'FirstPay phone number',
                  value: d.accountNumber ?? '—',
                  onCopy: () =>
                      _copy(d.accountNumber, 'FirstPay phone number')),
              if (d.accountHolderName != null)
                _CopyRow(
                    label: 'Account holder',
                    value: d.accountHolderName!,
                    onCopy: null),
              if (d.email != null)
                _CopyRow(
                    label: 'Email',
                    value: d.email!,
                    onCopy: () => _copy(d.email, 'Email')),
            ],
          ),
        ),
        if ((d.depositInstructions ?? '').isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.sageLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(d.depositInstructions!,
                style:
                    const TextStyle(fontSize: 13.5, color: AppColors.sageDark)),
          ),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => _sharePayment(d),
          icon: const Icon(Icons.ios_share, size: 18),
          label: const Text('Share payment details'),
        ),
        const SizedBox(height: 12),
        const Row(
          children: [
            Icon(Icons.info_outline, size: 16, color: AppColors.muted),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'Please complete your deposit using the information above '
                'before continuing.',
                style: TextStyle(fontSize: 12.5, color: AppColors.muted),
              ),
            ),
          ],
        ),
      ],
      button: "I've made my deposit",
      onButton: () => setState(() => _step = 2),
    );
  }

  // ── Step 3 ────────────────────────────────────────────────────────────────
  Widget _stepUpload() {
    return _StepBody(
      icon: Icons.upload_file_outlined,
      title: 'Upload proof of payment',
      subtitle:
          'Upload a screenshot or photo of your deposit so the business can '
          'verify it.',
      content: [
        if (_proofBytes == null)
          Row(
            children: [
              Expanded(
                child: _PickButton(
                  icon: Icons.photo_camera_outlined,
                  label: 'Camera',
                  onTap: () => _pick(ImageSource.camera),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _PickButton(
                  icon: Icons.photo_library_outlined,
                  label: 'Photo library',
                  onTap: () => _pick(ImageSource.gallery),
                ),
              ),
            ],
          )
        else
          Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.memory(_proofBytes!,
                    height: 220, width: double.infinity, fit: BoxFit.cover),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => setState(() => _proofBytes = null),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Choose a different image'),
              ),
            ],
          ),
        const SizedBox(height: 16),
        TextField(
          controller: _reference,
          decoration: const InputDecoration(
            labelText: 'Reference number (optional)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notes,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Notes to business (optional)',
            border: OutlineInputBorder(),
          ),
        ),
      ],
      button: 'Submit deposit',
      buttonEnabled: _proofBytes != null && !_submitting,
      busy: _submitting,
      onButton: _submit,
    );
  }

  // ── Step 4 ────────────────────────────────────────────────────────────────
  Widget _stepSubmitted(DepositPaymentDetails d) {
    final ref8 = widget.appointmentId.length >= 8
        ? widget.appointmentId.substring(0, 8).toUpperCase()
        : widget.appointmentId.toUpperCase();
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            children: [
              Center(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 550),
                  curve: Curves.elasticOut,
                  builder: (c, v, child) =>
                      Transform.scale(scale: v, child: child),
                  child: Container(
                    width: 92,
                    height: 92,
                    decoration: const BoxDecoration(
                        color: AppColors.sage, shape: BoxShape.circle),
                    child: const Icon(Icons.check,
                        color: Colors.white, size: 48),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Deposit submitted',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink)),
              const SizedBox(height: 8),
              const Text(
                'Your booking is now awaiting verification by the business. '
                "We'll notify you as soon as your deposit has been reviewed.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, height: 1.4, color: AppColors.muted),
              ),
              const SizedBox(height: 24),
              _DetailCard(rows: [
                (Icons.confirmation_number_outlined, 'Booking ref  $ref8'),
                (Icons.hourglass_top, 'Status: Pending verification'),
                const (Icons.schedule, 'Usually reviewed within a few hours'),
              ]),
            ],
          ),
        ),
        SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          child: Column(
            children: [
              SizedBox(
                height: 52,
                width: double.infinity,
                child: FilledButton(
                  onPressed: () =>
                      context.go(RoutePaths.bookingDetail(widget.appointmentId)),
                  child: const Text('View booking'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 52,
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => context.go(RoutePaths.discover),
                  child: const Text('Return to marketplace'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _copy(String? value, String label) {
    if (value == null || value.isEmpty) return;
    Clipboard.setData(ClipboardData(text: value));
    showAppSnackBar(context, message: '$label copied');
  }

  void _sharePayment(DepositPaymentDetails d) {
    final lines = <String>[
      'Deposit for ${d.serviceName ?? 'my appointment'}'
          '${d.businessName != null ? ' at ${d.businessName}' : ''}',
      if (d.depositAmount != null)
        'Amount: ${formatCurrency(d.depositAmount, d.currency)}',
      'FirstPay phone: ${d.accountNumber ?? ''}',
      if (d.accountHolderName != null) 'Account holder: ${d.accountHolderName}',
      if (d.email != null) 'Email: ${d.email}',
    ];
    Share.share(lines.join('\n'));
  }
}

// ── Shared pieces ────────────────────────────────────────────────────────────
class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.step, required this.total});
  final int step;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Row(
        children: [
          for (var i = 0; i < total; i++) ...[
            if (i > 0) const SizedBox(width: 6),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                height: 5,
                decoration: BoxDecoration(
                  color: i <= step ? AppColors.sage : AppColors.parchment,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepBody extends StatelessWidget {
  const _StepBody({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.content,
    required this.button,
    required this.onButton,
    this.buttonEnabled = true,
    this.busy = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> content;
  final String button;
  final VoidCallback onButton;
  final bool buttonEnabled;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppColors.terracottaTint,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(icon, size: 34, color: AppColors.terracottaDeep),
              ),
              const SizedBox(height: 16),
              Text(title,
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink)),
              const SizedBox(height: 6),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 15, height: 1.4, color: AppColors.muted)),
              const SizedBox(height: 20),
              ...content,
            ],
          ),
        ),
        SafeArea(
          top: false,
          minimum: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: SizedBox(
            height: 54,
            width: double.infinity,
            child: FilledButton(
              onPressed: buttonEnabled && !busy ? onButton : null,
              child: busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(button,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ],
    );
  }
}

class _AmountCard extends StatelessWidget {
  const _AmountCard({required this.amount, required this.currency});
  final double? amount;
  final String? currency;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.terracottaTint,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.terracottaTintBorder),
      ),
      child: Column(
        children: [
          const Text('Deposit amount',
              style: TextStyle(fontSize: 13, color: AppColors.terracottaDeep)),
          const SizedBox(height: 4),
          Text(formatCurrency(amount, currency),
              style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: AppColors.terracottaDeep)),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.rows});
  final List<(IconData, String)> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.parchment),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AppColors.divider),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                children: [
                  Icon(rows[i].$1, size: 20, color: AppColors.sage),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(rows[i].$2,
                        style: const TextStyle(
                            fontSize: 15, color: AppColors.ink)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CopyRow extends StatelessWidget {
  const _CopyRow(
      {required this.label, required this.value, required this.onCopy});
  final String label;
  final String value;
  final VoidCallback? onCopy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColors.muted)),
                const SizedBox(height: 2),
                Text(value,
                    style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink)),
              ],
            ),
          ),
          if (onCopy != null)
            IconButton(
              icon: const Icon(Icons.copy, size: 18, color: AppColors.sageDark),
              onPressed: onCopy,
            ),
        ],
      ),
    );
  }
}

class _PickButton extends StatelessWidget {
  const _PickButton(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.parchment),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: AppColors.sageDark),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink)),
          ],
        ),
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info(
      {required this.icon, required this.title, required this.message});
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: AppColors.muted),
            const SizedBox(height: 12),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}
