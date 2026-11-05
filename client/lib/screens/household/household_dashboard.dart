import 'package:flutter/material.dart';

import '../../services/database_helper.dart';
import '../../widgets/active_incidents_card.dart';
import '../../widgets/report_dialog.dart';
import '../login_page.dart';
import 'components/marquee_banner.dart';
import 'components/household_side_pill.dart';

class HouseholdDashboard extends StatefulWidget {
  const HouseholdDashboard({super.key});

  @override
  State<HouseholdDashboard> createState() => _HouseholdDashboardState();
}

class _HouseholdDashboardState extends State<HouseholdDashboard> {
  int? _sideIndex;
  final String _announcementText =
      'No active announcements at the moment. Check back later for critical community updates.';

  Future<Map<String, String>> _loadProfile() async {
    final lastName =
        await DatabaseHelper.instance.getConfig('household_last_name') ??
        'Unknown';
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
          final lastName = snapshot.data?['last_name'] ?? 'Tarcsai';

          return Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Centered Profile Name Header Block
                    Text(
                      'Household $lastName',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Full-Width Interactive Marquee Ticker
                    _buildTickerTape(),
                    const SizedBox(height: 24),

                    // Main Grid Content (Offsets 48px to the right to leave space for sidebar)
                    Padding(
                      padding: const EdgeInsets.only(left: 48.0),
                      child: _buildMainViewContent(),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: HouseholdSidePill(
                  sideIndex: _sideIndex,
                  onChanged: (idx) => setState(() => _sideIndex = idx),
                ),
              ),
            ],
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
    if (_sideIndex == 0)
      return _buildPlaceholderCard('Checklist Content', Icons.checklist);
    if (_sideIndex == 1)
      return _buildPlaceholderCard('Community Plan Details', Icons.groups);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Theme(
          data: Theme.of(context).copyWith(
            textTheme: Theme.of(context).textTheme.apply(fontSizeFactor: 0.88),
          ),
          child: ActiveIncidentsCard(),
        ),
        const SizedBox(height: 16),
        _buildPlaceholderCard(
          'Community Reports',
          Icons.assignment_turned_in_outlined,
        ),
      ],
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
    return Theme(
      data: Theme.of(context).copyWith(
        navigationBarTheme: _sideIndex != null
            ? const NavigationBarThemeData(indicatorColor: Colors.transparent)
            : Theme.of(context).navigationBarTheme,
      ),
      child: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (idx) {
          if (idx == 0) setState(() => _sideIndex = null);
          if (idx == 1) showReportDialog(context);
          if (idx == 2)
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const LoginPage()),
            );
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.report_outlined, color: Colors.redAccent),
            selectedIcon: Icon(Icons.report, color: Colors.redAccent),
            label: 'Report',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_circle_outlined),
            selectedIcon: Icon(Icons.account_circle),
            label: 'Profile',
          ),
        ],
      ),
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
