import 'package:flutter/material.dart';
import '../map_screen.dart';
import '../../widgets/active_incidents_card.dart';
import '../../widgets/dark_plan_layout.dart';

class LeaderDashboard extends StatefulWidget {
  const LeaderDashboard({super.key});
  @override
  State<LeaderDashboard> createState() => _LeaderDashboardState();
}

class _LeaderDashboardState extends State<LeaderDashboard> {
  int? _sideIndex;
  static const _sections = [
    PlanSection('Notification page', 'Community notices and updates for linked households.', Icons.notifications_outlined),
    PlanSection('Household plan completion', 'View household preparedness completion where sharing is authorised.', Icons.fact_check_outlined),
    PlanSection('Residents’ roll call', 'An incident roll based on the default resident list.', Icons.groups_outlined),
    PlanSection('Community setup', 'Community details and planning arrangements.', Icons.settings_outlined),
    PlanSection('Building preparedness', 'Checklists for the outside of community buildings.', Icons.business_outlined),
    PlanSection('Incident guests', 'Guest registration and incident attendance.', Icons.person_add_outlined),
    PlanSection('Sharing & privacy', 'Community plan visibility and information-sharing controls.', Icons.privacy_tip_outlined),
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
        if (index == 0) setState(() => _sideIndex = null);
        if (index == 1) {
          Navigator.push(context, MaterialPageRoute(builder: (context) => const MapScreen()));
        }
      },
      destinations: const [
        NavigationDestination(icon: Icon(Icons.warning), label: 'Incidents'),
        NavigationDestination(icon: Icon(Icons.map), label: 'Map'),
        NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
      ],
    ),
  );
}
