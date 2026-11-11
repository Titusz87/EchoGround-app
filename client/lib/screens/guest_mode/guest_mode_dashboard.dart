import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../../services/database_helper.dart';
import '../../widgets/embedded_street_map.dart';
import '../../widgets/active_incidents_card.dart';
import '../login_page.dart';

import 'package:maplibre_gl/maplibre_gl.dart';

class GuestModeDashboard extends StatefulWidget {
  const GuestModeDashboard({super.key});

  @override
  State<GuestModeDashboard> createState() => _GuestModeDashboardState();
}

class _GuestModeDashboardState extends State<GuestModeDashboard> {
  int _bottomIndex = 0;
  final GlobalKey _mapKey = GlobalKey();

  static const _nativeLandKey = String.fromEnvironment('NATIVE_LAND_KEY');
  LatLng? _deviceLocation;
  String _locationLabel = 'Finding your location…';
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    _refreshLocation();
  }

  Future<void> _refreshLocation() async {
    if (_locating) return;
    setState(() {
      _locating = true;
      _locationLabel = 'Finding your location…';
    });
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _deviceLocation = null;
            _locationLabel = 'Location permission is off. Enable it and tap to retry.';
          });
        }
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 12),
        ),
      );
      if (!mounted) return;
      final coordinates = LatLng(position.latitude, position.longitude);
      setState(() {
        _deviceLocation = coordinates;
        _locationLabel = 'Finding the place name and First Nations region…';
      });
      final labels = await Future.wait([
        _lookupLocality(coordinates),
        _lookupTerritories(coordinates),
      ]);
      if (!mounted) return;
      final locality = labels[0];
      final territories = labels[1];
      setState(() {
        _locationLabel = [
          if (locality.isNotEmpty) locality,
          if (territories.isNotEmpty)
            territories
          else
            'First Nations region unavailable',
        ].join(' · ');
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _deviceLocation = null;
          _locationLabel = 'Location unavailable. Tap to retry.';
        });
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<String> _lookupLocality(LatLng point) async {
    try {
      final response = await http.get(Uri.https(
        'api.bigdatacloud.net',
        '/data/reverse-geocode-client',
        {
          'latitude': '${point.latitude}',
          'longitude': '${point.longitude}',
          'localityLanguage': 'en',
        },
      )).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return '';
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final city = data['city']?.toString().trim() ?? '';
      final locality = city.isNotEmpty
          ? city
          : data['locality']?.toString().trim() ?? '';
      final state = data['principalSubdivision']?.toString().trim() ?? '';
      return {locality, state}.where((value) => value.isNotEmpty).join(', ');
    } catch (_) {
      return '';
    }
  }

  Future<String> _lookupTerritories(LatLng point) async {
    if (_nativeLandKey.trim().isEmpty) return '';
    try {
      final response = await http.get(Uri.https(
        'native-land.ca',
        '/api/index.php',
        {
          'maps': 'territories',
          'position': '${point.latitude},${point.longitude}',
          'key': _nativeLandKey.trim(),
        },
      )).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return '';
      final payload = jsonDecode(response.body);
      final features = payload is Map ? payload['features'] : payload;
      if (features is! List) return '';
      final names = <String>{};
      for (final feature in features.whereType<Map>()) {
        final properties = feature['properties'];
        if (properties is! Map) continue;
        final name = (properties['Name'] ?? properties['name'])
            ?.toString().trim() ?? '';
        if (name.isNotEmpty) names.add(name);
      }
      return names.join(', ');
    } catch (_) {
      return '';
    }
  }

  // Loads the active incidents from local SQLite matching tracking layouts
  Future<List<Map<String, dynamic>>> _loadMapIncidents() async {
    try {
      return await DatabaseHelper.instance.fetchAllNotifications();
    } catch (_) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final double mapHeight = _bottomIndex == 0 ? 260.0 : 440.0;

    // Calculates total height of the fixed header section (Map + Titles + Padding)
    final double fixedHeaderHeight = mapHeight + 132.0;

    return Scaffold(
      backgroundColor: const Color(0xFF14171A),
      body: Stack(
        children: [
          // LAYER 1: The Independent Scrolling Component Panel (Built first so it sits behind)
          Positioned.fill(
            child: SingleChildScrollView(
              // Top padding ensures the cards start rendering exactly beneath your fixed header block
              padding: EdgeInsets.only(
                top: fixedHeaderHeight + 16.0,
                left: 16.0,
                right: 16.0,
                bottom: 24.0,
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [ActiveIncidentsCard()],
              ),
            ),
          ),

          // LAYER 2: The Fixed Header Section (Built second with solid background to hide items sliding under)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: fixedHeaderHeight,
            child: Container(
              color: const Color(
                0xFF14171A,
              ), // Matches your theme to hide background card overflow elements
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Fixed Aspect Map Window Frame
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: mapHeight,
                      maxHeight: mapHeight,
                    ),
                    child: ValueListenableBuilder<int>(
                      valueListenable: DatabaseHelper.instance.syncNotifier,
                      builder: (context, syncCount, child) {
                        return FutureBuilder<List<Map<String, dynamic>>>(
                          future: _loadMapIncidents(),
                          builder: (context, snapshot) {
                            final incidentList = snapshot.data ?? [];

                            return RepaintBoundary(
                              child: EmbeddedStreetMap(
                                key: _mapKey,
                                dynamicCenter: _deviceLocation,
                                incidentMarkers: incidentList,
                                initialZoom: 10.0,
                                height: mapHeight,
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    'Guest Mode',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: InkWell(
                      onTap: _locating ? null : _refreshLocation,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.location_on,
                              color: Color(0xFF4DB6AC), size: 16),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              _locationLabel,
                              textAlign: TextAlign.center,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Colors.white60, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return NavigationBar(
      selectedIndex: _bottomIndex > 1 ? 0 : _bottomIndex,
      onDestinationSelected: (index) {
        if (index == 2) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
          );
        } else {
          setState(() => _bottomIndex = index);
        }
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.map_outlined),
          selectedIcon: Icon(Icons.map),
          label: 'Map',
        ),
        NavigationDestination(
          icon: Icon(Icons.account_circle_outlined),
          selectedIcon: Icon(Icons.account_circle),
          label: 'Profile',
        ),
      ],
    );
  }
}
