import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The single SupabaseClient instance, shared by every repository.
/// Only `features/*/data/*_repository.dart` files should read this —
/// see the layering rule documented in the project plan.
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});
