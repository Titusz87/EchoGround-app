import 'package:flutter/material.dart';

import '../../services/database_helper.dart';
import '../../widgets/active_incidents_card.dart';
import '../../widgets/report_dialog.dart';
import '../../widgets/household/household_checklist.dart';
import '../../widgets/planning/community_plan_panel.dart';
import '../../widgets/incident_tile.dart';
import '../login_page.dart';
import 'components/marquee_banner.dart';

class HouseholdDashboard extends StatefulWidget {
  const HouseholdDashboard({super.key});

  @override
  State<HouseholdDashboard> createState() => _HouseholdDashboardState();
}

class _HouseholdDashboardState extends State<HouseholdDashboard> {
  int _bottomIndex =
      0; // Standard bottom navigation item controller index tracking
  final String _announcementText =
      'No active announcements at the moment. Check back later for critical community updates.';

  Future<Map<String, String>> _loadProfile() async {
    final lastName =
        await DatabaseHelper.instance.getConfig('household_last_name') ??
        'Unknown Household';
    return {'last_name': lastName};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF14171A),
      appBar: AppBar(
        title: const Text(''),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: FutureBuilder<Map<String, String>>(
        future: _loadProfile(),
        builder: (context, snapshot) {
          final lastName = (snapshot.data?['last_name'] ?? '').trim();
          final hasFamilyName = lastName.isNotEmpty &&
              !['unknown', 'unknown household', '—'].contains(lastName.toLowerCase());

          return SingleChildScrollView(
            // FIXED: Removed the left sidebar padding constraint completely!
            // All content rows now scale to full screen layout width safely.
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Profile Text Header Block
                Text(
                  hasFamilyName ? 'Welcome back, $lastName family' : 'Welcome back',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Let’s keep your household prepared.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.white60),
                ),
                const SizedBox(height: 24),

                // Full-Width Interactive Marquee Ticker
                _buildTickerTape(),
                const SizedBox(height: 24),

                // Active Target Screen Component Display Frame
                _buildMainViewContent(),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildTickerTape() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2225),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: InkWell(
        onTap: () => _showAnnouncementDetails(),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.campaign, color: Color(0xFF4DB6AC), size: 18),
              const SizedBox(width: 8),
              Expanded(child: MarqueeBanner(text: _announcementText)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainViewContent() {
    // Switch state layout frames based on your bottom navigation choices
    if (_bottomIndex == 1) return const HouseholdChecklist();
    if (_bottomIndex == 3) return const CommunityPlanPanel();

    // Default Index (0) -> Main Feed Overview Card Stack
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Theme(
          data: Theme.of(context).copyWith(
            textTheme: Theme.of(context).textTheme.apply(fontSizeFactor: 0.88),
          ),
          child: const ActiveIncidentsCard(),
        ),
        const SizedBox(height: 16),
        _buildCommunityReportsFeed(),
      ],
    );
  }

  // 🛠️ DYNAMIC COMMUNITY REPORT FEED INTERCEPTOR
  Widget _buildCommunityReportsFeed() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF14171A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: ValueListenableBuilder<int>(
        valueListenable: DatabaseHelper.instance.syncNotifier,
        builder: (context, syncCount, _) {
          return FutureBuilder<List<Map<String, dynamic>>>(
            future: DatabaseHelper.instance.fetchAllNotifications(),
            builder: (context, snapshot) {
              final rawList = snapshot.data ?? [];

              // 1. Filter out only entries that are community reports
              final reports = rawList.where((item) {
                final id = item['id']?.toString() ?? '';
                return id.startsWith('unknown_incident') ||
                    id.contains('community_report');
              }).toList();

              // 2. Anti-Duplication normalization layer: deduplicate by event type and time window
              final List<Map<String, dynamic>> uniqueReports = [];
              final Set<String> seenSignatures = {};

              for (var r in reports) {
                final type =
                    r['event_type']?.toString().toLowerCase().trim() ?? '';
                final created = r['created']?.toString().trim() ?? '';
                // Take base minute string slice or approximate group criteria signature
                final timeSig = created.length > 16
                    ? created.substring(0, 16)
                    : created;
                final signature = '${type}_$timeSig';

                if (!seenSignatures.contains(signature)) {
                  seenSignatures.add(signature);
                  uniqueReports.add(r);
                }
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.assignment_turned_in_outlined,
                        color: Color(0xFF4DB6AC),
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'COMMUNITY REPORTS FEED',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (uniqueReports.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24.0),
                        child: Text(
                          'No public community reports active in your sector context.',
                          style: TextStyle(color: Colors.white38, fontSize: 13),
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: uniqueReports.length,
                      separatorBuilder: (_, __) =>
                          const Divider(color: Colors.white10, height: 16),
                      itemBuilder: (context, index) {
                        return IncidentTile(incident: uniqueReports[index]);
                      },
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildPlaceholderCard(String title, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF14171A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
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
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
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

  Widget _buildBottomNav() {
    return NavigationBar(
      selectedIndex: _bottomIndex,
      onDestinationSelected: (idx) {
        if (idx == 2) {
          // Trigger the 3-page structural report dialog modal overlay pattern
          showReportDialog(context);
        } else if (idx == 4) {
          // Route direct page navigation context straight over the account profile portal
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
          );
        } else {
          setState(() => _bottomIndex = idx);
        }
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.checklist_outlined),
          selectedIcon: Icon(Icons.checklist),
          label: 'Checklist',
        ),
        NavigationDestination(
          icon: Icon(Icons.report_outlined, color: Colors.redAccent),
          selectedIcon: Icon(Icons.report, color: Colors.redAccent),
          label: 'Report',
        ),
        NavigationDestination(
          icon: Icon(Icons.groups_outlined),
          selectedIcon: Icon(Icons.groups),
          label: 'Plan',
        ),
        NavigationDestination(
          icon: Icon(Icons.account_circle_outlined),
          selectedIcon: Icon(Icons.account_circle),
          label: 'Profile',
        ),
      ],
    );
  }

  void _showAnnouncementDetails() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF14171A),
        title: const Row(
          children: [
            Icon(Icons.campaign, color: Color(0xFF4DB6AC)),
            SizedBox(width: 8),
            Text(
              'Community Announcement',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _announcementText,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: Color(0xFF4DB6AC)),
            ),
          ),
        ],
      ),
    );
  }
}
