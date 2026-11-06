import 'package:flutter/material.dart';
import '../login_page.dart';
import '../../widgets/report_dialog.dart';
import '../../widgets/active_incidents_card.dart';
import '../../widgets/dark_plan_layout.dart';
import '../../widgets/community_leader/community_plan_editor.dart';


import '../../services/database_helper.dart';
import 'components/leader_reports_log.dart';

class LeaderDashboard extends StatefulWidget {
  const LeaderDashboard({super.key});
  @override
  State<LeaderDashboard> createState() => _LeaderDashboardState();
}

class _LeaderDashboardState extends State<LeaderDashboard> {
  int? _sideIndex = 1;
  final _planDraft = CommunityPlanDraft();
  List<PlanSection> get _sections => [
    PlanSection('Notifications', 'Community notices and updates for linked households.', Icons.notifications_outlined),
    PlanSection('Community plan', 'Community evacuation arrangements.', Icons.description_outlined, content: CommunityPlanEditor(draft: _planDraft)),
    PlanSection('Household preparedness plan', 'Household preparedness summaries and completion status.', Icons.fact_check_outlined),
    PlanSection('Privacy & security', 'Privacy and security options will be available in a future release.', Icons.privacy_tip_outlined),
  ];

  int _bottomIndex =
      0; // Standard bottom navigation item controller index tracking

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

  Future<Map<String, String>> _loadCommunityStats() async {
    final name =
        await DatabaseHelper.instance.getConfig('auth_community_name') ??
        'Bruhyna';
    final households =
        await DatabaseHelper.instance.getConfig('community_households_count') ??
        '1';
    final members =
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
          final name = snapshot.data?['name'] ?? 'Bruhyna';
          final households = snapshot.data?['households'] ?? '1';
          final members = snapshot.data?['members'] ?? '1';

          if (_bottomIndex == 1) {
            return DarkPlanLayout(
              sections: _sections,
              selectedIndex: _sideIndex,
              onSelected: (index) => setState(() => _sideIndex = index),
              incidents: const ActiveIncidentsCard(),
            );
          }
          return SingleChildScrollView(
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

                // Active Core Render Shell
                _buildDynamicBodyContent(),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildDynamicBodyContent() {
    // Default Index (0) -> Core Overview Panels Stack Card views
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ActiveIncidentsCard(),
        const SizedBox(height: 16),
        LeaderReportsLog(
          reports: _reports,
          onStatusChanged: (idx, status) =>
              setState(() => _reports[idx]['status'] = status),
        ),
      ],
    );
  }

  Widget _buildBottomNav() {
    return NavigationBar(
      selectedIndex: _bottomIndex > 2 ? 0 : _bottomIndex, // Ensures fallback highlight maps to Home safely during popups
      onDestinationSelected: (idx) {
        if (idx == 2) {
          // Trigger the stateful dialog popup interface directly
          _showAnnouncementWizard();
        } else if (idx == 3) {
          // Route direct page navigation context straight over the account profile portal
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
          );
        } else if (idx == 4) {
          showReportDialog(context);
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
          icon: Icon(Icons.assignment_outlined),
          selectedIcon: Icon(Icons.assignment),
          label: 'Plan',
        ),
        NavigationDestination(
          icon: Icon(Icons.add_comment_outlined, color: Color(0xFF4DB6AC)),
          selectedIcon: Icon(Icons.add_comment, color: Color(0xFF4DB6AC)),
          label: 'Broadcast',
        ),
        NavigationDestination(
          icon: Icon(Icons.account_circle_outlined),
          selectedIcon: Icon(Icons.account_circle),
          label: 'Profile',
        ),
        NavigationDestination(
          icon: Icon(Icons.report_outlined, color: Colors.redAccent),
          selectedIcon: Icon(Icons.report, color: Colors.redAccent),
          label: 'Report',
        ),
      ],
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
