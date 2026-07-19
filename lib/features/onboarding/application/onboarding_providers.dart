import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/onboarding_prefs.dart';

final onboardingPrefsProvider = Provider<OnboardingPrefs>((ref) {
  return OnboardingPrefs();
});

/// Whether the first-run intro has been seen. Read synchronously by the
/// router's redirect, so its initial value is loaded in main() and injected
/// via a ProviderScope override (defaults to true so a returning session
/// never re-shows the intro if the override is somehow missing).
final onboardingSeenProvider = StateProvider<bool>((ref) => true);

/// Marks the intro complete: persists the flag and flips the provider so
/// the router lets the customer through to the marketplace.
Future<void> completeOnboarding(WidgetRef ref) async {
  ref.read(onboardingSeenProvider.notifier).state = true;
  await ref.read(onboardingPrefsProvider).setSeen();
}
