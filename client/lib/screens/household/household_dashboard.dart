import 'package:flutter/material.dart';
import '../../widgets/household/household_header.dart';
import '../../widgets/household/current_alert_card.dart';
import '../../widgets/household/household_status_card.dart';
import '../../widgets/household/preparedness_card.dart';
import '../../widgets/household/community_updates_card.dart';
import '../../widgets/active_incidents_card.dart';
import '../login_page.dart';

//import 'package:maplibre_gl/maplibre_gl.dart';

class HouseholdDashboard extends StatelessWidget {
  const HouseholdDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Household Dashboard'),
        centerTitle: true,
      ),
     body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const [
            HouseholdHeader(),

            SizedBox(height: 20),
            // Lists live cached database items natively
            ActiveIncidentsCard(),

            SizedBox(height: 16),
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
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist),
            label: 'Checklist',
          ),
          NavigationDestination(
            icon: Icon(Icons.report_outlined),
            selectedIcon: Icon(Icons.report),
            label: 'Report',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'Community Plan',
          ),
        ],
      ),
    );
  }
}
