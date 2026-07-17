import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../models/customer_trust.dart';
import '../../../routing/route_paths.dart';
import '../../app_mode/application/app_mode_provider.dart';
import '../../auth/application/auth_providers.dart';
import '../../support/presentation/legal_document_screen.dart';
import '../../support/support_content.dart';
import '../../trust/application/trust_providers.dart';

class CustomerProfileScreen extends ConsumerWidget {
  const CustomerProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authStatus = ref.watch(authStatusProvider);

    if (authStatus != AuthStatus.authenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Guest header — no account needed to browse or book.
            const Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.sageLight,
                  foregroundColor: AppColors.sageDark,
                  child: Icon(Icons.person_outline),
                ),
                title: Text('Guest User'),
                subtitle: Text('Browsing without an account'),
              ),
            ),
            const SizedBox(height: 12),
            _GuestTile(
              icon: Icons.event_note_outlined,
              label: 'My Appointments',
              onTap: () => context.push(RoutePaths.bookings),
            ),
            _GuestTile(
              icon: Icons.storefront_outlined,
              label: 'Become a Vendor',
              onTap: () => context.push(RoutePaths.businessRegister),
            ),
            _GuestTile(
              icon: Icons.login,
              label: 'Vendor Login',
              onTap: () => context.push(RoutePaths.login),
            ),
            const SizedBox(height: 8),
            _GuestTile(
              icon: Icons.help_outline,
              label: 'Support',
              onTap: () => context.push(RoutePaths.support),
            ),
            _GuestTile(
              icon: Icons.privacy_tip_outlined,
              label: 'Privacy Policy',
              onTap: () => _openLegal(
                  context, 'Privacy Policy', SupportContent.privacyPolicy),
            ),
            _GuestTile(
              icon: Icons.description_outlined,
              label: 'Terms of Service',
              onTap: () => _openLegal(
                  context, 'Terms of Service', SupportContent.termsOfService),
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () => context.push(RoutePaths.customerRegister),
                child: const Text('Create a customer account'),
              ),
            ),
          ],
        ),
      );
    }

    final profileAsync = ref.watch(myProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(
          child: Text(AppException.from(err).message),
        ),
        data: (profile) {
          final name = profile?.fullName ?? '';
          final email = profile?.email ?? '';
          final trust = ref.watch(myTrustProvider).valueOrNull;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.sageLight,
                    foregroundColor: AppColors.sageDark,
                    backgroundImage: profile?.avatarUrl != null
                        ? CachedNetworkImageProvider(profile!.avatarUrl!)
                        : null,
                    child: profile?.avatarUrl == null
                        ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?')
                        : null,
                  ),
                  title: Text(name.isNotEmpty ? name : 'Your account'),
                  subtitle: Text(email),
                  trailing: const Icon(Icons.edit_outlined,
                      color: AppColors.muted),
                  onTap: () => context.push(RoutePaths.editCustomerProfile),
                ),
              ),
              if (trust != null) ...[
                const SizedBox(height: 12),
                _ReputationCard(trust: trust),
              ],
              const SizedBox(height: 20),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.notifications_none,
                      color: AppColors.sage),
                  title: const Text('Notifications'),
                  trailing:
                      const Icon(Icons.chevron_right, color: AppColors.muted),
                  onTap: () =>
                      context.push(RoutePaths.notificationPreferences),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.help_outline, color: AppColors.sage),
                  title: const Text('Help & Support'),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
                  onTap: () => context.push(RoutePaths.support),
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.swap_horiz, color: AppColors.sage),
                  title: const Text('Switch account'),
                  trailing:
                      const Icon(Icons.chevron_right, color: AppColors.muted),
                  onTap: () async {
                    try {
                      await ref.read(authRepositoryProvider).signOut();
                      if (context.mounted) context.go(RoutePaths.login);
                    } catch (e) {
                      if (context.mounted) {
                        showAppSnackBar(
                          context,
                          message: AppException.from(e).message,
                          isError: true,
                        );
                      }
                    }
                  },
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.logout, color: AppColors.danger),
                  title: const Text('Sign out'),
                  onTap: () async {
                    final confirmed = await showConfirmDialog(
                      context,
                      title: 'Sign out?',
                      message: "You'll need to log in again to book or view "
                          "your bookings.",
                      confirmLabel: 'Sign out',
                    );
                    if (!confirmed) return;
                    try {
                      await ref.read(authRepositoryProvider).signOut();
                    } catch (e) {
                      if (context.mounted) {
                        showAppSnackBar(
                          context,
                          message: AppException.from(e).message,
                          isError: true,
                        );
                      }
                    }
                  },
                ),
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.delete_forever_outlined,
                      color: AppColors.danger),
                  title: const Text(
                    'Delete account',
                    style: TextStyle(color: AppColors.danger),
                  ),
                  trailing:
                      const Icon(Icons.chevron_right, color: AppColors.muted),
                  onTap: () => context.push(RoutePaths.deleteAccount),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ReputationCard extends StatelessWidget {
  final CustomerTrust trust;

  const _ReputationCard({required this.trust});

  Color get _color {
    if (trust.trustScore >= 60) return AppColors.sage;
    if (trust.trustScore >= 40) return AppColors.terracotta;
    return AppColors.danger;
  }

  @override
  Widget build(BuildContext context) {
    String? statusLine;
    if (trust.permanentBan) {
      statusLine = 'Your account is restricted from booking. Contact support.';
    } else if (trust.isSuspended) {
      statusLine =
          'Booking is paused until ${DateFormat('MMM d, y').format(trust.suspensionUntil!.toLocal())}.';
    } else if (trust.depositRequired) {
      statusLine = 'A refundable deposit may be required to book.';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Your reputation',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    trust.reputation,
                    style: TextStyle(
                      color: _color,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${trust.trustScore}',
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: _color,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '/ 100 trust score',
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: AppColors.muted),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: trust.trustScore / 100,
                backgroundColor: AppColors.parchment,
                color: _color,
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              statusLine ??
                  'Completed bookings raise your score; no-shows lower it.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: statusLine != null
                        ? AppColors.danger
                        : AppColors.muted,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

void _openLegal(BuildContext context, String title, String body) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => LegalDocumentScreen(title: title, body: body),
    ),
  );
}

/// A tappable row in the Guest Profile.
class _GuestTile extends StatelessWidget {
  const _GuestTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: AppColors.sage),
        title: Text(label),
        trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
        onTap: onTap,
      ),
    );
  }
}
