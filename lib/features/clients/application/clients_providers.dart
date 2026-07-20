import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../models/customer.dart';
import '../../business_context/application/active_business_provider.dart';
import '../data/clients_repository.dart';

final clientsRepositoryProvider = Provider<ClientsRepository>((ref) {
  return ClientsRepository(ref.watch(supabaseClientProvider));
});

final clientsListProvider = FutureProvider.autoDispose<List<Customer>>((
  ref,
) async {
  final membership = await ref.watch(activeMembershipProvider.future);
  if (membership == null) return [];
  return ref.watch(clientsRepositoryProvider).fetchAll(membership.business.id);
});

final clientSearchQueryProvider = StateProvider<String>((ref) => '');

/// Client list filter: 'all' | 'regulars' | 'new' | 'flagged'. The latter
/// three match the corresponding tag on the customer.
final clientFilterProvider = StateProvider<String>((ref) => 'all');

final filteredClientsProvider = Provider.autoDispose<AsyncValue<List<Customer>>>(
  (ref) {
    final query = ref.watch(clientSearchQueryProvider).trim().toLowerCase();
    final filter = ref.watch(clientFilterProvider);
    final clientsAsync = ref.watch(clientsListProvider);
    return clientsAsync.whenData((clients) {
      var list = clients;
      if (filter == 'blocked') {
        list = list.where((c) => c.isBlocked).toList();
      } else if (filter != 'all') {
        final tag = filter == 'regulars' ? 'regular' : filter;
        list = list.where((c) => c.tags.contains(tag)).toList();
      }
      if (query.isNotEmpty) {
        list = list
            .where((c) =>
                c.fullName.toLowerCase().contains(query) ||
                c.phone.toLowerCase().contains(query) ||
                (c.email ?? '').toLowerCase().contains(query))
            .toList();
      }
      return list;
    });
  },
);

class ClientDetailData {
  final Customer customer;
  final CustomerStats stats;
  final List<dynamic> history;

  const ClientDetailData({
    required this.customer,
    required this.stats,
    required this.history,
  });
}

final clientDetailProvider = FutureProvider.autoDispose
    .family<ClientDetailData, String>((ref, clientId) async {
      final repo = ref.watch(clientsRepositoryProvider);
      final results = await Future.wait([
        repo.fetchById(clientId),
        repo.fetchStats(clientId),
        repo.fetchHistory(clientId),
      ]);
      return ClientDetailData(
        customer: results[0] as Customer,
        stats: results[1] as CustomerStats,
        history: results[2] as List,
      );
    });
