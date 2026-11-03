import 'widgets/privacy_security_options.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'widgets/dark_plan_layout.dart';

/// Isolated UI preview. Does not initialise Firebase, accounts or a database.
void main() {
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal, brightness: Brightness.dark)),
    home: kDebugMode ? const _PreviewMenu() : const Scaffold(body: Center(child: Text('UI preview is available in debug builds only.'))),
  ));
}

class _PreviewMenu extends StatelessWidget {
  const _PreviewMenu();
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('EchoGround UI preview')),
    body: ListView(padding: const EdgeInsets.all(24), children: [
      const Text('Design preview only', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      const Text('No login, backend, Firebase or real household data. Choose a view to inspect the layout.'),
      const SizedBox(height: 24),
      FilledButton.icon(icon: const Icon(Icons.home_outlined), label: const Text('Household preview'), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _PlanPreview(household: true)))),
      const SizedBox(height: 12),
      FilledButton.icon(icon: const Icon(Icons.groups_outlined), label: const Text('Community preview'), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const _PlanPreview(household: false)))),
    ]),
  );
}

class _PlanPreview extends StatefulWidget {
  final bool household;
  const _PlanPreview({required this.household});
  @override
  State<_PlanPreview> createState() => _PlanPreviewState();
}

class _PlanPreviewState extends State<_PlanPreview> {
  int? selected;
  static const householdSections = [
    PlanSection('Household checklist', 'Prepare the supplies your household may need when evacuating.', Icons.checklist_outlined),
    PlanSection('Household preparedness plan', 'Plan evacuation arrangements and prepare your dwelling.', Icons.home_outlined),
    PlanSection('Community contact', 'Contact details for your community contact.', Icons.contact_phone_outlined),
    PlanSection('Privacy & security', 'Choose what you share.', Icons.privacy_tip_outlined, content: PrivacySecurityOptions()),
  ];
  static const communitySections = [
    PlanSection('Notifications', 'Community notices and updates for linked households.', Icons.notifications_outlined),
    PlanSection('Household preparedness plan', 'Household preparedness summaries and completion status.', Icons.fact_check_outlined),
    PlanSection('Privacy & security', 'Privacy and security options will be available in a future release.', Icons.privacy_tip_outlined),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.household ? 'Household Dashboard' : 'Community Leader Dashboard'), centerTitle: true),
    body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), color: Theme.of(context).colorScheme.surfaceContainer, child: const Text('UI PREVIEW • no live data • back to switch roles', textAlign: TextAlign.center, style: TextStyle(fontSize: 12))),
      Expanded(child: DarkPlanLayout(
        sections: widget.household ? householdSections : communitySections,
        selectedIndex: selected,
        onSelected: (index) => setState(() => selected = index),
        incidents: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.crisis_alert_outlined, color: Color(0xFF4DB6AC)),
          SizedBox(height: 12),
          Text('Incident feed preview', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          SizedBox(height: 12),
          Text('Live warnings are not loaded in this preview. Select a sidebar icon to inspect a planning panel.'),
        ]),
      )),
    ]),
    bottomNavigationBar: NavigationBar(
      selectedIndex: 0,
      onDestinationSelected: (index) {
        if (index == 0) { setState(() => selected = null); }
        else { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('UI preview only — this action is not connected.'))); }
      },
      destinations: widget.household ? const [
        NavigationDestination(icon: Icon(Icons.crisis_alert_outlined), selectedIcon: Icon(Icons.crisis_alert_outlined), label: 'Incidents'),
        NavigationDestination(icon: Icon(Icons.report_outlined, color: Colors.redAccent, size: 34), selectedIcon: Icon(Icons.report_outlined, color: Colors.redAccent, size: 34), label: 'Report'),
        NavigationDestination(icon: Icon(Icons.contacts_outlined), label: 'Profile'),
      ] : const [
        NavigationDestination(icon: Icon(Icons.warning), label: 'Incidents'),
        NavigationDestination(icon: Icon(Icons.map), label: 'Map'),
        NavigationDestination(icon: Icon(Icons.person), label: 'Profile'),
      ],
    ),
  );
}
