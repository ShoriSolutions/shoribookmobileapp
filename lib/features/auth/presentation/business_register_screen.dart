import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/password_policy.dart';
import '../../../core/widgets/password_requirements.dart';
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
