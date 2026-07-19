import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/location_service.dart';
import '../../../core/widgets/app_snackbar.dart';
import '../../../core/widgets/osm_map.dart';
import '../../../models/business.dart';
import '../../../routing/route_paths.dart';
import '../application/marketplace_providers.dart';
import 'widgets/category_visuals.dart';

enum _SortBy { nearest, name }

/// C03 · Search & map — the Search tab. Results on a map with teardrop
/// pins (active pin larger, in sage), a recenter button and a peeking
/// result card, or a plain list. One-tap List/Map toggle.
class SearchMapScreen extends ConsumerStatefulWidget {
  const SearchMapScreen({super.key});

  @override
  ConsumerState<SearchMapScreen> createState() => _SearchMapScreenState();
}

class _SearchMapScreenState extends ConsumerState<SearchMapScreen> {
  final _searchController = TextEditingController();
  final _mapController = MapController();
  bool _mapView = true;
  bool _openNowOnly = false;
  _SortBy _sort = _SortBy.nearest;
  bool _locating = false;
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _searchController.text = ref.read(searchQueryProvider);
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
      _mapController.move(LatLng(loc.lat, loc.lng), 14);
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
    final location = ref.watch(customerLocationProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _searchBar(),
            _filterRow(location),
            const SizedBox(height: 10),
            _toggle(),
            const SizedBox(height: 8),
            Expanded(
              child: resultsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (_, __) =>
                    const Center(child: Text('Could not load results.')),
                data: (all) {
                  final list = _apply(all, openNow, location);
                  return _mapView
                      ? _mapBody(list, openNow, location)
                      : _listBody(list, openNow, location);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Business> _apply(
    List<Business> all,
    Map<String, bool> openNow,
    ({double lat, double lng})? location,
  ) {
    var list = [...all];
    if (_openNowOnly) {
      list = list.where((b) => openNow[b.id] == true).toList();
    }
    if (_sort == _SortBy.name) {
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else if (location != null) {
      double? d(Business b) => (b.latitude != null && b.longitude != null)
          ? Geolocator.distanceBetween(
              location.lat, location.lng, b.latitude!, b.longitude!)
          : null;
      list.sort((a, b) {
        final da = d(a), db = d(b);
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      });
    }
    return list;
  }

  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: AppColors.ink),
            onPressed: () =>
                context.canPop() ? context.pop() : context.go(RoutePaths.discover),
          ),
          Expanded(
            child: TextField(
              controller: _searchController,
              onChanged: (v) =>
                  ref.read(searchQueryProvider.notifier).state = v,
              decoration: InputDecoration(
                hintText: 'Search businesses, services, areas',
                prefixIcon:
                    const Icon(Icons.search, color: AppColors.sageDark),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.cancel,
                            size: 18, color: AppColors.faint),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(searchQueryProvider.notifier).state = '';
                          setState(() {});
                        },
                      ),
                filled: true,
                fillColor: AppColors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
          ),
        ],
      ),
    );
  }

  Widget _filterRow(({double lat, double lng})? location) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: SizedBox(
        height: 38,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            _chip(
              label: 'Open now',
              selected: _openNowOnly,
              onTap: () => setState(() => _openNowOnly = !_openNowOnly),
            ),
            const SizedBox(width: 8),
            _chip(
              label: _locating ? 'Locating…' : 'Near me',
              selected: location != null,
              onTap: _locating ? null : _toggleNearMe,
            ),
            const SizedBox(width: 8),
            _chip(
              label: _sort == _SortBy.nearest ? 'Sort · Nearest' : 'Sort · Name',
              selected: false,
              trailing: Icons.keyboard_arrow_down,
              onTap: _pickSort,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickSort() async {
    final choice = await showModalBottomSheet<_SortBy>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('Nearest first'),
              trailing: _sort == _SortBy.nearest
                  ? const Icon(Icons.check, color: AppColors.sage)
                  : null,
              onTap: () => Navigator.pop(ctx, _SortBy.nearest),
            ),
            ListTile(
              title: const Text('Name (A–Z)'),
              trailing: _sort == _SortBy.name
                  ? const Icon(Icons.check, color: AppColors.sage)
                  : null,
              onTap: () => Navigator.pop(ctx, _SortBy.name),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice != null) setState(() => _sort = choice);
  }

  Widget _toggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 44,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.parchment,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            _toggleHalf('List', !_mapView, () => setState(() => _mapView = false)),
            _toggleHalf('Map', _mapView, () => setState(() => _mapView = true)),
          ],
        ),
      ),
    );
  }

  Widget _toggleHalf(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active ? AppColors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: active ? AppColors.ink : AppColors.muted)),
        ),
      ),
    );
  }

  // ── Map body ────────────────────────────────────────────────────────
  Widget _mapBody(List<Business> list, Map<String, bool> openNow,
      ({double lat, double lng})? location) {
    final withCoords =
        list.where((b) => b.latitude != null && b.longitude != null).toList();
    final selected = _selectedId == null
        ? (withCoords.isNotEmpty ? withCoords.first : null)
        : withCoords.where((b) => b.id == _selectedId).firstOrNull;
    final center = selected != null
        ? LatLng(selected.latitude!, selected.longitude!)
        : (location != null
            ? LatLng(location.lat, location.lng)
            : kDefaultMapCenter);

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: center,
            initialZoom: 13,
            interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.shorisolutions.shoribook',
            ),
            MarkerLayer(
              markers: [
                for (final b in withCoords)
                  Marker(
                    point: LatLng(b.latitude!, b.longitude!),
                    width: b.id == selected?.id ? 52 : 40,
                    height: b.id == selected?.id ? 52 : 40,
                    alignment: Alignment.bottomCenter,
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedId = b.id),
                      child: _Pin(
                        visual: CategoryVisual.of(b.category),
                        active: b.id == selected?.id,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
        Positioned(
          top: 12,
          right: 12,
          child: _recenterButton(location),
        ),
        if (selected != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: _peekCard(selected, openNow[selected.id]),
          ),
      ],
    );
  }

  Widget _recenterButton(({double lat, double lng})? location) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 2,
      child: InkWell(
        onTap: _locating ? null : _toggleNearMe,
        borderRadius: BorderRadius.circular(12),
        child: const SizedBox(
          width: 48,
          height: 48,
          child: Icon(Icons.my_location, color: AppColors.sageDark),
        ),
      ),
    );
  }

  Widget _peekCard(Business b, bool? open) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 6,
      shadowColor: Colors.black26,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            SizedBox(
              width: 66,
              height: 66,
              child: _cover(b),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(b.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink)),
                  const SizedBox(height: 1),
                  Text(_subtitle(b),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.muted)),
                  const SizedBox(height: 6),
                  if (open != null)
                    _statusChip(open),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              height: 40,
              child: ElevatedButton(
                onPressed: () =>
                    context.push(RoutePaths.businessProfile(b.slug)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                ),
                child: const Text('Book',
                    style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── List body ───────────────────────────────────────────────────────
  Widget _listBody(List<Business> list, Map<String, bool> openNow,
      ({double lat, double lng})? location) {
    if (list.isEmpty) {
      return const Center(
        child: Text('No results — try a different search.',
            style: TextStyle(color: AppColors.muted)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (c, i) {
        final b = list[i];
        final dist = (location != null &&
                b.latitude != null &&
                b.longitude != null)
            ? Geolocator.distanceBetween(
                location.lat, location.lng, b.latitude!, b.longitude!)
            : null;
        return GestureDetector(
          onTap: () => context.push(RoutePaths.businessProfile(b.slug)),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.parchment),
            ),
            child: Row(
              children: [
                SizedBox(width: 66, height: 66, child: _cover(b)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(b.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink)),
                      const SizedBox(height: 2),
                      Text(_subtitle(b),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12.5, color: AppColors.muted)),
                      const SizedBox(height: 6),
                      Row(children: [
                        if (openNow[b.id] != null) _statusChip(openNow[b.id]!),
                        if (dist != null) ...[
                          const SizedBox(width: 6),
                          Text(formatDistance(dist),
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.muted)),
                        ],
                      ]),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.faint),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _cover(Business b) {
    final visual = CategoryVisual.of(b.category);
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(gradient: visual.gradient),
        alignment: Alignment.center,
        child: Icon(visual.icon, color: Colors.white, size: 26),
      ),
    );
  }

  Widget _statusChip(bool open) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: open ? AppColors.successBg : AppColors.closedBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(open ? 'Open now' : 'Closed',
          style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: open ? AppColors.successText : AppColors.closedText)),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback? onTap,
    IconData? trailing,
  }) {
    return GestureDetector(
      onTap: onTap,
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
            Text(label,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? AppColors.sageDark : AppColors.muted)),
            if (trailing != null)
              Icon(trailing, size: 16, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

String _subtitle(Business b) {
  return [
    if (b.category != null)
      BusinessCategory.labelFor(b.category).split(' / ').first,
    b.address,
  ].where((s) => s != null && s.trim().isNotEmpty).join(' · ');
}

class _Pin extends StatelessWidget {
  const _Pin({required this.visual, required this.active});
  final CategoryVisual visual;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.sage : AppColors.terracotta;
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Icon(Icons.location_on, size: active ? 52 : 40, color: color),
        Positioned(
          top: active ? 9 : 7,
          child: Icon(visual.icon,
              size: active ? 18 : 14, color: Colors.white),
        ),
      ],
    );
  }
}
