import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../services/database_helper.dart';
import '../../widgets/planning/community_plan_panel.dart';
import '../../widgets/active_incidents_card.dart';
import '../../widgets/report_dialog.dart';
import '../../widgets/household/household_checklist.dart';
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
  String _activeAnnouncementBannerText =
      'No active announcements at this time.';

  @override
  void initState() {
    super.initState();
    _recoverStoredActiveAnnouncement();
    _establishRealtimeBannerListener();
  }

  /// Restores the last active cloud notification text value from SQLite configurations on layout init
  Future<void> _recoverStoredActiveAnnouncement() async {
    final String? cachedAnnouncement = await DatabaseHelper.instance.getConfig(
      'last_live_announcement',
    );
    if (mounted &&
        cachedAnnouncement != null &&
        cachedAnnouncement.trim().isNotEmpty) {
      setState(() {
        _activeAnnouncementBannerText = cachedAnnouncement.trim();
      });
    }
  }

  /// 🛰️ REAL-TIME STREAM DECODER
  /// Intercepts incoming FCM foreground announcement broadcast payloads on message delivery
  void _establishRealtimeBannerListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.data != null) {
        final Map<String, dynamic> cleanData = Map<String, dynamic>.from(
          message.data,
        );

        // Check for type definition to handle data streams accurately
        final String typeStr = (cleanData['type'] ?? '').toString();
        if (typeStr.contains('Announcement')) {
          // Extracts the correct CAPITALIZED 'Message' key matching your backend frame payload log model!
          final String? incomingBody =
              cleanData['Message']?.toString() ??
              cleanData['body']?.toString() ??
              cleanData['message']?.toString();

          if (incomingBody != null && mounted) {
            setState(() {
              _activeAnnouncementBannerText = incomingBody.trim();
            });
          }
        }
      }
    });
  }

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
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Profile Text Header Block
                Text(
                  hasFamilyName
                      ? 'Welcome back, $lastName family!'
                      : 'Welcome back! Glad you’re here.',
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
      child: ValueListenableBuilder<int>(
        valueListenable: DatabaseHelper.instance.syncNotifier,
        builder: (context, syncCount, child) {
          return FutureBuilder<String>(
            future: DatabaseHelper.instance
                .getConfig('last_live_announcement')
                .then((v) => v ?? 'No active announcements at this time.'),
            builder: (context, snapshot) {
              final String currentText =
                  snapshot.data ?? _activeAnnouncementBannerText;

              return InkWell(
                onTap: () => _showAnnouncementDetails(),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 6,
                    horizontal: 16,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.campaign,
                        color: Color(0xFF4DB6AC),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: MarqueeBanner(text: currentText)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildMainViewContent() {
    if (_bottomIndex == 1) return const HouseholdChecklist();
    if (_bottomIndex == 3) return const CommunityPlanPanel();

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

  // COMMUNITY REPORT FEED INTERCEPTOR METHOD
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

              // 🛠️ FIXED: Strict filtering guard explicitly strips any leak copies out of the lists feed
              final reports = rawList.where((item) {
                final String id = item['id']?.toString() ?? '';
                final String typeStr =
                    (item['event_type'] ?? item['type'] ?? '')
                        .toString()
                        .toLowerCase();
                final String descStr = (item['description'] ?? '')
                    .toString()
                    .toLowerCase();
                final String titleStr = (item['title'] ?? '')
                    .toString()
                    .toLowerCase();

                // 1. Core ID configuration requirement
                final bool isReportId =
                    id.startsWith('unknown_incident') ||
                    id.contains('community_report');

                // 2. Strict content pattern signatures match checks
                final bool isAnnouncement =
                    typeStr.contains('announcement') ||
                    titleStr.contains('announcement') ||
                    descStr.contains('linked context') ||
                    descStr.contains('[linked');

                return isReportId && !isAnnouncement;
              }).toList();

              final List<Map<String, dynamic>> uniqueReports = [];
              final Set<String> seenSignatures = {};

              for (var r in reports) {
                final type =
                    r['event_type']?.toString().toLowerCase().trim() ?? '';
                final created = r['created']?.toString().trim() ?? '';
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

  Widget _buildBottomNav() {
    return NavigationBar(
      selectedIndex: _bottomIndex,
      onDestinationSelected: (idx) {
        if (idx == 2) {
          showReportDialog(context);
        } else if (idx == 4) {
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
      builder: (context) => FutureBuilder(
        future: DatabaseHelper.instance
            .getConfig('last_live_announcement')
            .then((v) => v ?? _activeAnnouncementBannerText),
        builder: (context, snapshot) {
          final contentText = snapshot.data ?? _activeAnnouncementBannerText;
          return AlertDialog(
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
              child: SingleChildScrollView(
                child: Text(
                  contentText,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
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
          );
        },
      ),
    );
  }
}
