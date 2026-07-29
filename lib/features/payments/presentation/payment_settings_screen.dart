import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../models/payment_profile.dart';
import '../../business_context/application/active_business_provider.dart';
import '../application/payment_providers.dart';

/// Payment Settings — capture the FirstPay details a business needs before it
/// can require deposits. OWNER/ADMIN only (reached from the admin-gated More
/// menu). Built provider-agnostic so WiPay / bank / card can slot in later.
class PaymentSettingsScreen extends ConsumerStatefulWidget {
  const PaymentSettingsScreen({super.key});

  @override
  ConsumerState<PaymentSettingsScreen> createState() =>
      _PaymentSettingsScreenState();
}

class _PaymentSettingsScreenState
    extends ConsumerState<PaymentSettingsScreen> {
  final _holder = TextEditingController();
  final _account = TextEditingController();
  final _email = TextEditingController();
  final _instructions = TextEditingController();
  final _notes = TextEditingController();
  bool _obscureAccount = true;
  bool _seeded = false;
  bool _saving = false;

  @override
  void dispose() {
    _holder.dispose();
    _account.dispose();
    _email.dispose();
    _instructions.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _seed(PaymentProfile? p) {
    _holder.text = p?.accountHolderName ?? '';
    _account.text = p?.accountNumber ?? '';
    _email.text = p?.email ?? '';
    _instructions.text = p?.depositInstructions ?? '';
    _notes.text = p?.paymentNotes ?? '';
    _seeded = true;
  }

  Future<void> _save() async {
    final membership = ref.read(activeMembershipProvider).valueOrNull;
    if (membership == null) return;
    if (_holder.text.trim().isEmpty ||
        _account.text.trim().isEmpty ||
        _email.text.trim().isEmpty) {
      showAppSnackBar(context,
          message: 'Fill in the account holder, number and email.',
          isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final status = await ref.read(paymentRepositoryProvider).save(
            businessId: membership.business.id,
            details: {
              'account_holder_name': _holder.text.trim(),
              'account_number': _account.text.trim(),
              'email': _email.text.trim(),
            },
            depositInstructions: _instructions.text.trim(),
            paymentNotes: _notes.text.trim(),
          );
      ref.invalidate(firstPayProfileProvider);
      ref.invalidate(depositReadyProvider);
      if (mounted) {
        showAppSnackBar(context,
            message: status == 'ready'
                ? 'FirstPay is ready — you can now require deposits.'
                : 'Saved. Complete all required fields to finish setup.');
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
    final async = ref.watch(firstPayProfileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Payment settings')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorRetryView(
          message: AppException.from(e).message,
          onRetry: () => ref.invalidate(firstPayProfileProvider),
        ),
        data: (profile) {
          if (!_seeded) _seed(profile);
          final status = PaymentProfile.statusFor(profile);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Payment methods',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Add the details customers pay their booking deposits to. '
                'Required before you can turn on deposits.',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              _ProviderHeader(name: 'FirstPay', status: status),
              const SizedBox(height: 20),
              const _FieldLabel('Account holder name'),
              _field(_holder, hint: 'e.g. Jane Doe', cap: true),
              const SizedBox(height: 16),
              const _FieldLabel('FirstPay account number'),
              _field(
                _account,
                hint: 'Your FirstPay account number',
                obscure: _obscureAccount,
                suffix: IconButton(
                  icon: Icon(
                      _obscureAccount
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: AppColors.muted),
                  onPressed: () =>
                      setState(() => _obscureAccount = !_obscureAccount),
                ),
              ),
              const SizedBox(height: 16),
              const _FieldLabel('FirstPay email address'),
              _field(_email,
                  hint: 'payments@yourbusiness.com',
                  keyboard: TextInputType.emailAddress),
              const SizedBox(height: 24),
              Text('Optional',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              const _FieldLabel('Deposit instructions'),
              _field(_instructions,
                  hint: 'Shown to customers when paying a deposit', lines: 3),
              const SizedBox(height: 16),
              const _FieldLabel('Business payment notes'),
              _field(_notes, hint: 'Private notes for your team', lines: 3),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Save payment settings',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 12),
              const Row(
                children: [
                  Icon(Icons.lock_outline, size: 15, color: AppColors.muted),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Only owners and admins can see these details. They are '
                      'never shown publicly.',
                      style: TextStyle(fontSize: 12.5, color: AppColors.muted),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _field(
    TextEditingController c, {
    String? hint,
    bool obscure = false,
    bool cap = false,
    int lines = 1,
    TextInputType? keyboard,
    Widget? suffix,
  }) {
    return TextField(
      controller: c,
      obscureText: obscure,
      maxLines: obscure ? 1 : lines,
      keyboardType: keyboard,
      textCapitalization:
          cap ? TextCapitalization.words : TextCapitalization.none,
      decoration: InputDecoration(
        hintText: hint,
        border: const OutlineInputBorder(),
        suffixIcon: suffix,
      ),
    );
  }
}

class _ProviderHeader extends StatelessWidget {
  const _ProviderHeader({required this.name, required this.status});
  final String name;
  final PaymentStatus status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      PaymentStatus.ready => (AppColors.successBg, AppColors.successText),
      PaymentStatus.setupRequired => (
          AppColors.terracottaTint,
          AppColors.terracottaDeep
        ),
      PaymentStatus.notConfigured => (AppColors.fieldMuted, AppColors.muted),
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.parchment),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet_outlined,
              color: AppColors.sageDark),
          const SizedBox(width: 12),
          Expanded(
            child: Text(name,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: bg, borderRadius: BorderRadius.circular(999)),
            child: Text(status.label,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: AppColors.ink)),
      );
}
