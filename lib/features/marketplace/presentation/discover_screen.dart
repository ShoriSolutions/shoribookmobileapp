import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/location_service.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_retry_view.dart';
import '../../../models/business.dart';
import '../../../routing/route_paths.dart';
import '../../app_mode/application/app_mode_provider.dart';
import '../../auth/application/auth_providers.dart';
import '../../guest_prompt/presentation/guest_account_prompt.dart';
import '../../messaging/application/messaging_providers.dart';
import '../../favorites/presentation/widgets/favorite_button.dart';
import '../application/marketplace_providers.dart';
import 'widgets/category_visuals.dart';

/// C02 · Marketplace home — the app's centrepiece. Location + a big
/// question, one search field, then Featured (horizontal) and Near you
/// (list) drawn from live marketplace results.
class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  final _searchController = TextEditingController();
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    // Remind a guest with device-only bookings to make an account so they
    // don't lose them (once per 15 days; no-op otherwise).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) maybeShowGuestDataReminder(context, ref);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _toggleNearMe() async {
    if (ref.read(customerLocationProvider) != null) {
      ref.read(customerLocationProvider.notifier).state = null;
      return;
    }
    setState(() => _locating = true);
    try {
      final loc = await getCurrentLocation();
      ref.read(customerLocationProvider.notifier).state = loc;
    } catch (e) {
      if (mounted) {
        showAppSnackBar(context,
            message: AppException.from(e).message, isError: true);
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final resultsAsync = ref.watch(searchResultsProvider);
    final openNow = ref.watch(marketplaceOpenNowProvider).valueOrNull ?? const {};
    final selectedCategory = ref.watch(selectedCategoryProvider);
    final selectedTag = ref.watch(selectedTagProvider);
    final location = ref.watch(customerLocationProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(searchResultsProvider.future),
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _header(context, location != null)),
              SliverToBoxAdapter(child: _searchField()),
              SliverToBoxAdapter(child: _categoryRow(selectedCategory, location)),
              if (selectedTag != null)
                SliverToBoxAdapter(child: _activeTagBanner(selectedTag)),
              ...resultsAsync.when(
                loading: () => [
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ],
                error: (_, __) => [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: ErrorRetryView(
                      message: 'Could not load businesses.',
                      onRetry: () => ref.invalidate(searchResultsProvider),
                    ),
                  ),
                ],
                data: (businesses) =>
                    _results(context, businesses, openNow, location),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────
  Widget _header(BuildContext context, bool nearMeOn) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _locating ? null : _toggleNearMe,
                  borderRadius: BorderRadius.circular(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your area',
                          style: TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 1),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.location_on_outlined,
                              size: 18, color: AppColors.sageDark),
                          const SizedBox(width: 4),
                          Text(
                            nearMeOn ? 'Near you' : 'Bridgetown',
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: AppColors.ink),
                          ),
                          const Icon(Icons.keyboard_arrow_down,
                              size: 20, color: AppColors.ink),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Messaging is for signed-in customers only (not guests).
              if (ref.watch(authStatusProvider) == AuthStatus.authenticated) ...[
                _CircleIconButton(
                  icon: Icons.forum_outlined,
                  background: AppColors.sageLight,
                  foreground: AppColors.sageDark,
                  badge: ref.watch(unreadConversationsProvider),
                  onTap: () => context.push(RoutePaths.messages),
                ),
                const SizedBox(width: 10),
              ],
              _CircleIconButton(
                icon: Icons.person_outline,
                background: AppColors.sageLight,
                foreground: AppColors.sageDark,
                avatarUrl: ref.watch(myProfileProvider).valueOrNull?.avatarUrl,
                onTap: () => context.go(RoutePaths.account),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Who do you want\nto book with?',
            style: TextStyle(
              fontSize: 28,
              height: 1.12,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchField() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => ref.read(searchQueryProvider.notifier).state = v,
        decoration: InputDecoration(
          hintText: 'Search businesses, services, areas',
          prefixIcon: const Icon(Icons.search, color: AppColors.muted),
          filled: true,
          fillColor: AppColors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            borderSide: const BorderSide(color: AppColors.sage, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _activeTagBanner(String tag) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Row(
        children: [
          const Text('Filtered by tag',
              style: TextStyle(fontSize: 12.5, color: AppColors.muted)),
          const SizedBox(width: 8),
          InkWell(
            onTap: () =>
                ref.read(selectedTagProvider.notifier).state = null,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
              decoration: BoxDecoration(
                color: AppColors.sageLight,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.sageTintBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(tag,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.sageDark)),
                  const SizedBox(width: 4),
                  const Icon(Icons.close, size: 15, color: AppColors.sageDark),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryRow(String? selectedCategory,
      ({double lat, double lng})? location) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          children: [
            _CategoryChip(
              label: _locating ? 'Locating…' : 'Near me',
              icon: Icons.near_me_outlined,
              selected: location != null,
              onTap: _locating ? null : _toggleNearMe,
            ),
            const SizedBox(width: 8),
            for (final c in BusinessCategory.all) ...[
              _CategoryChip(
                label: _shortLabel(c),
                icon: CategoryVisual.of(c.value).icon,
                selected: selectedCategory == c.value,
                onTap: () => ref.read(selectedCategoryProvider.notifier).state =
                    selectedCategory == c.value ? null : c.value,
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }

  // ── Results (Featured + Near you) ──────────────────────────────────────
  List<Widget> _results(
    BuildContext context,
    List<Business> businesses,
    Map<String, bool> openNow,
    ({double lat, double lng})? location,
  ) {
    if (businesses.isEmpty) {
      return const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(top: 60),
            child: EmptyState(
              icon: '🔍',
              title: 'No businesses found',
              message: 'Try a different search or category.',
            ),
          ),
        ),
      ];
    }

    // Distance (metres) to each business when "Near me" is on.
    final distances = <String, double>{};
    if (location != null) {
      for (final b in businesses) {
        if (b.latitude != null && b.longitude != null) {
          distances[b.id] = Geolocator.distanceBetween(
              location.lat, location.lng, b.latitude!, b.longitude!);
        }
      }
    }

    final featured =
        businesses.where((b) => b.badges.contains('featured') || b.featuredRequested).toList();
    final featuredIds = featured.map((b) => b.id).toSet();
    var nearYou =
        businesses.where((b) => !featuredIds.contains(b.id)).toList();
    if (location != null) {
      nearYou.sort((a, b) {
        final da = distances[a.id];
        final db = distances[b.id];
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      });
    }

    return [
      if (featured.isNotEmpty) ...[
        SliverToBoxAdapter(child: _sectionHeader('Featured')),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 268,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              itemCount: featured.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (c, i) => _FeaturedCard(
                business: featured[i],
                openNow: openNow[featured[i].id],
                distanceMeters: distances[featured[i].id],
              ),
            ),
          ),
        ),
      ],
      if (nearYou.isNotEmpty) ...[
        SliverToBoxAdapter(child: _sectionHeader('Near you')),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          sliver: SliverList.separated(
            itemCount: nearYou.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (c, i) => _NearYouRow(
              business: nearYou[i],
              openNow: openNow[nearYou[i].id],
              distanceMeters: distances[nearYou[i].id],
            ),
          ),
        ),
      ],
    ];
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink)),
          Text('See all',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.sageDark)),
        ],
      ),
    );
  }

  String _shortLabel(BusinessCategory c) {
    const short = {
      'barber': 'Barbers',
      'nail_tech': 'Nails',
      'lash_artist': 'Lashes',
      'brow_artist': 'Brows',
      'esthetician': 'Estheticians',
      'hair_stylist': 'Hair',
      'personal_trainer': 'Trainers',
      'other': 'More',
    };
    return short[c.value] ?? c.label;
  }
}

// ── Shared status / meta chips ───────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.openNow});
  final bool openNow;

  @override
  Widget build(BuildContext context) {
    return _Pill(
      label: openNow ? 'Open now' : 'Closed',
      bg: openNow ? AppColors.successBg : AppColors.closedBg,
      fg: openNow ? AppColors.successText : AppColors.closedText,
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.bg, required this.fg});
  final String label;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

/// Tappable tag chips shown on Discover cards. Tapping one filters the whole
/// marketplace by that tag (via [selectedTagProvider]).
class _TagChips extends ConsumerWidget {
  const _TagChips({required this.tags, this.max = 3});
  final List<String> tags;
  final int max;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shown = tags.take(max).toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final t in shown)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => ref.read(selectedTagProvider.notifier).state = t,
            child: _Pill(label: t, bg: AppColors.sageLight, fg: AppColors.sageDark),
          ),
      ],
    );
  }
}

/// The gradient cover with a centred white category line icon, shared by
/// featured cards and near-you rows. Uses the real cover photo when set.
class _CategoryCover extends StatelessWidget {
  const _CategoryCover({
    required this.business,
    required this.borderRadius,
    this.iconSize = 40,
  });

  final Business business;
  final BorderRadius borderRadius;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final visual = CategoryVisual.of(business.category);
    return ClipRRect(
      borderRadius: borderRadius,
      child: business.coverImageUrl != null
          ? CachedNetworkImage(
              imageUrl: business.coverImageUrl!,
              fit: BoxFit.cover,
              errorWidget: (c, u, e) => _gradient(visual),
            )
          : _gradient(visual),
    );
  }

  Widget _gradient(CategoryVisual visual) {
    return Container(
      decoration: BoxDecoration(gradient: visual.gradient),
      alignment: Alignment.center,
      child: Icon(visual.icon, color: Colors.white, size: iconSize),
    );
  }
}

class _FeaturedCard extends StatelessWidget {
  const _FeaturedCard({
    required this.business,
    required this.openNow,
    required this.distanceMeters,
  });

  final Business business;
  final bool? openNow;
  final double? distanceMeters;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(RoutePaths.businessProfile(business.slug)),
      child: Container(
        width: 236,
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.parchment),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0D1E1B16), blurRadius: 18, offset: Offset(0, 6)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SizedBox(
                  height: 126,
                  width: double.infinity,
                  child: _CategoryCover(
                    business: business,
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(18)),
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.star, size: 13, color: Colors.white),
                        SizedBox(width: 3),
                        Text('Featured',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ],
                    ),
                  ),
                ),
                Positioned(
                    top: 8, right: 8, child: FavoriteButton(business: business)),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(business.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink)),
                  const SizedBox(height: 2),
                  Text(
                    _subtitle(business),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(fontSize: 12.5, color: AppColors.muted),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (openNow != null) ...[
                        _StatusChip(openNow: openNow!),
                        const SizedBox(width: 6),
                      ],
                      if (distanceMeters != null)
                        _Pill(
                          label: formatDistance(distanceMeters!),
                          bg: AppColors.fieldMuted,
                          fg: AppColors.muted,
                        ),
                    ],
                  ),
                  if (business.tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _TagChips(tags: business.tags, max: 2),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NearYouRow extends StatelessWidget {
  const _NearYouRow({
    required this.business,
    required this.openNow,
    required this.distanceMeters,
  });

  final Business business;
  final bool? openNow;
  final double? distanceMeters;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(RoutePaths.businessProfile(business.slug)),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.parchment),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 78,
              height: 78,
              child: _CategoryCover(
                business: business,
                borderRadius: BorderRadius.circular(12),
                iconSize: 30,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(business.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink)),
                  const SizedBox(height: 2),
                  Text(
                    _subtitle(business),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(fontSize: 12.5, color: AppColors.muted),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (openNow != null) ...[
                        _StatusChip(openNow: openNow!),
                        const SizedBox(width: 6),
                      ],
                      if (distanceMeters != null)
                        _Pill(
                          label: formatDistance(distanceMeters!),
                          bg: AppColors.fieldMuted,
                          fg: AppColors.muted,
                        ),
                    ],
                  ),
                  if (business.tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _TagChips(tags: business.tags, max: 3),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.faint),
          ],
        ),
      ),
    );
  }
}

/// "Nail tech · Holetown" style subtitle from category + area.
String _subtitle(Business b) {
  return [
    if (b.category != null) BusinessCategory.labelFor(b.category).split(' / ').first,
    b.address,
  ].where((s) => s != null && s.trim().isNotEmpty).join(' · ');
}

// ── Small buttons ────────────────────────────────────────────────────────

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
    this.badge = 0,
    this.avatarUrl,
  });

  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;
  final int badge;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final hasAvatar = avatarUrl != null && avatarUrl!.isNotEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 44,
            height: 44,
            clipBehavior: hasAvatar ? Clip.antiAlias : Clip.none,
            decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.sageTintBorder),
            ),
            child: hasAvatar
                ? CachedNetworkImage(
                    imageUrl: avatarUrl!,
                    fit: BoxFit.cover,
                    width: 44,
                    height: 44,
                    errorWidget: (_, __, ___) =>
                        Icon(icon, size: 22, color: foreground),
                  )
                : Icon(icon, size: 22, color: foreground),
          ),
          if (badge > 0)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                constraints: const BoxConstraints(minWidth: 18),
                decoration: BoxDecoration(
                  color: AppColors.terracotta,
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.cream, width: 1.5),
                ),
                child: Text(
                  badge > 9 ? '9+' : '$badge',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.sageLight : AppColors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: selected ? AppColors.sage : AppColors.parchment),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: selected ? AppColors.sageDark : AppColors.muted),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? AppColors.sageDark : AppColors.muted)),
          ],
        ),
      ),
    );
  }
}
