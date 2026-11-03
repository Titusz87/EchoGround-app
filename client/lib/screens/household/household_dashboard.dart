import '../../widgets/privacy_security_options.dart';
import 'package:flutter/material.dart';
import '../../widgets/active_incidents_card.dart';
import '../../widgets/dark_plan_layout.dart';

class HouseholdDashboard extends StatefulWidget {
  const HouseholdDashboard({super.key});
  @override
  State<HouseholdDashboard> createState() => _HouseholdDashboardState();
}

class _HouseholdDashboardState extends State<HouseholdDashboard> {
  int? _sideIndex;
  static const _sections = [
    PlanSection('Household checklist', 'Prepare the supplies your household may need when evacuating.', Icons.checklist_outlined),
    PlanSection('Household preparedness plan', 'Plan evacuation arrangements and prepare your dwelling.', Icons.home_outlined),
    PlanSection('Community contact', 'Contact details for your community contact.', Icons.contact_phone_outlined),
    PlanSection('Privacy & security', 'Choose what you share.', Icons.privacy_tip_outlined, content: PrivacySecurityOptions()),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Household Dashboard'), centerTitle: true),
    body: DarkPlanLayout(
      sections: _sections,
      selectedIndex: _sideIndex,
      onSelected: (index) => setState(() => _sideIndex = index),
      incidents: Theme(
        data: Theme.of(context).copyWith(textTheme: Theme.of(context).textTheme.apply(fontSizeFactor: 0.88)),
        child: const ActiveIncidentsCard(),
      ),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: 0,
      onDestinationSelected: (index) {
        if (index == 0) setState(() => _sideIndex = null);
        // Report and Profile retain the team's existing placeholder behaviour.
      },
      destinations: const [
        NavigationDestination(icon: Icon(Icons.crisis_alert_outlined), selectedIcon: Icon(Icons.crisis_alert_outlined), label: 'Incidents'),
        NavigationDestination(icon: Icon(Icons.report_outlined, color: Colors.redAccent, size: 34), selectedIcon: Icon(Icons.report_outlined, color: Colors.redAccent, size: 34), label: 'Report'),
        NavigationDestination(icon: Icon(Icons.contacts_outlined), selectedIcon: Icon(Icons.contacts_outlined), label: 'Profile'),
      ],
    ),
  );
}
