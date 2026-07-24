import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/application/auth_providers.dart';
import 'routing/app_router.dart';
import 'routing/route_paths.dart';

class ShorivoApp extends ConsumerWidget {
  const ShorivoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    // supabase_flutter handles the incoming deep link itself (invite
    // email / password reset), but doesn't know this app wants a
    // dedicated "set your password" screen for it — AuthChangeEvent
    // .passwordRecovery is the signal Supabase emits specifically for
    // that case, so we route to it explicitly rather than letting the
    // generic authenticated-redirect logic decide.
    ref.listen(authStateChangesProvider, (previous, next) {
      final event = next.valueOrNull?.event;
      if (event == AuthChangeEvent.passwordRecovery) {
        // Pin to Set-password until the new password is saved, so the
        // role-based redirect can't bounce them to their home first.
        ref.read(passwordRecoveryProvider.notifier).state = true;
        router.go(RoutePaths.setPassword);
      } else if (event == AuthChangeEvent.signedOut) {
        ref.read(passwordRecoveryProvider.notifier).state = false;
      }
    });

    return MaterialApp.router(
      title: 'Shorivo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
