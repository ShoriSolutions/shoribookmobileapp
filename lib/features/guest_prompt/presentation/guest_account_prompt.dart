import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../routing/route_paths.dart';
import '../../auth/application/auth_providers.dart';
import '../data/guest_prompt_store.dart';

final guestPromptStoreProvider =
    Provider<GuestPromptStore>((ref) => GuestPromptStore());

// In-flight guard so overlapping build/post-frame triggers never double-show.
bool _promptBusy = false;

/// Shows the "create a free account" nudge to a guest at a natural moment
/// (after a booking, or opening My Bookings) — respecting the once-per-30-days
/// cooldown. No-op for signed-in users. Never call on app launch.
Future<void> maybeShowGuestAccountPrompt(
    BuildContext context, WidgetRef ref) async {
  if (_promptBusy) return;
  if (ref.read(authStatusProvider) == AuthStatus.authenticated) return;
  _promptBusy = true;
  try {
    final store = ref.read(guestPromptStoreProvider);
    if (await store.shouldShow()) {
      await store.markShown(); // mark first so a rebuild can't re-trigger
      if (context.mounted) await _showGuestAccountPrompt(context);
    }
  } finally {
    _promptBusy = false;
  }
}

Future<void> _showGuestAccountPrompt(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => const _GuestAccountSheet(),
  );
}

class _GuestAccountSheet extends StatefulWidget {
  const _GuestAccountSheet();

  @override
  State<_GuestAccountSheet> createState() => _GuestAccountSheetState();
}

class _GuestAccountSheetState extends State<_GuestAccountSheet> {
  bool _learnMore = false;

  static const _benefits = [
    'Save your booking history',
    'Continue conversations with vendors',
    'Save your favourite businesses',
    'Appointment reminders across all your devices',
    'Book faster with your saved details',
    'Recover your bookings if you change or lose your device',
  ];

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.85;
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppColors.parchment,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Center(
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    color: AppColors.sageLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.favorite_outline,
                      color: AppColors.sageDark, size: 30),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Keep your Shorivo experience',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink)),
              const SizedBox(height: 8),
              const Text(
                "You're browsing as a guest. Create a free Shorivo account to "
                'unlock more:',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14.5, height: 1.4, color: AppColors.muted),
              ),
              const SizedBox(height: 18),
              for (final b in _benefits) _benefitRow(b),
              const SizedBox(height: 16),
              _noticeBox(),
              if (_learnMore) ...[
                const SizedBox(height: 16),
                _learnMoreBody(),
              ] else
                Align(
                  alignment: Alignment.center,
                  child: TextButton(
                    onPressed: () => setState(() => _learnMore = true),
                    child: const Text('Learn more',
                        style: TextStyle(
                            color: AppColors.sageDark,
                            fontWeight: FontWeight.w700)),
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push(RoutePaths.customerRegister);
                  },
                  style:
                      ElevatedButton.styleFrom(backgroundColor: AppColors.sage),
                  child: const Text('Create free account',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Continue as guest',
                    style: TextStyle(color: AppColors.muted)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _benefitRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, size: 20, color: AppColors.sage),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(
                    fontSize: 14.5, height: 1.35, color: AppColors.ink)),
          ),
        ],
      ),
    );
  }

  Widget _noticeBox() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.parchment),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, size: 18, color: AppColors.muted),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'To protect your privacy and keep things tidy, guest info that '
              "isn't linked to active bookings or conversations may be removed "
              'after 15 days of inactivity. An account keeps everything '
              'securely linked to you.',
              style: TextStyle(fontSize: 12.5, height: 1.4, color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _learnMoreBody() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.sageLight,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Why create a Shorivo account?',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink)),
          SizedBox(height: 8),
          Text(
            "It's completely free and gives you a better booking experience. "
            'You can view all your appointments in one place, get reminders '
            'and booking updates, continue conversations with businesses, save '
            'favourite vendors, book faster, and keep your history even if you '
            'change devices.\n\nYou can keep using Guest Mode anytime — an '
            'account just makes your experience travel with you.',
            style: TextStyle(fontSize: 13.5, height: 1.45, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
