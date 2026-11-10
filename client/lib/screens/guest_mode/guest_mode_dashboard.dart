import 'package:flutter/material.dart';

import '../../../services/database_helper.dart';
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

  // DYNAMIC STATE HOLDERS
  String _currentCommunityDisplay = 'Guest Mode';
  String _currentRegionDisplay = 'Adelaide, South Australia';

  @override
  void initState() {
    super.initState();
    _recoverLastActiveProfileEnvironment();
  }

  /// PERSISTENT ENVIRONMENT RECOVERY ENGINE
  /// Scans your SQLite database settings to preserve group identities across logouts
  Future<void> _recoverLastActiveProfileEnvironment() async {
    final String? savedCommunity =
        await DatabaseHelper.instance.getConfig('auth_community_name') ??
        await DatabaseHelper.instance.getConfig('community_name');

    if (mounted && savedCommunity != null && savedCommunity.trim().isNotEmpty) {
      setState(() {
        _currentCommunityDisplay = savedCommunity.trim();
        _currentRegionDisplay = 'Sector Cluster Area';
      });
    }
  }

  /// Extracts coordinates, falling back to Adelaide center if device cache is null
  LatLng _getSafeCoordinates() {
    final double? lat = DatabaseHelper.instance.cachedLat;
    final double? lng = DatabaseHelper.instance.cachedLng;

    if (lat != null && lng != null) {
      return LatLng(lat, lng);
    }
    return const LatLng(-34.7689, 138.6076);
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
    final LatLng safeLocation = _getSafeCoordinates();
    final double mapHeight = _bottomIndex == 0 ? 260.0 : 440.0;

    // Calculates total height of the fixed header section (Map + Titles + Padding)
    final double fixedHeaderHeight = mapHeight + 104.0;

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
                                dynamicCenter: safeLocation,
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

                  // FIXED DYNAMIC HEADER: Displays your persistent community name variables automatically
                  Text(
                    _currentCommunityDisplay,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Color(0xFF4DB6AC),
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          _currentRegionDisplay,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
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
