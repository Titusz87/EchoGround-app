import 'package:flutter/material.dart';

import '../../services/database_helper.dart';
import '../login_page.dart';
import 'components/leader_side_pill.dart';
import 'components/leader_reports_log.dart';

class LeaderDashboard extends StatefulWidget {
  const LeaderDashboard({super.key});

  @override
  State<LeaderDashboard> createState() => _LeaderDashboardState();
}

class _LeaderDashboardState extends State<LeaderDashboard> {
  int? _sideIndex;

  final List<Map<String, dynamic>> _reports = [
    {
      'id': 'rep_01',
      'sender_name': 'Thomas Tarcsai',
      'phone': '+61 412 345 678',
      'type': 'Bushfire Proximity',
      'location': '📍 Broome, WA · Yawuru',
      'description': 'Smoke columns visible near the northeast ridgeline. Wind shifting toward residential boundary paths.',
      'status': null,
    },
    {
      'id': 'rep_02',
      'sender_name': 'Sarah Jenkins',
      'phone': '+61 498 765 432',
      'type': 'Flash Flood',
      'location': '📍 Roebuck Bay Crossing',
      'description': 'Water levels have risen over the primary access road crossing infrastructure. Small cars cannot pass.',
      'status': null,
    },
  ];

  /// Loads live community profile statistics dynamically out of your SQLite storage configuration tables.
  Future<Map<String, String>> _loadCommunityStats() async {
    // 🛠️ UPDATED: Check 'auth_community_name' first, fall back to leader path keys, then to your new community name
    final String name =
        await DatabaseHelper.instance.getConfig('auth_community_name') ??
        await DatabaseHelper.instance.getConfig('auth_leader_community') ??
        'Unknown Community';

    // Dynamically retrieve metrics or display baseline figures for a freshly generated community zone
    final String households =
        await DatabaseHelper.instance.getConfig('auth_households_count') ??
        await DatabaseHelper.instance.getConfig('community_households_count') ??
        '1';

    final String members =
        await DatabaseHelper.instance.getConfig('auth_members_count') ??
        await DatabaseHelper.instance.getConfig('community_members_count') ??
        '1';

    return {'name': name, 'households': households, 'members': members};
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
        future: _loadCommunityStats(),
        builder: (context, snapshot) {
          final name = snapshot.data?['name'] ?? 'Trujneya';
          final households = snapshot.data?['households'] ?? '2';
          final members = snapshot.data?['members'] ?? '10';

          return Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Community $name',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Households: $households\nMembers: $members',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white60,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.only(left: 48.0),
                      child: _buildDynamicBodyContent(),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: LeaderSidePill(
                  sideIndex: _sideIndex,
                  onChanged: (idx) => setState(() => _sideIndex = idx),
                  onOpenAnnouncementWizard: _showAnnouncementWizard,
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildDynamicBodyContent() {
    if (_sideIndex == 2)
      return _buildPlaceholderCard(
        'Community Action Plan Matrix',
        Icons.assignment,
      );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildActiveIncidentsPlaceholder(),
        const SizedBox(height: 16),
        LeaderReportsLog(
          reports: _reports,
          onStatusChanged: (idx, status) =>
              setState(() => _reports[idx]['status'] = status),
        ),
      ],
    );
  }

  Widget _buildActiveIncidentsPlaceholder() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF14171A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.orangeAccent,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'ACTIVE INCIDENTS',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          SizedBox(height: 32),
          Center(
            child: Text(
              'No current incidents reported.',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ),
        ],
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
            child: Text(
              'No content active in this component panel context.',
              style: TextStyle(color: Colors.white38, fontSize: 13),
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
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Map',
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

  void _showAnnouncementWizard() {
    String? selectedIncident;
    final textController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final List<String> options = [
      'Active Bushfire Alert (Northeast)',
      'Roebuck Bay Flash Flood Event',
      'Regional Severe Thunderstorm Advisory',
    ];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: const Color(0xFF14171A),
          title: const Text(
            'Publish Community Broadcast',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: 460,
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedIncident,
                    isExpanded: true,
                    dropdownColor: const Color(0xFF14171A),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: 'Target Incident Link',
                      border: OutlineInputBorder(),
                    ),
                    items: options
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(e, overflow: TextOverflow.ellipsis),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setModalState(() => selectedIncident = v),
                    validator: (v) => v == null ? 'Required field' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: textController,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Type announcement message...',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Required field' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white38),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4DB6AC),
                foregroundColor: const Color(0xFF14171A),
              ),
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Broadcast sent.'),
                      backgroundColor: Colors.teal,
                    ),
                  );
                }
              },
              child: const Text('Send Broadcast'),
            ),
          ],
        ),
      ),
    );
  }
}
