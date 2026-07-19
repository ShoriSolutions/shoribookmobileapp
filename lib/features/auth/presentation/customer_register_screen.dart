import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/password_policy.dart';
import '../../../core/widgets/password_requirements.dart';
import '../../../routing/route_paths.dart';
import '../application/customer_register_controller.dart';
import 'widgets/auth_field.dart';

/// C15 · Sign up — optional account creation. Full name, email, and a
/// password with a live checklist matching the real policy. Terms are
/// accepted implicitly by continuing (recorded server-side).
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
  bool _obscurePassword = true;
  String? _checkEmailMessage;

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final result =
        await ref.read(customerRegisterControllerProvider.notifier).signUp(
              fullName: _fullName.text.trim(),
              email: _email.text.trim(),
              password: _password.text,
            );
    if (result == null || !mounted) return;
    if (!result.sessionActive) {
      setState(() {
        _checkEmailMessage =
            'Check your email to confirm your account, then log in.';
      });
      return;
    }
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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: _checkEmailMessage != null
              ? _CheckEmailView(message: _checkEmailMessage!)
              : _buildForm(context, registerState, isLoading),
        ),
      ),
    );
  }

  Widget _buildForm(
      BuildContext context, AsyncValue<void> registerState, bool isLoading) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.arrow_back, color: AppColors.ink),
              onPressed: () => context.canPop()
                  ? context.pop()
                  : context.go(RoutePaths.register),
            ),
          ),
          const SizedBox(height: 8),
          const Text('Create your account',
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                  color: AppColors.ink)),
          const SizedBox(height: 6),
          const Text('Optional — but it saves your details for next time.',
              style: TextStyle(fontSize: 15, color: AppColors.muted)),
          const SizedBox(height: 28),
          AuthField(
            label: 'Full name',
            controller: _fullName,
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
          ),
          const SizedBox(height: 16),
          AuthField(
            label: 'Email',
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            hintText: 'you@example.com',
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Enter your email' : null,
          ),
          const SizedBox(height: 16),
          AuthField(
            label: 'Password',
            controller: _password,
            obscureText: _obscurePassword,
            hintText: '8–12 characters',
            onChanged: (_) => setState(() {}),
            validator: PasswordPolicy.validate,
            suffixIcon: IconButton(
              icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AppColors.muted),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          const SizedBox(height: 12),
          PasswordRequirements(password: _password.text),
          if (registerState.hasError) ...[
            const SizedBox(height: 12),
            Text(registerState.error.toString(),
                style: const TextStyle(color: AppColors.danger)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: isLoading ? null : _submit,
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Create account',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text('By continuing you agree to our Terms & Privacy Policy.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
          ),
          const SizedBox(height: 16),
          Center(
            child: GestureDetector(
              onTap: () => context.go(RoutePaths.login),
              child: const Text.rich(
                TextSpan(children: [
                  TextSpan(
                      text: 'Have an account? ',
                      style: TextStyle(color: AppColors.muted)),
                  TextSpan(
                      text: 'Log in',
                      style: TextStyle(
                          color: AppColors.sageDark,
                          fontWeight: FontWeight.w800)),
                ]),
                style: TextStyle(fontSize: 14.5),
              ),
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
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('✉️', style: TextStyle(fontSize: 32)),
          const SizedBox(height: 12),
          const Text('Check your email',
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink)),
          const SizedBox(height: 6),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: AppColors.muted)),
          const SizedBox(height: 20),
          TextButton(
            onPressed: () => context.go(RoutePaths.login),
            child: const Text('Back to log in'),
          ),
        ],
      ),
    );
  }
}
