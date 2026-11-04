import 'package:flutter/material.dart';
import '../login_page.dart';
import '../../widgets/report_dialog.dart';
import '../../widgets/active_incidents_card.dart';
import '../../widgets/dark_plan_layout.dart';
import '../../widgets/community_leader/community_plan_editor.dart';

class LeaderDashboard extends StatefulWidget {
  const LeaderDashboard({super.key});
  @override
  State<LeaderDashboard> createState() => _LeaderDashboardState();
}

class _LeaderDashboardState extends State<LeaderDashboard> {
  int? _sideIndex;
  final _planDraft = CommunityPlanDraft();
  List<PlanSection> get _sections => [
    PlanSection('Notifications', 'Community notices and updates for linked households.', Icons.notifications_outlined),
    PlanSection('Community plan', 'Community evacuation arrangements.', Icons.description_outlined, content: CommunityPlanEditor(draft: _planDraft)),
    PlanSection('Household preparedness plan', 'Household preparedness summaries and completion status.', Icons.fact_check_outlined),
    PlanSection('Privacy & security', 'Privacy and security options will be available in a future release.', Icons.privacy_tip_outlined),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Community Leader Dashboard'), centerTitle: true),
    body: DarkPlanLayout(
      sections: _sections,
      selectedIndex: _sideIndex,
      onSelected: (index) => setState(() => _sideIndex = index),
      incidents: const ActiveIncidentsCard(),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: 0,
      onDestinationSelected: (index) {
        if (index == 0) {
          setState(() => _sideIndex = null);
        } else if (index == 1) {
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
