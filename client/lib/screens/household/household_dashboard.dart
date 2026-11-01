import 'package:flutter/material.dart';
<<<<<<< HEAD

import 'household_plan_page.dart';
=======
import '../../widgets/echoground_banner.dart';
>>>>>>> origin/feature/stephen
import '../../widgets/household/household_header.dart';
import '../../widgets/household/current_alert_card.dart';
import '../../widgets/household/household_status_card.dart';
import '../../widgets/household/preparedness_card.dart';
import '../../widgets/household/community_updates_card.dart';
import '../login_page.dart';

//import 'package:maplibre_gl/maplibre_gl.dart';

class HouseholdDashboard extends StatelessWidget {
  const HouseholdDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
<<<<<<< HEAD
        title: const Text('Household Dashboard'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
=======
        title: const Text('EchoGround'),
        centerTitle: true,
      ),
     body: EchoGroundPageBody(
        children: const [
>>>>>>> origin/feature/stephen
            HouseholdHeader(),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.checklist_outlined),
              label: const Text('Open my household plan'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HouseholdPlanPage()),
              ),
            ),

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
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (index) {
          if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const LoginPage()),
            );
          }
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.warning), label: 'Incidents'),
          NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
