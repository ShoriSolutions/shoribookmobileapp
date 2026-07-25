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

  // Guests browse as an anonymous (authenticated) session so marketplace
  // reads work — the bare `anon` role lacks the table grants, but the
  // `authenticated` role has them. The session persists on-device, so a
  // returning guest reuses it (no new user). Anonymous users are still
  // treated as guests everywhere in the UI (see authStatusProvider), and
  // stale ones are purged after 15 days. Best-effort: never block launch.
  final client = Supabase.instance.client;
  if (client.auth.currentSession == null) {
    try {
      await client.auth.signInAnonymously();
    } catch (_) {
      // Anonymous sign-ins disabled or offline — the app still launches;
      // browsing may be limited until a session can be established.
    }
  }

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