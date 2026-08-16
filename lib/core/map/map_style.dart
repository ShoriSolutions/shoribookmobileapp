import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';

import '../env/env.dart';

export 'package:vector_map_tiles/vector_map_tiles.dart' show Style;

/// MapLibre vector map styling for the app, rendered inside flutter_map via
/// vector_map_tiles. The MapTiler style is loaded once and cached; every map
/// surface (location picker, profile preview, marketplace search) shares it.
///
/// If no MAPTILER_KEY is configured the loader returns null and callers fall
/// back to raster OpenStreetMap tiles, so the app still renders a map in dev.

/// MapTiler style. "streets-v2" is a clean, legible street style; swap the
/// slug (e.g. "basic-v2", "bright-v2") to restyle every map at once.
const String _maptilerStyleUri =
    'https://api.maptiler.com/maps/streets-v2/style.json?key={key}';

// Raster fallback (dev only — OSM's public tiles aren't for production use).
const String kOsmRasterUrl = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
const String kOsmUserAgent = 'com.shorisolutions.shorivo';

Future<Style?>? _cachedStyle;

/// Loads (and caches) the MapLibre vector style. Returns null when no MapTiler
/// key is set or the style can't be fetched — callers then use raster tiles.
Future<Style?> loadMapStyle() => _cachedStyle ??= _readStyle();

Future<Style?> _readStyle() async {
  if (!Env.hasMapTiler) return null;
  try {
    return await StyleReader(
      uri: _maptilerStyleUri,
      apiKey: Env.maptilerKey,
    ).read();
  } catch (_) {
    return null; // fall back to raster
  }
}

/// The base tile layer for a [FlutterMap]: MapLibre vector tiles when a style
/// is available, otherwise raster OSM. Attribution is added separately.
Widget mapBaseLayer(Style? style) {
  if (style != null) {
    return VectorTileLayer(
      theme: style.theme,
      sprites: style.sprites,
      tileProviders: style.providers,
      maximumZoom: 18,
    );
  }
  return TileLayer(
    urlTemplate: kOsmRasterUrl,
    userAgentPackageName: kOsmUserAgent,
  );
}

/// Small attribution required by MapTiler / OSM. Place as a [FlutterMap] child.
Widget mapAttribution(Style? style) => RichAttributionWidget(
      alignment: AttributionAlignment.bottomRight,
      attributions: [
        if (style != null)
          const TextSourceAttribution('© MapTiler', prependCopyright: false),
        const TextSourceAttribution('© OpenStreetMap contributors',
            prependCopyright: false),
      ],
    );
