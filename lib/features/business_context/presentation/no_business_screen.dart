import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../auth/application/auth_providers.dart';

/// Shown when an authenticated user has no ACTIVE business membership —
/// either they haven't finished the web app's business-creation wizard
/// yet, or their staff invite is still pending. Business creation is a
/// larger onboarding flow that stays on the web app for this MVP.
class NoBusinessScreen extends ConsumerWidget {
  const NoBusinessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🏪', style: TextStyle(fontSize: 40)),
                const SizedBox(height: 16),
                Text(
                  'No business found',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  "We couldn't find an active business for your account. "
                  "If you were just invited, check your email for the invite "
                  "link. If you're setting up a new business, finish that on "
                  "the BetterBooking website first — it'll show up here "
                  "automatically once it's ready.",
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: AppColors.muted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: () =>
                      ref.read(authRepositoryProvider).signOut(),
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
