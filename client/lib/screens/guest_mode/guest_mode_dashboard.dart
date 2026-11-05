import 'package:flutter/material.dart';
//import '../../widgets/guest_mode/guest_mode_header.dart';
import '../../widgets/dynamic_dashboard_header.dart';
import '../../widgets/household/current_alert_card.dart';
import '../../widgets/household/household_status_card.dart';
import '../../widgets/household/preparedness_card.dart';
import '../../widgets/household/community_updates_card.dart';
import '../../widgets/active_incidents_card.dart';
import '../login_page.dart';
import '../../widgets/report_dialog.dart';

//import 'package:maplibre_gl/maplibre_gl.dart';

class GuestModeDashboard extends StatelessWidget {
  const GuestModeDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Guest Mode'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: const [
            DynamicDashboardHeader(),

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
          if (index == 1) {
            showReportDialog(context);
          } else if (index == 2) {
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
            icon: Icon(Icons.crisis_alert_outlined),
            selectedIcon: Icon(Icons.crisis_alert),
            label: 'Incidents',
          ),
          NavigationDestination(
            icon: Icon(Icons.report_outlined, color: Colors.redAccent, size: 34),
            selectedIcon: Icon(Icons.report, color: Colors.redAccent, size: 34),
            label: 'Report',
          ),
          // FIXED: Replaced "Contacts" layout destination item properties with "Profile"
          NavigationDestination(
            icon: Icon(Icons.account_circle_outlined),
            selectedIcon: Icon(Icons.account_circle),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

