import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'core/env/env.dart';
import 'features/onboarding/application/onboarding_providers.dart';
import 'features/onboarding/data/onboarding_prefs.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  assert(
    Env.isConfigured,
    'Missing Supabase config — run with '
    '--dart-define-from-file=env/dev.json (see env/dev.example.json)',
  );

  await Supabase.initialize(
    url: Env.supabaseUrl,
    publishableKey: Env.supabaseAnonKey,
  );

  // Load the first-run flag before the router's redirect reads it, so a
  // returning session goes straight to the marketplace with no intro flash.
  final onboardingSeen = await OnboardingPrefs().seen();

  runApp(
    ProviderScope(
      overrides: [onboardingSeenProvider.overrideWith((ref) => onboardingSeen)],
      child: const ShoriBooksApp(),
    ),
  );
}