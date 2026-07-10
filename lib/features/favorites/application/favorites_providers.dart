import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../models/business.dart';
import '../../auth/application/auth_providers.dart';
import '../data/favorites_repository.dart';

final favoritesRepositoryProvider = Provider<FavoritesRepository>((ref) {
  return FavoritesRepository(ref.watch(supabaseClientProvider));
});

final favoriteBusinessesProvider = FutureProvider.autoDispose<List<Business>>(
  (ref) async {
    final authStatus = ref.watch(authStatusProvider);
    if (authStatus != AuthStatus.authenticated) return [];
    final userId = ref.read(authRepositoryProvider).currentUser?.id;
    if (userId == null) return [];
    return ref
        .watch(favoritesRepositoryProvider)
        .fetchFavoriteBusinesses(userId);
  },
);

/// Cheap heart-state across Discover results — separate from the full
/// favorites list so toggling one doesn't force-refetch business rows.
final favoriteBusinessIdsProvider = FutureProvider.autoDispose<Set<String>>((
  ref,
) async {
  final authStatus = ref.watch(authStatusProvider);
  if (authStatus != AuthStatus.authenticated) return {};
  final userId = ref.read(authRepositoryProvider).currentUser?.id;
  if (userId == null) return {};
  return ref
      .watch(favoritesRepositoryProvider)
      .fetchFavoriteBusinessIds(userId);
});
