/// Compile-time environment configuration.
///
/// Values are injected via `--dart-define-from-file=env/dev.json`
/// (see env/dev.example.json for the required keys). Deliberately not
/// using flutter_dotenv: that bundles the values as a plaintext asset
/// inside the compiled app, while dart-define values are compiled in
/// as Dart constants and support per-environment files (dev/staging/
/// prod) with zero extra package.
class Env {
  const Env._();

  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  );

  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
