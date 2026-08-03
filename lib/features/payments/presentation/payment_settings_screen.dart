import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../models/payment_profile.dart';
import '../../../models/payment_provider_info.dart';
import '../../business_context/application/active_business_provider.dart';
import '../application/payment_providers.dart';

/// A few country names for the picker (codes come from the registry union).
const _countryNames = <String, String>{
  'BB': 'Barbados',
  'TT': 'Trinidad & Tobago',
  'JM': 'Jamaica',
  'GY': 'Guyana',
  'US': 'United States',
  'GB': 'United Kingdom',
  'CA': 'Canada',
  'AU': 'Australia',
};

/// Payment Settings — region-aware. Shows the providers available for the
/// business's country and lets an OWNER/ADMIN configure the one supported here
/// (FirstPay). Deposits are only offered when a supported provider exists.
class PaymentSettingsScreen extends ConsumerStatefulWidget {
  const PaymentSettingsScreen({super.key});

  @override
  ConsumerState<PaymentSettingsScreen> createState() =>
      _PaymentSettingsScreenState();
}

class _PaymentSettingsScreenState extends ConsumerState<PaymentSettingsScreen> {
  final _holder = TextEditingController();
  final _account = TextEditingController();
  final _email = TextEditingController();
  final _instructions = TextEditingController();
  final _notes = TextEditingController();
  bool _obscureAccount = true;
  bool _seeded = false;
  bool _depositSeeded = false;
  int? _expiryMinutes;
  bool _requireAll = false;
  bool _saving = false;

  static const _expiryPresets = <int?>[null, 30, 60, 120, 360, 720, 1440];

  @override
  void dispose() {
    _holder.dispose();
    _account.dispose();
    _email.dispose();
    _instructions.dispose();
    _notes.dispose();
    super.dispose();
  }

  static String _expiryLabel(int? m) {
    if (m == null) return 'Off';
    if (m % 1440 == 0) return '${m ~/ 1440 * 24}h';
    if (m % 60 == 0) return '${m ~/ 60}h';
    return '${m}m';
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
      await ref.read(paymentRepositoryProvider).saveDepositSettings(
            businessId: membership.business.id,
            expiryMinutes: _expiryMinutes,
            requireAll: _requireAll,
          );
      ref.invalidate(firstPayProfileProvider);
      ref.invalidate(depositReadyProvider);
      ref.invalidate(activeMembershipProvider);
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
          final business =
              ref.watch(activeMembershipProvider).valueOrNull?.business;
          if (!_depositSeeded && business != null) {
            _expiryMinutes = business.depositExpiryMinutes;
            _requireAll = business.requireDepositAllServices;
            _depositSeeded = true;
          }

          final country = ref.watch(effectiveBusinessCountryProvider);
          final classified =
              ref.watch(businessPaymentProvidersProvider).valueOrNull ??
                  const <ClassifiedProvider>[];
          final firstPayAvailable = classified.any((e) =>
              e.info.id == 'firstpay' &&
              e.availability == ProviderAvailability.available);
          final anyAvailable = classified
              .any((e) => e.availability == ProviderAvailability.available);
          final needsAttention = profile != null && !firstPayAvailable;
          final status = PaymentProfile.statusFor(profile);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _countryRow(country),
              const SizedBox(height: 16),
              Text('Available payment methods',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              // Only FirstPay is offered for now; other providers are hidden
              // until they launch.
              for (final c in classified.where((e) => e.info.id == 'firstpay')) ...[
                _ProviderRow(provider: c.info, availability: c.availability),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 12),
              if (needsAttention) ...[
                _banner(
                  title: 'Your payment settings need attention',
                  body: "Your current payment provider isn't available in your "
                      'region. Your details are saved — set up a supported '
                      'provider to keep taking deposits.',
                ),
                const SizedBox(height: 16),
              ],
              if (!anyAvailable)
                _banner(
                  title: "Deposits aren't available in your country",
                  body: "We're working to support additional payment providers "
                      'in your region.',
                )
              else if (firstPayAvailable)
                ..._firstPayForm(status)
              else
                _banner(
                  title: 'Configure on the Shorivo website',
                  body: 'A supported provider is available in your region but '
                      "isn't configurable in the app yet.",
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _countryRow(String country) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.parchment),
      ),
      child: Row(
        children: [
          const Icon(Icons.public, color: AppColors.sageDark, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Business country',
                    style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
                const SizedBox(height: 2),
                Text('${_countryNames[country] ?? country} ($country)',
                    style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink)),
              ],
            ),
          ),
          // Country is fixed to where the account signed up; not editable here.
        ],
      ),
    );
  }

  List<Widget> _firstPayForm(PaymentStatus status) {
    return [
      const SizedBox(height: 4),
      const _FieldLabel('Account holder name'),
      _field(_holder, hint: 'e.g. Jane Doe', cap: true),
      const SizedBox(height: 16),
      const _FieldLabel('FirstPay phone number'),
      _field(
        _account,
        hint: 'Your FirstPay phone number',
        keyboard: TextInputType.phone,
        obscure: _obscureAccount,
        suffix: IconButton(
          icon: Icon(
              _obscureAccount
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              color: AppColors.muted),
          onPressed: () => setState(() => _obscureAccount = !_obscureAccount),
        ),
      ),
      const SizedBox(height: 16),
      const _FieldLabel('FirstPay email address'),
      _field(_email,
          hint: 'payments@yourbusiness.com',
          keyboard: TextInputType.emailAddress),
      const SizedBox(height: 24),
      Text('Optional', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 12),
      const _FieldLabel('Deposit instructions'),
      _field(_instructions,
          hint: 'Shown to customers when paying a deposit', lines: 3),
      const SizedBox(height: 16),
      const _FieldLabel('Business payment notes'),
      _field(_notes, hint: 'Private notes for your team', lines: 3),
      const SizedBox(height: 24),
      Text('Deposit settings', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 8),
      Card(
        margin: EdgeInsets.zero,
        child: SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          title: const Text('Require a deposit for all services'),
          subtitle: const Text(
              'Apply to every service (otherwise set it per service).'),
          value: _requireAll,
          onChanged: (v) => setState(() => _requireAll = v),
        ),
      ),
      const SizedBox(height: 14),
      const _FieldLabel('Auto-cancel if no deposit within'),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (final m in _expiryPresets)
            ChoiceChip(
              label: Text(_expiryLabel(m)),
              selected: _expiryMinutes == m,
              onSelected: (_) => setState(() => _expiryMinutes = m),
            ),
        ],
      ),
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
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      ),
      const SizedBox(height: 12),
      const Row(
        children: [
          Icon(Icons.lock_outline, size: 15, color: AppColors.muted),
          SizedBox(width: 6),
          Expanded(
            child: Text(
              'Only owners and admins can see these details. They are never '
              'shown publicly.',
              style: TextStyle(fontSize: 12.5, color: AppColors.muted),
            ),
          ),
        ],
      ),
    ];
  }

  Widget _banner({required String title, required String body}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.terracottaTint,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.terracottaTintBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.terracottaDeep)),
          const SizedBox(height: 4),
          Text(body,
              style: const TextStyle(
                  fontSize: 13, height: 1.4, color: AppColors.terracottaDeep)),
        ],
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

class _ProviderRow extends StatelessWidget {
  const _ProviderRow({required this.provider, required this.availability});
  final PaymentProviderInfo provider;
  final ProviderAvailability availability;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (availability) {
      ProviderAvailability.available => (
          'Available',
          AppColors.successBg,
          AppColors.successText
        ),
      ProviderAvailability.comingSoon => (
          'Coming soon',
          AppColors.fieldMuted,
          AppColors.muted
        ),
      ProviderAvailability.notInRegion => (
          'Not available in your region',
          AppColors.fieldMuted,
          AppColors.muted
        ),
      ProviderAvailability.inactive => ('', AppColors.fieldMuted, AppColors.muted),
    };
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.parchment),
      ),
      child: Row(
        children: [
          if (provider.logoAsset != null)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Image.asset(provider.logoAsset!, height: 20),
            )
          else
            const Padding(
              padding: EdgeInsets.only(right: 10),
              child: Icon(Icons.account_balance_outlined,
                  size: 20, color: AppColors.sageDark),
            ),
          Expanded(
            child: Text(provider.name,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.ink)),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: bg, borderRadius: BorderRadius.circular(999)),
            child: Text(label,
                style: TextStyle(
                    fontSize: 11.5, fontWeight: FontWeight.w700, color: fg)),
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
