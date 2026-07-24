import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'core/env/env.dart';
import 'core/time/time_zone_service.dart';
import 'features/onboarding/application/onboarding_providers.dart';
import 'features/onboarding/data/onboarding_prefs.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load the IANA tz database up front so every UTC↔local conversion is
  // DST-correct from the first frame.
  TimeZoneService.ensureInitialized();

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
      child: const ShorivoApp(),
    ),
  );
}