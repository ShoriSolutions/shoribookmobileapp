import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/location/address_form.dart';
import '../../../core/theme/app_colors.dart';
import '../../../models/address.dart';
import '../../../routing/route_paths.dart';
import '../application/customer_register_controller.dart';
import 'widgets/auth_wave_header.dart';
import 'widgets/terms_acceptance_checkbox.dart';

class CustomerRegisterScreen extends ConsumerStatefulWidget {
  const CustomerRegisterScreen({super.key});

  @override
  ConsumerState<CustomerRegisterScreen> createState() =>
      _CustomerRegisterScreenState();
}

class _CustomerRegisterScreenState
    extends ConsumerState<CustomerRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscurePassword = true;
  bool _acceptedTerms = false;
  String? _checkEmailMessage;
  Address _address = const Address();

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final result = await ref
        .read(customerRegisterControllerProvider.notifier)
        .signUp(
          fullName: _fullName.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
          address: _address.isEmpty ? null : _address,
        );
    if (result == null || !mounted) return; // error already surfaced via the AsyncValue
    if (!result.sessionActive) {
      setState(() {
        _checkEmailMessage =
            'Check your email to confirm your account, then log in.';
      });
      return;
    }
    // A session was returned immediately (no email confirmation
    // required) — navigate ourselves rather than relying on the
    // redirect logic, which deliberately doesn't force a redirect away
    // from this route (it can be pushed from deep inside the booking
    // wizard via login's "create an account" link, and a redirect-
    // triggered `go()` would destroy that screen's state). See the
    // comment in app_router.dart's customer-mode branch.
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(RoutePaths.splash);
    }
  }

  @override
  Widget build(BuildContext context) {
    final registerState = ref.watch(customerRegisterControllerProvider);
    final isLoading = registerState.isLoading;

    return Scaffold(
      body: Column(
        children: [
          AuthWaveHeader(
            height: 140,
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
            'Join BetterBooking',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Discover and book independent pros near you.',
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _fullName,
            decoration: const InputDecoration(labelText: 'Full name'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
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
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'Min. 8 characters',
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
            validator: (v) => (v == null || v.length < 8)
                ? 'Password must be at least 8 characters'
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _confirm,
            obscureText: _obscurePassword,
            decoration: const InputDecoration(labelText: 'Confirm password'),
            validator: (v) =>
                v != _password.text ? 'Passwords do not match' : null,
          ),
          const SizedBox(height: 24),
          Text('Your address', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(
            'Optional — helps us show pros near you. You can add or change '
            'it anytime.',
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          AddressForm(onChanged: (a) => _address = a),
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
                  : const Text('Create account'),
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
          child: const Text('Back to log in'),
        ),
      ],
    );
  }
}
