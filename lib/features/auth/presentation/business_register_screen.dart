import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/location/address_form.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/currency_rates.dart';
import '../../../core/utils/password_policy.dart';
import '../../../models/address.dart';
import '../../../core/widgets/password_requirements.dart';
import '../../../models/subscription_package.dart';
import '../../subscription/application/subscription_providers.dart';
import '../../../models/business.dart';
import '../../../routing/route_paths.dart';
import '../application/business_register_controller.dart';
import 'widgets/auth_wave_header.dart';
import 'widgets/terms_acceptance_checkbox.dart';

class BusinessRegisterScreen extends ConsumerStatefulWidget {
  const BusinessRegisterScreen({super.key});

  @override
  ConsumerState<BusinessRegisterScreen> createState() =>
      _BusinessRegisterScreenState();
}

class _BusinessRegisterScreenState
    extends ConsumerState<BusinessRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _businessName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _category;
  bool _obscurePassword = true;
  bool _acceptedTerms = false;
  String? _checkEmailMessage;
  Address _address = const Address();

  @override
  void dispose() {
    _fullName.dispose();
    _businessName.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final result = await ref
        .read(businessRegisterControllerProvider.notifier)
        .signUp(
          fullName: _fullName.text.trim(),
          businessName: _businessName.text.trim(),
          category: _category ?? 'other',
          email: _email.text.trim(),
          password: _password.text,
          address: _address.isEmpty ? null : _address,
        );
    if (result == null || !mounted) return; // error surfaced via AsyncValue
    if (!result.sessionActive) {
      setState(() {
        _checkEmailMessage =
            'Check your email to confirm your account. Your business will be '
            'set up automatically the first time you log in.';
      });
      return;
    }
    // Session live immediately (autoconfirm) — the business was created
    // in the controller; let the router redirect route us to the business
    // home once the membership resolves.
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RoutePaths.splash);
    }
  }

  @override
  Widget build(BuildContext context) {
    final registerState = ref.watch(businessRegisterControllerProvider);
    final isLoading = registerState.isLoading;

    return Scaffold(
      body: Column(
        children: [
          AuthWaveHeader(
            height: 130,
            showBack: true,
            onBack: () => context.canPop()
                ? context.pop()
                : context.go(RoutePaths.register),
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 24,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: _checkEmailMessage != null
                        ? _CheckEmailView(message: _checkEmailMessage!)
                        : _buildForm(context, registerState, isLoading),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(
    BuildContext context,
    AsyncValue<void> registerState,
    bool isLoading,
  ) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Grow your business',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Take online bookings and manage your schedule, clients and staff '
            'in one place.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 20),
          const _PlansPreview(),
          const SizedBox(height: 24),
          TextFormField(
            controller: _fullName,
            decoration: const InputDecoration(labelText: 'Your name'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _businessName,
            decoration: const InputDecoration(labelText: 'Business name'),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? 'Enter your business name'
                : null,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _category,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Category'),
            items: [
              for (final c in BusinessCategory.all)
                DropdownMenuItem(
                  value: c.value,
                  child: Text('${c.emoji}  ${c.label}'),
                ),
            ],
            onChanged: (v) => setState(() => _category = v),
            validator: (v) => v == null ? 'Choose a category' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email address'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter your email' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _password,
            obscureText: _obscurePassword,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: '8–12 characters',
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AppColors.muted,
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: PasswordPolicy.validate,
          ),
          const SizedBox(height: 8),
          PasswordRequirements(password: _password.text),
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirm,
            obscureText: _obscurePassword,
            decoration: const InputDecoration(labelText: 'Confirm password'),
            validator: (v) =>
                v != _password.text ? 'Passwords do not match' : null,
          ),
          const SizedBox(height: 24),
          Text('Business location',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(
            'So customers can find you on the map and nearby search. You can '
            'change it anytime.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          AddressForm(
            streetLabel: 'Business address (optional)',
            onChanged: (a) => _address = a,
          ),
          const SizedBox(height: 16),
          // V01 · the category/name 90-day lock note, surfaced up front.
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.sageLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.sageTintBorder),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.lock_outline, size: 18, color: AppColors.sageDark),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your name & category lock for 90 days after setup to keep '
                    'marketplace listings stable.',
                    style: TextStyle(fontSize: 13, color: AppColors.sageDark),
                  ),
                ),
              ],
            ),
          ),
          if (registerState.hasError) ...[
            const SizedBox(height: 12),
            Text(
              registerState.error.toString(),
              style: const TextStyle(color: AppColors.danger),
            ),
          ],
          const SizedBox(height: 16),
          TermsAcceptanceCheckbox(
            value: _acceptedTerms,
            onChanged: (v) => setState(() => _acceptedTerms = v),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (isLoading || !_acceptedTerms) ? null : _submit,
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Create business account'),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () => context.go(RoutePaths.login),
              child: const Text('Already have an account? Log in'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckEmailView extends StatelessWidget {
  const _CheckEmailView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('✉️', style: TextStyle(fontSize: 32)),
        const SizedBox(height: 12),
        Text('Check your email', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 20),
        TextButton(
          onPressed: () => context.go(RoutePaths.login),
          child: const Text('Go to log in'),
        ),
      ],
    );
  }
}

/// Read-only preview of the subscription plans shown during registration —
/// sets expectations: 14-day full-access trial, then pick a plan. Loaded
/// live from the DB (anon-readable), so it always reflects current pricing.
class _PlansPreview extends ConsumerWidget {
  const _PlansPreview();

  String _price(SubscriptionPackage p) {
    if (p.priceAmount == null) return '';
    final per = switch (p.billingPeriod) {
      'annual' => '/yr',
      'weekly' => '/wk',
      'once' => '',
      _ => '/mo',
    };
    // Shown in the stored base currency (BBD); the modal lets them convert.
    return '${CurrencyRates.format(p.priceAmount!, p.currency, from: p.currency)} $per';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(subscriptionPackagesProvider);
    return async.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (packages) {
        if (packages.isEmpty) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.sageLight,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('✨ 14-day free trial',
                  style: TextStyle(
                      fontWeight: FontWeight.w800, color: AppColors.sageDark)),
              const SizedBox(height: 2),
              Text(
                'Full access to everything free for 14 days. After that, choose '
                'the plan that fits:',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              for (final p in packages)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(p.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                            ),
                            if (p.isPopular) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: AppColors.sage.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: const Text('Popular',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.sageDark)),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Text(_price(p),
                          style: TextStyle(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
