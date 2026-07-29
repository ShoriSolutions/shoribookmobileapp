import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/terms_prefs.dart';

final termsPrefsProvider = Provider<TermsPrefs>((ref) => TermsPrefs());

/// Whether the user has agreed to the current Terms & Privacy version. Read
/// synchronously by the router's redirect, so the initial value is loaded in
/// main() and injected via a ProviderScope override (defaults to true so a
/// missing override never wrongly blocks the app).
final termsAcceptedProvider = StateProvider<bool>((ref) => true);

/// Records agreement: persists the accepted version and flips the provider so
/// the router lets the user through.
Future<void> acceptTerms(WidgetRef ref) async {
  ref.read(termsAcceptedProvider.notifier).state = true;
  await ref.read(termsPrefsProvider).setAccepted();
}
