import 'package:flutter/material.dart';

import '../../services/database_helper.dart';
import '../../widgets/embedded_street_map.dart';
import '../../widgets/dynamic_dashboard_header.dart';
import '../login_page.dart';
import '../../widgets/report_dialog.dart';
import '../../widgets/active_incidents_card.dart';

import 'package:maplibre_gl/maplibre_gl.dart';

class GuestModeDashboard extends StatefulWidget {
  const GuestModeDashboard({super.key});

  @override
  State<GuestModeDashboard> createState() => _GuestModeDashboardState();
}

class _GuestModeDashboardState extends State<GuestModeDashboard> {
  /// Extracts active memory values populated by tracking service loops
  LatLng? _getLiveCacheCoordinates() {
    final double? lat = DatabaseHelper.instance.cachedLat;
    final double? lng = DatabaseHelper.instance.cachedLng;

    if (lat != null && lng != null) {
      return LatLng(lat, lng);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF14171A),
      appBar: AppBar(
        title: const Text(''),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      // Listens directly to syncNotifier updates to handle the async loading gap seamlessly
      body: ValueListenableBuilder<int>(
        valueListenable: DatabaseHelper.instance.syncNotifier,
        builder: (context, syncCount, child) {
          final LatLng? liveLocation = _getLiveCacheCoordinates();

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Guest Mode',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),

                const DynamicDashboardHeader(locationOnly: true),
                const SizedBox(height: 24),

                const ActiveIncidentsCard(),
                const SizedBox(height: 16),

                EmbeddedStreetMap(dynamicCenter: liveLocation),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return NavigationBar(
      selectedIndex: 0,
      onDestinationSelected: (index) {
        if (index == 1) {
          showReportDialog(context);
        } else if (index == 2) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
          );
        }
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.report_outlined, color: Colors.redAccent),
          selectedIcon: Icon(Icons.report, color: Colors.redAccent),
          label: 'Report',
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
