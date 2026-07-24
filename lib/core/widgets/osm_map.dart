import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../theme/app_colors.dart';

/// OpenStreetMap tiles need no API key. A User-Agent identifying the app
/// is required by OSM's tile usage policy.
const String _osmUrlTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const String _osmUserAgent = 'com.shorisolutions.shorivo';

/// Fallback centre when no location is set yet (Barbados).
const LatLng kDefaultMapCenter = LatLng(13.1939, -59.5432);

/// Interactive map that lets the owner tap to drop/move the location pin.
class LocationPickerMap extends StatefulWidget {
  const LocationPickerMap({
    super.key,
    required this.selected,
    required this.onChanged,
    this.height = 220,
  });

  final LatLng? selected;
  final ValueChanged<LatLng> onChanged;
  final double height;

  @override
  State<LocationPickerMap> createState() => _LocationPickerMapState();
}

class _LocationPickerMapState extends State<LocationPickerMap> {
  final _controller = MapController();

  @override
  void didUpdateWidget(covariant LocationPickerMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Recentre when the selection changes from outside (e.g. after
    // "Use my current location").
    final sel = widget.selected;
    if (sel != null && sel != oldWidget.selected) {
      _controller.move(sel, 15);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sel = widget.selected;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: widget.height,
        child: FlutterMap(
          mapController: _controller,
          options: MapOptions(
            initialCenter: sel ?? kDefaultMapCenter,
            initialZoom: sel != null ? 15 : 11,
            onTap: (_, point) => widget.onChanged(point),
          ),
          children: [
            TileLayer(
              urlTemplate: _osmUrlTemplate,
              userAgentPackageName: _osmUserAgent,
            ),
            if (sel != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: sel,
                    width: 44,
                    height: 44,
                    alignment: Alignment.bottomCenter,
                    child: const Icon(
                      Icons.location_on,
                      size: 40,
                      color: AppColors.terracotta,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Read-only-ish map preview showing a single pin. Pan/zoom enabled,
/// rotation disabled. Used on the customer marketplace profile.
class MapPreview extends StatelessWidget {
  const MapPreview({super.key, required this.point, this.height = 180});

  final LatLng point;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        height: height,
        child: FlutterMap(
          options: MapOptions(
            initialCenter: point,
            initialZoom: 15,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: _osmUrlTemplate,
              userAgentPackageName: _osmUserAgent,
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: point,
                  width: 44,
                  height: 44,
                  alignment: Alignment.bottomCenter,
                  child: const Icon(
                    Icons.location_on,
                    size: 40,
                    color: AppColors.terracotta,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
