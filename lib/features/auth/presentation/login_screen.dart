import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show OAuthProvider;
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/shori_logo.dart';
import '../../../routing/route_paths.dart';
import '../application/auth_providers.dart';
import 'widgets/auth_field.dart';
import 'widgets/social_auth_button.dart';
import '../application/login_controller.dart';

/// C14 · Log in — never a wall. "Continue as guest" stays top-right;
/// email + password, forgot-password by deep link, and optional
/// Apple/Google sign-in.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.business = false});

  /// When true the screen wears a business/vendor identity (title, copy,
  /// accent) — same credentials and auth, just tailored so a vendor arriving
  /// from "Vendor login" knows they're in the right place. The role is still
  /// resolved server-side after login and routes them to the dashboard.
  final bool business;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _guest() => context.canPop() ? context.pop() : context.go(RoutePaths.discover);

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final ok = await ref.read(loginControllerProvider.notifier).signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
    if (!mounted) return;
    if (!ok) {
      final error = ref.read(loginControllerProvider).error;
      showAppSnackBar(context, message: error.toString(), isError: true);
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
    final loginState = ref.watch(loginControllerProvider);
    final isLoading = loginState.isLoading;
    final business = widget.business;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.close, color: AppColors.ink),
                      onPressed: _guest,
                    ),
                    // A vendor logging in isn't browsing as a guest.
                    if (business)
                      const SizedBox.shrink()
                    else
                      TextButton(
                        onPressed: _guest,
                        child: const Text('Continue as guest',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.muted)),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: business
                        ? AppColors.terracottaTint
                        : AppColors.sageLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  alignment: Alignment.center,
                  child: business
                      ? const Icon(Icons.storefront,
                          size: 42, color: AppColors.terracottaDeep)
                      : const ShoriLogo(markSize: 44, showWordmark: false),
                ),
                const SizedBox(height: 20),
                if (business) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.terracottaTint,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text('BUSINESS',
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: AppColors.terracottaDeep)),
                  ),
                  const SizedBox(height: 10),
                ],
                Text(business ? 'Professionals Login' : 'Welcome back',
                    style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: AppColors.ink)),
                const SizedBox(height: 6),
                Text(
                    business
                        ? 'Access your dashboard, bookings, staff and payments.'
                        : 'Log in to sync your bookings and favourites.',
                    style: const TextStyle(
                        fontSize: 15, color: AppColors.muted)),
                const SizedBox(height: 28),
                AuthField(
                  label: 'Email',
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  hintText: 'you@example.com',
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Enter your email' : null,
                ),
                const SizedBox(height: 16),
                AuthField(
                  label: 'Password',
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  autofillHints: const [AutofillHints.password],
                  onFieldSubmitted: (_) => _submit(),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Enter your password' : null,
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
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.push(RoutePaths.forgotPassword),
                    child: const Text('Forgot password?',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColors.sageDark)),
                  ),
                ),
                const SizedBox(height: 4),
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
                        : const Text('Log in',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 20),
                const _OrDivider(),
                const SizedBox(height: 16),
                SocialAuthButton(
                  provider: SocialProvider.apple,
                  onTap: () => _oauth(OAuthProvider.apple, 'Apple'),
                ),
                const SizedBox(height: 12),
                SocialAuthButton(
                  provider: SocialProvider.google,
                  onTap: () => _oauth(OAuthProvider.google, 'Google'),
                ),
                const SizedBox(height: 20),
                Center(
                  child: GestureDetector(
                    onTap: () => context.push(business
                        ? RoutePaths.businessRegister
                        : RoutePaths.register),
                    child: Text.rich(
                      TextSpan(children: [
                        TextSpan(
                            text: business ? 'New to Shorivo? ' : 'New here? ',
                            style: const TextStyle(color: AppColors.muted)),
                        TextSpan(
                            text:
                                business ? 'Become a vendor' : 'Create account',
                            style: const TextStyle(
                                color: AppColors.sageDark,
                                fontWeight: FontWeight.w800)),
                      ]),
                      style: const TextStyle(fontSize: 14.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _oauth(OAuthProvider provider, String label) async {
    try {
      // Opens the provider; the session returns via the auth deep link.
      await ref.read(authRepositoryProvider).signInWithProvider(provider);
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context,
            message: '$label sign-in is unavailable: '
                '${AppException.from(e).message}',
            isError: true);
      }
    }
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(color: AppColors.parchment)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text('or', style: TextStyle(color: AppColors.muted)),
        ),
        Expanded(child: Divider(color: AppColors.parchment)),
      ],
    );
  }
}
