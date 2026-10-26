import 'package:flutter/material.dart';
import '../../widgets/echoground_banner.dart';
import '../map_screen.dart';
import '../../widgets/active_incidents_card.dart';
import '../../widgets/community_leader/household_status_card.dart';
import '../../widgets/community_leader/community_alert_card.dart';
import '../../widgets/community_leader/community_tasks_card.dart';

class LeaderDashboard extends StatelessWidget {
  const LeaderDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EchoGround'),
        centerTitle: true,
      ),

      body: EchoGroundPageBody(
        children: const [
            EchoGroundBanner(),
            SizedBox(height: 20),
            ActiveIncidentsCard(),
            SizedBox(height: 16),

/*
            HouseholdStatusCard(),
            SizedBox(height: 16),

            CommunityAlertCard(),
            SizedBox(height: 16),

            CommunityTasksCard(),
      */
        ],
      ),

      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
         onDestinationSelected: (index) {
    if (index == 1) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const MapScreen(),
        ),
      );
    }
  },
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.warning),
            label: 'Incidents',
          ),
          NavigationDestination(
            icon: Icon(Icons.map),
            label: 'Map',
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