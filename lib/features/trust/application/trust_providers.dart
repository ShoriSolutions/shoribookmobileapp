import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../models/customer_trust.dart';
import '../../auth/application/auth_providers.dart';
import '../data/trust_repository.dart';

final trustRepositoryProvider = Provider<TrustRepository>((ref) {
  return TrustRepository(ref.watch(supabaseClientProvider));
});

/// The signed-in customer's own trust snapshot (null when unauthenticated).
final myTrustProvider = FutureProvider.autoDispose<CustomerTrust?>((ref) async {
  final authStatus = ref.watch(authStatusProvider);
  if (authStatus != AuthStatus.authenticated) return null;
  return ref.read(trustRepositoryProvider).fetchMyTrust();
});
