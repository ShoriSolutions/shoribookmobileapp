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
import '../../trust/application/trust_providers.dart';

/// C09 · Profile — light and guest-first. Identity card (guest or
/// signed-in), grouped menu cards for account/support, and a "For
/// businesses" card that leads into the vendor app.
class CustomerProfileScreen extends ConsumerWidget {
  const CustomerProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authStatus = ref.watch(authStatusProvider);
    final isGuest = authStatus != AuthStatus.authenticated;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            const Text('Profile',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: AppColors.ink)),
            const SizedBox(height: 16),
            if (isGuest) ..._guest(context) else ..._authed(context, ref),
            const SizedBox(height: 20),
            const _GroupLabel('For businesses'),
            _MenuCard(rows: [
              _MenuRow(
                icon: Icons.storefront_outlined,
                title: 'Become a vendor',
                onTap: () => context.push(RoutePaths.businessRegister),
              ),
              _MenuRow(
                icon: Icons.login,
                title: 'Vendor login',
                onTap: () => context.push(RoutePaths.login),
              ),
            ]),
            const SizedBox(height: 24),
            const Center(
              child: Text('ShoriBooks v1.0 · Shori Solutions',
                  style: TextStyle(fontSize: 12.5, color: AppColors.faint)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Guest ────────────────────────────────────────────────────────────
  List<Widget> _guest(BuildContext context) {
    return [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.parchment),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: AppColors.sageLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.person_outline,
                      color: AppColors.sageDark, size: 28),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Guest',
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink)),
                      SizedBox(height: 2),
                      Text('Browsing without an account',
                          style: TextStyle(
                              fontSize: 14, color: AppColors.muted)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => context.push(RoutePaths.login),
                style:
                    ElevatedButton.styleFrom(backgroundColor: AppColors.sage),
                child: const Text('Log in or sign up',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
                'Save your bookings, favourites & details across devices.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: AppColors.muted)),
          ],
        ),
      ),
      const SizedBox(height: 20),
      const _GroupLabel('Account'),
      _MenuCard(rows: [
        _MenuRow(
          icon: Icons.calendar_today_outlined,
          title: 'My bookings',
          onTap: () => context.go(RoutePaths.bookings),
        ),
        _MenuRow(
          icon: Icons.favorite_border,
          iconTint: AppColors.terracottaTint,
          iconColor: AppColors.terracotta,
          title: 'Favourites',
          onTap: () => context.push(RoutePaths.favorites),
        ),
        _MenuRow(
          icon: Icons.notifications_none,
          title: 'Notifications',
          onTap: () => context.push(RoutePaths.support),
        ),
      ]),
      const SizedBox(height: 20),
      _supportGroup(context),
    ];
  }

  // ── Signed in ────────────────────────────────────────────────────────
  List<Widget> _authed(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(myProfileProvider);
    final profile = profileAsync.valueOrNull;
    final trust = ref.watch(myTrustProvider).valueOrNull;
    final name = profile?.fullName ?? '';
    final email = profile?.email ?? '';

    return [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.parchment),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.sageLight,
              foregroundColor: AppColors.sageDark,
              backgroundImage: profile?.avatarUrl != null
                  ? CachedNetworkImageProvider(profile!.avatarUrl!)
                  : null,
              child: profile?.avatarUrl == null
                  ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w700))
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name.isNotEmpty ? name : 'Your account',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink)),
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(email,
                        style: const TextStyle(
                            fontSize: 13.5, color: AppColors.muted)),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: AppColors.muted),
              onPressed: () => context.push(RoutePaths.editCustomerProfile),
            ),
          ],
        ),
      ),
      if (trust != null) ...[
        const SizedBox(height: 14),
        _ReputationCard(trust: trust),
      ],
      const SizedBox(height: 20),
      const _GroupLabel('Account'),
      _MenuCard(rows: [
        _MenuRow(
          icon: Icons.calendar_today_outlined,
          title: 'My bookings',
          onTap: () => context.go(RoutePaths.bookings),
        ),
        _MenuRow(
          icon: Icons.favorite_border,
          iconTint: AppColors.terracottaTint,
          iconColor: AppColors.terracotta,
          title: 'Favourites',
          onTap: () => context.push(RoutePaths.favorites),
        ),
        _MenuRow(
          icon: Icons.notifications_none,
          title: 'Notifications',
          onTap: () => context.push(RoutePaths.notificationPreferences),
        ),
      ]),
      const SizedBox(height: 20),
      _supportGroup(context),
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
          title: 'Sign out',
          danger: true,
          onTap: () => _confirmSignOut(context, ref),
        ),
        _MenuRow(
          icon: Icons.delete_forever_outlined,
          iconTint: const Color(0xFFF7ECE9),
          iconColor: AppColors.danger,
          title: 'Delete account',
          danger: true,
          onTap: () => context.push(RoutePaths.deleteAccount),
        ),
      ]),
    ];
  }

  Widget _supportGroup(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _GroupLabel('Support'),
        _MenuCard(rows: [
          _MenuRow(
            icon: Icons.help_outline,
            title: 'Help & FAQ',
            onTap: () => context.push(RoutePaths.support),
          ),
          _MenuRow(
            icon: Icons.chat_bubble_outline,
            title: 'Contact support',
            onTap: () => context.push(RoutePaths.support),
          ),
        ]),
      ],
    );
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Sign out?',
      message: "You'll need to log in again to book or view your bookings.",
      confirmLabel: 'Sign out',
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

// ── Reusable menu pieces ──────────────────────────────────────────────

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
    this.iconTint = AppColors.sageLight,
    this.iconColor = AppColors.sageDark,
    this.danger = false,
  });

  final IconData icon;
  final String title;
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
                color: iconTint,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 19, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: danger ? AppColors.danger : AppColors.ink)),
            ),
            const Icon(Icons.chevron_right, color: AppColors.faint),
          ],
        ),
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.parchment),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Your reputation',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink)),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(trust.reputation,
                    style: TextStyle(
                        color: _color,
                        fontWeight: FontWeight.w700,
                        fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('${trust.trustScore}',
                  style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: _color)),
              const SizedBox(width: 6),
              const Text('/ 100 trust score',
                  style: TextStyle(fontSize: 13, color: AppColors.muted)),
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
            style: TextStyle(
                fontSize: 13,
                color: statusLine != null
                    ? AppColors.danger
                    : AppColors.muted),
          ),
        ],
      ),
    );
  }
}
