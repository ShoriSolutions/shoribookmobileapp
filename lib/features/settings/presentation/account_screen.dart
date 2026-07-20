import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../routing/route_paths.dart';
import '../../auth/application/auth_providers.dart';

/// Account management — the hub for personal profile, security, and the
/// account actions (switch account, log out, delete account). Reached from
/// the vendor More menu and the customer Profile.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = ref.watch(authRepositoryProvider).currentUser?.email;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppColors.ink),
                  onPressed: () => context.pop(),
                ),
                const SizedBox(width: 4),
                const Text('Account & security',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink)),
              ],
            ),
            if (email != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text('Signed in as $email',
                    style:
                        const TextStyle(fontSize: 13.5, color: AppColors.muted)),
              ),
            ],
            const SizedBox(height: 20),
            const _GroupLabel('Profile'),
            _MenuCard(rows: [
              _MenuRow(
                icon: Icons.person_outline,
                title: 'Edit profile',
                subtitle: 'Name & photo',
                onTap: () => context.push(RoutePaths.editCustomerProfile),
              ),
              _MenuRow(
                icon: Icons.lock_outline,
                title: 'Change password',
                subtitle: "We'll email you a secure link",
                onTap: () => _changePassword(context, ref, email),
              ),
            ]),
            const SizedBox(height: 20),
            const _GroupLabel('Account actions'),
            _MenuCard(rows: [
              _MenuRow(
                icon: Icons.swap_horiz,
                title: 'Switch account',
                onTap: () => _signOut(context, ref, toLogin: true),
              ),
              _MenuRow(
                icon: Icons.logout,
                iconTint: const Color(0xFFF7ECE9),
                iconColor: AppColors.danger,
                title: 'Log out',
                danger: true,
                onTap: () => _confirmSignOut(context, ref),
              ),
              _MenuRow(
                icon: Icons.delete_forever_outlined,
                iconTint: const Color(0xFFF7ECE9),
                iconColor: AppColors.danger,
                title: 'Delete account',
                subtitle: 'Permanently remove your account & data',
                danger: true,
                onTap: () => context.push(RoutePaths.deleteAccount),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Future<void> _changePassword(
      BuildContext context, WidgetRef ref, String? email) async {
    if (email == null) return;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Change password?',
      message: "We'll email $email a secure link to set a new password.",
      confirmLabel: 'Send link',
      isDestructive: false,
    );
    if (!confirmed || !context.mounted) return;
    try {
      await ref.read(authRepositoryProvider).sendPasswordResetEmail(email);
      if (context.mounted) {
        showAppSnackBar(context,
            message: 'Check your email for a link to reset your password.');
      }
    } catch (e) {
      if (context.mounted) {
        showAppSnackBar(context,
            message: AppException.from(e).message, isError: true);
      }
    }
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Log out?',
      message: "You'll need to log in again to get back in.",
      confirmLabel: 'Log out',
    );
    if (!confirmed || !context.mounted) return;
    await _signOut(context, ref);
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref,
      {bool toLogin = false}) async {
    try {
      await ref.read(authRepositoryProvider).signOut();
      if (toLogin && context.mounted) context.go(RoutePaths.login);
    } catch (e) {
      if (context.mounted) {
        showAppSnackBar(context,
            message: AppException.from(e).message, isError: true);
      }
    }
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(text.toUpperCase(),
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
              color: AppColors.faint)),
    );
  }
}

class _MenuCard extends StatelessWidget {
  const _MenuCard({required this.rows});
  final List<_MenuRow> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.parchment),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, color: AppColors.divider, indent: 60),
            rows[i],
          ],
        ],
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.iconTint = AppColors.sageLight,
    this.iconColor = AppColors.sageDark,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color iconTint;
  final Color iconColor;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                  color: iconTint, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, size: 19, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: danger ? AppColors.danger : AppColors.ink)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(subtitle!,
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColors.muted)),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.faint),
          ],
        ),
      ),
    );
  }
}
