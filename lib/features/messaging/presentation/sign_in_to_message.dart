import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../routing/route_paths.dart';

/// Shown when a guest tries to message but a guest (anonymous) session can't
/// be created — instead of dumping them on the login screen with no context,
/// explain why and offer to log in / sign up.
Future<void> showSignInToMessagePrompt(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.parchment,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: AppColors.sageLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.forum_outlined,
                  color: AppColors.sageDark, size: 28),
            ),
            const SizedBox(height: 16),
            const Text('Sign in to message',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink)),
            const SizedBox(height: 8),
            const Text(
              'Create a free account or log in to chat with businesses about '
              'their services and your bookings.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.5, height: 1.4, color: AppColors.muted),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.push(RoutePaths.login);
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.sage),
                child: const Text('Log in or sign up',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Not now',
                  style: TextStyle(color: AppColors.muted)),
            ),
          ],
        ),
      ),
    ),
  );
}
