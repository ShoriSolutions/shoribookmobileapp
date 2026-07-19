import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../models/customer.dart';
import '../../../routing/route_paths.dart';
import '../application/clients_providers.dart';

/// V08 · Clients — searchable, filterable client list (All / Regulars /
/// New / Flagged) with a count line and tap-through to each profile.
class ClientsListScreen extends ConsumerWidget {
  const ClientsListScreen({super.key});

  static const _filters = [
    ('all', 'All'),
    ('regulars', 'Regulars'),
    ('new', 'New'),
    ('flagged', 'Flagged'),
  ];

  static const _avatarColors = [
    AppColors.sage,
    AppColors.terracotta,
    AppColors.sageDark,
    Color(0xFFB9A97F),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientsAsync = ref.watch(filteredClientsProvider);
    final allClients = ref.watch(clientsListProvider).valueOrNull ?? const [];
    final filter = ref.watch(clientFilterProvider);
    final regulars =
        allClients.where((c) => c.tags.contains('regular')).length;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Clients',
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: AppColors.ink)),
                  GestureDetector(
                    onTap: () => context.push(RoutePaths.clientNew),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                          color: AppColors.sage, shape: BoxShape.circle),
                      child: const Icon(Icons.add, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
              child: TextField(
                onChanged: (v) =>
                    ref.read(clientSearchQueryProvider.notifier).state = v,
                decoration: InputDecoration(
                  hintText: 'Search name or number',
                  prefixIcon: const Icon(Icons.search, color: AppColors.muted),
                  filled: true,
                  fillColor: AppColors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: const BorderSide(color: AppColors.parchment),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: const BorderSide(color: AppColors.parchment),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide:
                        const BorderSide(color: AppColors.sage, width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  for (final f in _filters) ...[
                    _FilterChip(
                      label: f.$2,
                      selected: filter == f.$1,
                      danger: f.$1 == 'flagged',
                      onTap: () =>
                          ref.read(clientFilterProvider.notifier).state = f.$1,
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
              child: Text('${allClients.length} clients · $regulars regulars',
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted)),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => ref.refresh(clientsListProvider.future),
                child: clientsAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (err, st) => ListView(children: [
                    const SizedBox(height: 80),
                    ErrorRetryView(
                      message: 'Could not load clients.',
                      onRetry: () => ref.invalidate(clientsListProvider),
                    ),
                  ]),
                  data: (clients) {
                    if (clients.isEmpty) {
                      return ListView(children: const [
                        SizedBox(height: 60),
                        EmptyState(
                          icon: '👤',
                          title: 'No clients yet',
                          message:
                              'Clients you add or who book with you show up here.',
                        ),
                      ]);
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                      itemCount: clients.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) => _ClientTile(
                        customer: clients[i],
                        color: _avatarColors[i % _avatarColors.length],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.danger = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final accent = danger ? AppColors.danger : AppColors.sage;
    final accentDeep = danger ? AppColors.danger : AppColors.sageDark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? (danger ? const Color(0xFFF7ECE9) : AppColors.sage)
              : AppColors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? accent : AppColors.parchment),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: selected
                    ? (danger ? accentDeep : Colors.white)
                    : (danger ? accentDeep : AppColors.muted))),
      ),
    );
  }
}

class _ClientTile extends StatelessWidget {
  final Customer customer;
  final Color color;

  const _ClientTile({required this.customer, required this.color});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push(RoutePaths.clientDetail(customer.id)),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.parchment),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: color,
                foregroundColor: color == const Color(0xFFB9A97F)
                    ? AppColors.ink
                    : Colors.white,
                child: Text(
                  customer.firstName.isNotEmpty
                      ? customer.firstName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(customer.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.ink)),
                    const SizedBox(height: 2),
                    Text(customer.phone,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.muted)),
                  ],
                ),
              ),
              if (customer.tags.contains('flagged'))
                _tag('Flagged', const Color(0xFFF7ECE9), AppColors.danger)
              else if (customer.tags.contains('new'))
                _tag('New', AppColors.closedBg, AppColors.closedText)
              else if (customer.tags.contains('regular'))
                _tag('Regular', AppColors.successBg, AppColors.successText),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tag(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label,
          style:
              TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}
