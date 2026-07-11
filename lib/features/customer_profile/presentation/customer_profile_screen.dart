import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../routing/route_paths.dart';
import '../../app_mode/application/app_mode_provider.dart';
import '../../auth/application/auth_providers.dart';

class CustomerProfileScreen extends ConsumerWidget {
  const CustomerProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authStatus = ref.watch(authStatusProvider);

    if (authStatus != AuthStatus.authenticated) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('◐', style: TextStyle(fontSize: 32)),
                const SizedBox(height: 12),
                Text(
                  'Sign in to manage your account',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => context.push(RoutePaths.login),
                  child: const Text('Log in'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => context.push(RoutePaths.customerRegister),
                  child: const Text('Create an account'),
                ),
              ],
            ),
          ),
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
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.sageLight,
                    foregroundColor: AppColors.sageDark,
                    child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?'),
                  ),
                  title: Text(name.isNotEmpty ? name : 'Your account'),
                  subtitle: Text(email),
                ),
              ),
              const SizedBox(height: 20),
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
            ],
          );
        },
      ),
    );
  }
}
