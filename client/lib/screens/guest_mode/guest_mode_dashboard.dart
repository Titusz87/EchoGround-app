import 'package:flutter/material.dart';
import '../../widgets/guest_mode/guest_mode_header.dart';
import '../../widgets/household/current_alert_card.dart';
import '../../widgets/household/household_status_card.dart';
import '../../widgets/household/preparedness_card.dart';
import '../../widgets/household/community_updates_card.dart';
import '../login_page.dart';

//import 'package:maplibre_gl/maplibre_gl.dart';

class GuestModeDashboard extends StatelessWidget {
  const GuestModeDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CountryReady.ai'),
        centerTitle: true,
      ),
     body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const [
            GuestModeHeader(),

            SizedBox(height: 20),
            /*

            CurrentAlertCard(),

            SizedBox(height: 16),

            HouseholdStatusCard(),

            SizedBox(height: 16),
            

            PreparednessCard(),

            SizedBox(height: 16),

            CommunityUpdatesCard(),
            */
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (index) {
    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const LoginPage(),
        ),
      );
    }
  },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.warning),
            label: 'Incidents',
          ),
          NavigationDestination(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
