import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import 'household/household_dashboard.dart';
import '../screens/guest_mode/guest_mode_dashboard.dart'; 
// import 'leader/leader_dashboard.dart'; // 

class AppGatekeeper extends StatelessWidget {
  const AppGatekeeper({super.key});

  /// Evaluates persistent device configurations inside SQLite asynchronously
  Future<Widget> _determineInitialScreen() async {
    // Force the database initialization thread to complete 
    await DatabaseHelper.instance.database;

    // Fetch logged-in authentication context keys concurrently
    final String? householdId = await DatabaseHelper.instance.getConfig('auth_household_id');
    final String? leaderId = await DatabaseHelper.instance.getConfig('auth_leader_id');

    // ROUTING MATRIX LOGIC
    if (householdId != null && householdId.isNotEmpty) {
      print("GATEKEEPER ROUTING: Active Household Account ($householdId) detected.");
      return const HouseholdDashboard();
    }

    if (leaderId != null && leaderId.isNotEmpty) {
      print("GATEKEEPER ROUTING: Active Leader Account ($leaderId) detected.");
      // return const LeaderDashboard(); // Return your corresponding leader layout screen here
      return const HouseholdDashboard(); // Temporary fallback wrapper until file is implemented
    }

    // Serve pure anonymous Guest Mode canvas layout
    print("GATEKEEPER ROUTING: No local identity profiles active. Serving Guest Mode...");
    return const GuestModeDashboard(); // Make sure this widget points to your generic Guest screen container
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _determineInitialScreen(),
      builder: (context, snapshot) {
        // Renders a smooth, theme-matched loading background while the storage thread settles
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF14171A), // Matches your matte dark theme profile hex
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4DB6AC)),
              ),
            ),
          );
        }

        // Instantly mounts the target landing platform layout cleanly
        return snapshot.data ?? const GuestModeDashboard();
      },
    );
  }
}
