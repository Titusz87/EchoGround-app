import 'package:flutter/material.dart';
import '../../widgets/household/household_header.dart';
import '../../widgets/active_incidents_card.dart';
import '../login_page.dart';

//import 'package:maplibre_gl/maplibre_gl.dart';

class HouseholdDashboard extends StatefulWidget {
  const HouseholdDashboard({super.key});

  @override
  State<HouseholdDashboard> createState() => _HouseholdDashboardState();
}

class _HouseholdDashboardState extends State<HouseholdDashboard> {
  int _sideIndex = 0; // 0 = Checklist, 1 = Community Plan

  void _openCommunityPlan() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  Widget _railIcon({
    required IconData icon,
    required IconData selectedIcon,
    required String tooltip,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? scheme.secondaryContainer : Colors.transparent,
          ),
          child: Icon(
            selected ? selectedIcon : icon,
            size: 22,
            color: selected
                ? scheme.onSecondaryContainer
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }

  Widget _sidePill() {
    final theme = Theme.of(context);
    // Same grey as the bottom navigation bar, slightly transparent
    final barColor = theme.navigationBarTheme.backgroundColor ??
        theme.colorScheme.surfaceContainer;

    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: barColor.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _railIcon(
            icon: Icons.checklist_outlined,
            selectedIcon: Icons.checklist,
            tooltip: 'Checklist',
            selected: _sideIndex == 0,
            onTap: () => setState(() => _sideIndex = 0),
          ),
          const SizedBox(height: 12),
          _railIcon(
            icon: Icons.groups_outlined,
            selectedIcon: Icons.groups,
            tooltip: 'Community Plan',
            selected: _sideIndex == 1,
            onTap: _openCommunityPlan,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Household Dashboard'),
        centerTitle: true,
      ),
      body: Row(
        children: [
          // Side pill, vertically centred on the left
          Center(child: _sidePill()),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(8, 16, 16, 16),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0, // Incidents is the active tab
        onDestinationSelected: (index) {
          if (index == 1) {
            // TODO: open the Report page
          } else if (index == 2) {
            // TODO: open the Contacts page
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
          NavigationDestination(
            icon: Icon(Icons.contacts_outlined),
            selectedIcon: Icon(Icons.contacts),
            label: 'Contacts',
          ),
        ],
      ),
    );
  }
}
