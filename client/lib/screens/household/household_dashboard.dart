import 'package:flutter/material.dart';
import '../../widgets/household/household_header.dart';
import '../../widgets/active_incidents_card.dart';
import '../login_page.dart';

class HouseholdDashboard extends StatefulWidget {
  const HouseholdDashboard({super.key});

  @override
  State<HouseholdDashboard> createState() => _HouseholdDashboardState();
}

class _HouseholdDashboardState extends State<HouseholdDashboard> {
  // FIXED: Changed type to int? to support null. Allowing no sidebar selections by default
  int? _sideIndex; 

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
    final barColor = theme.navigationBarTheme.backgroundColor ??
        theme.colorScheme.surfaceContainer;

    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: barColor.withValues(alpha: 0.55),
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
            onTap: () {
              setState(() {
                // Toggle behavior: Deselect if clicked again
                _sideIndex = (_sideIndex == 0) ? null : 0;
              });
            },
          ),
          const SizedBox(height: 12),
          _railIcon(
            icon: Icons.groups_outlined,
            selectedIcon: Icons.groups,
            tooltip: 'Community Plan',
            selected: _sideIndex == 1,
            onTap: () {
              setState(() {
                // Toggle behavior: Deselect if clicked again
                _sideIndex = (_sideIndex == 1) ? null : 1;
              });
            },
          ),
        ],
      ),
    );
  }

  /// Empty structural card container shell matching ActiveIncidentsCard color and frame blueprints
  Widget _buildEmptyPlaceholderCard(String title, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF14171A), // Matches your incident widget background hex token
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF4DB6AC), size: 20),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24.0),
              child: Text(
                'No content active in this component panel context.',
                style: TextStyle(color: Colors.white38, fontSize: 13),
              ),
            ),
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
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const HouseholdHeader(),
                const SizedBox(height: 20),
                
                // DYNAMIC CONTROLLER CONTENT LOOP
                Padding(
                  padding: const EdgeInsets.only(left: 44),
                  child: Builder(
                    builder: (context) {
                      // CASE A: Checklist is active
                      if (_sideIndex == 0) {
                        return _buildEmptyPlaceholderCard('Checklist Content', Icons.checklist);
                      }
                      
                      // CASE B: Community Plan is active
                      if (_sideIndex == 1) {
                        return _buildEmptyPlaceholderCard('Community Plan Details', Icons.groups);
                      }
                      
                      // CASE C: Default/Null State - Render active incidents data block seamlessly
                      final base = Theme.of(context).textTheme;
                      return Theme(
                        data: Theme.of(context).copyWith(
                          textTheme: base.apply(fontSizeFactor: 0.88),
                        ),
                        child: const ActiveIncidentsCard(),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
          // Side pill floats over the left edge, vertically centred
          Align(
            alignment: Alignment.centerLeft,
            child: _sidePill(),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _sideIndex == null ? 0 : -1, // Unselect navigation bar items if side actions are displaying
        onDestinationSelected: (index) {
          if (index == 0) {
            setState(() => _sideIndex = null); // Return to default active incident panel overview loop
          } else if (index == 1) {
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
