import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

/// Map style providers. All of these need no API key and no credit card.
/// Swap the one used in [EmbeddedStreetMap._styleUrl] to change providers.
class MapStyles {
  MapStyles._();

  /// Dark theme, no key. Free for non-commercial use
  /// (commercial apps need a CARTO license).
  static const String cartoDark =
      'https://basemaps.cartocdn.com/gl/dark-matter-gl-style/style.json';

  /// No key, commercial use allowed. Light-ish styles only
  /// (liberty, bright, positron).
  static const String openFreeMapLiberty =
      'https://tiles.openfreemap.org/styles/liberty';

  static const String openFreeMapPositron =
      'https://tiles.openfreemap.org/styles/positron';
}

class EmbeddedStreetMap extends StatefulWidget {
  final double height;
  final LatLng? dynamicCenter;
  final double initialZoom;

  final List<Map<String, dynamic>> incidentMarkers;

  const EmbeddedStreetMap({
    super.key,
    this.height = 260.0,
    this.dynamicCenter,
    this.initialZoom = 12.0, // Regional 5-10km view
    this.incidentMarkers = const [],
  });

  @override
  State<EmbeddedStreetMap> createState() => _EmbeddedStreetMapState();
}

class _EmbeddedStreetMapState extends State<EmbeddedStreetMap> {
  static const String _styleUrl = MapStyles.cartoDark;

  MapLibreMapController? _mapController;
  Circle? _locationDot;
  final List<Circle> _activeIncidentCircles =
      []; // Tracks drew incident markers to prevent screen leaks
  bool _styleLoaded = false;

  @override
  void didUpdateWidget(covariant EmbeddedStreetMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newCenter = widget.dynamicCenter;
    if (newCenter != null && newCenter != oldWidget.dynamicCenter) {
      _mapController?.animateCamera(CameraUpdate.newLatLng(newCenter));
      _updateLocationDot(newCenter);
    }
    // 🎯 RE-TRIGGER LOOP: Automatically updates incident points when database changes
    if (_styleLoaded && widget.incidentMarkers != oldWidget.incidentMarkers) {
      _drawIncidentMarkers();
    }
  }

  Future<void> _updateLocationDot(LatLng position) async {
    final controller = _mapController;
    if (controller == null || !_styleLoaded) return;

    try {
      if (_locationDot == null) {
        _locationDot = await controller.addCircle(
          CircleOptions(
            geometry: position,
            circleRadius: 8,
            circleColor: '#4DB6AC',
            circleStrokeColor: '#FFFFFF',
            circleStrokeWidth: 2,
          ),
        );
      } else {
        await controller.updateCircle(
          _locationDot!,
          CircleOptions(geometry: position),
        );
      }
    } catch (e) {
      debugPrint('Could not draw location marker: $e');
    }
  }

  // NEW INCIDENT DRAW ENGINE: Loops database items and paints orange alert bounds
  Future<void> _drawIncidentMarkers() async {
    final controller = _mapController;
    if (controller == null || !_styleLoaded) return;

    try {
      // 1. Wipe out any older circles from the screen canvas
      for (final circle in _activeIncidentCircles) {
        await controller.removeCircle(circle);
      }
      _activeIncidentCircles.clear();

      // 2. Loop active records and draw them
      for (final incident in widget.incidentMarkers) {
        final double? lat = incident['latitude'] is num
            ? (incident['latitude'] as num).toDouble()
            : double.tryParse(incident['latitude']?.toString() ?? '');
        final double? lng = incident['longitude'] is num
            ? (incident['longitude'] as num).toDouble()
            : double.tryParse(incident['longitude']?.toString() ?? '');

        if (lat != null && lng != null) {
          final circle = await controller.addCircle(
            CircleOptions(
              geometry: LatLng(lat, lng),
              circleRadius: 10,
              circleColor: '#FF9800', // Warning vibrant orange color matching your UI theme
              circleStrokeColor: '#14171A',
              circleStrokeWidth: 1.5,
              circleOpacity: 0.85,
            ),
          );
          _activeIncidentCircles.add(circle);
        }
      }
      debugPrint(
        'MAP ENGINE: Successfully rendered ${_activeIncidentCircles.length} incident markers on style map.',
      );
    } catch (e) {
      debugPrint('Error placing incident markers: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final center = widget.dynamicCenter;

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: center == null
          ? _buildGlobePlaceholder()
          : MapLibreMap(
              initialCameraPosition: CameraPosition(
                target: center,
                zoom: widget.initialZoom,
              ),
              styleString: _styleUrl,
              onMapCreated: (MapLibreMapController controller) {
                _mapController = controller;
              },
              onStyleLoadedCallback: () {
                _styleLoaded = true;
                debugPrint('Map style loaded.');
                final current = widget.dynamicCenter;
                if (current != null) _updateLocationDot(current);
                _drawIncidentMarkers(); // Initial draw step call
              },
              myLocationEnabled: false,
              trackCameraPosition: true,
              compassEnabled: false,
              attributionButtonPosition: AttributionButtonPosition.bottomRight,
            ),
    );
  }

  Widget _buildGlobePlaceholder() {
    return Container(
      color: const Color(0xFF1E2225),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.public_rounded,
            size: 54,
            color: const Color(0xFF4DB6AC).withOpacity(0.65),
          ),
          const SizedBox(height: 16),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4DB6AC)),
                ),
              ),
              SizedBox(width: 10),
              Text(
                'Retrieving device position...',
                style: TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
