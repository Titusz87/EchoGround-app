import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../services/database_helper.dart';
import '../login_page.dart';
import 'components/leader_stats_header.dart';
import 'components/active_incidents_section.dart';
import 'components/reports_log_section.dart';

class LeaderDashboard extends StatefulWidget {
  final String? communityFallback;
  const LeaderDashboard({super.key, this.communityFallback});

  @override
  State<LeaderDashboard> createState() => _LeaderDashboardState();
}

class _LeaderDashboardState extends State<LeaderDashboard> {
  int _bottomIndex = 0;
  bool _isNetworkLoading = false;

  List<Map<String, dynamic>> _liveIncidents = [];
  List<Map<String, dynamic>> _reports = [];

  String _communityName = 'Bruhyna';
  String _householdsCount = '1';
  String _membersCount = '1';

  @override
  void initState() {
    super.initState();
    _initializeDashboardState();
  }

  /// Recovers persistent community state labels before running data pipes
  Future<void> _initializeDashboardState() async {
    final String savedComm =
        await DatabaseHelper.instance.getConfig('auth_community_name') ??
        await DatabaseHelper.instance.getConfig('community_name') ??
        '';

    if (mounted) {
      setState(() {
        if (widget.communityFallback != null &&
            widget.communityFallback!.trim().isNotEmpty) {
          _communityName = widget.communityFallback!.trim();
        } else if (savedComm.trim().isNotEmpty) {
          _communityName = savedComm.trim();
        }
      });
      _syncLeaderDashboardPipeline();
    }
  }

  Future<http.Response> _executeAdaptivePost(
    String endpointPath, {
    Object? body,
  }) async {
    const String injectedBaseUrl = String.fromEnvironment('BACKEND_URL');
    final List<String> targetBaseUrls = [
      if (injectedBaseUrl.isNotEmpty) injectedBaseUrl,
      'http://127.0.0.1:8000',
    ];

    http.Response? finalResponse;
    for (String baseUrl in targetBaseUrls) {
      try {
        final cleanBaseUrl = baseUrl.endsWith('/')
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl;

        finalResponse = await http
            .post(
              Uri.parse('$cleanBaseUrl$endpointPath'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode(body ?? {}),
            )
            .timeout(const Duration(seconds: 4));

        if (finalResponse.statusCode == 200) {
          return finalResponse;
        }
      } catch (_) {}
    }
    if (finalResponse != null) return finalResponse;
    throw Exception('Adaptive connection routing parameters exhausted.');
  }

  Future<void> _syncLeaderDashboardPipeline() async {
    try {
      final String rawLeaderId =
          await DatabaseHelper.instance.getConfig('auth_leader_id') ?? '1';
      final int parsedLeaderId = int.tryParse(rawLeaderId.trim()) ?? 1;

      final String rawHouseholds =
          await DatabaseHelper.instance.getConfig(
            'community_households_count',
          ) ??
          '1';
      final String rawMembers =
          await DatabaseHelper.instance.getConfig('community_members_count') ??
          '1';

      final Map<String, int> requestPayload = {'id': parsedLeaderId};

      // Background telemetry sync updates
      final incidentRes = await _executeAdaptivePost(
        '/community-leader/get-incidents',
        body: requestPayload,
      );
      final reportsRes = await _executeAdaptivePost(
        '/community-leader/refresh-dashboard',
        body: requestPayload,
      );

      int householdsUpdated = int.tryParse(rawHouseholds) ?? 1;
      int membersUpdated = int.tryParse(rawMembers) ?? 1;

      if (reportsRes.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(reportsRes.body);
        householdsUpdated = data['households_count'] ?? householdsUpdated;
        membersUpdated = data['members_count'] ?? membersUpdated;
      }

      final List<Map<String, dynamic>> allCachedRecords = await DatabaseHelper
          .instance
          .fetchAllNotifications();

      if (mounted) {
        setState(() {
          _householdsCount = householdsUpdated.toString();
          _membersCount = membersUpdated.toString();

          // FILTER 1: Exclude both reports AND announcements from official incident cards
          _liveIncidents = allCachedRecords.where((item) {
            final idStr = item['id']?.toString() ?? '';
            final typeStr = (item['event_type'] ?? item['type'] ?? '')
                .toString();

            return !idStr.startsWith('unknown_incident') &&
                !idStr.contains('community_report') &&
                !typeStr.contains('Announcement');
          }).toList();

          // FILTER 2: Populate ONLY authentic user reports, explicitly blocking announcements
          _reports = allCachedRecords.where((item) {
            final idStr = item['id']?.toString() ?? '';
            final typeStr = (item['event_type'] ?? item['type'] ?? '')
                .toString();

            final bool isReportRow =
                idStr.startsWith('unknown_incident') ||
                idStr.contains('community_report');
            final bool isAnnouncement = typeStr.contains('Announcement');

            return isReportRow && !isAnnouncement;
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('Sync Fallback: $e');
      final List<Map<String, dynamic>> allCachedRecords = await DatabaseHelper
          .instance
          .fetchAllNotifications();
      if (mounted) {
        setState(() {
          _liveIncidents = allCachedRecords
              .where(
                (item) =>
                    !(item['id']?.toString().startsWith('unknown_incident') ??
                        false),
              )
              .toList();
          _reports = allCachedRecords
              .where(
                (item) =>
                    (item['id']?.toString().startsWith('unknown_incident') ??
                    false),
              )
              .toList();
        });
      }
    }
  }

  Future<void> submitReportValidationAction(
    String targetReportId,
    String broadcastNotice,
  ) async {
    final String rawLeaderId =
        await DatabaseHelper.instance.getConfig('auth_leader_id') ?? '1';
    final int parsedLeaderId = int.tryParse(rawLeaderId.trim()) ?? 1;
    final String numericIdOnly = targetReportId.replaceAll(RegExp(r'\D'), '');

    final Map<String, dynamic> validationPayload = {
      'id': parsedLeaderId,
      'validated_incidents': [numericIdOnly],
      'notice': broadcastNotice.trim().isNotEmpty
          ? broadcastNotice.trim()
          : 'Verified by sector community leader.',
    };

    try {
      const String injectedBaseUrl = String.fromEnvironment('BACKEND_URL');
      final List<String> targetBaseUrls = [
        if (injectedBaseUrl.isNotEmpty) injectedBaseUrl,
        'http://127.0.0.1:8000',
      ];

      for (String baseUrl in targetBaseUrls) {
        try {
          final cleanBaseUrl = baseUrl.endsWith('/')
              ? baseUrl.substring(0, baseUrl.length - 1)
              : baseUrl;

          final response = await http
              .put(
                Uri.parse('$cleanBaseUrl/community-leader/validate-incidents'),
                headers: {'Content-Type': 'application/json'},
                body: json.encode(validationPayload),
              )
              .timeout(const Duration(seconds: 4));

          if (response.statusCode == 200) {
            // 🎯 FIXED MUTATION HARMONY: Update local memory + modify raw SQLite data fields cleanly
            final db = await DatabaseHelper.instance.database;
            await db.execute(
              "UPDATE notifications SET status = 'validated' WHERE id = ?",
              [targetReportId],
            );
            await db.execute(
              "UPDATE notifications SET is_validated = 1 WHERE id = ?",
              [targetReportId],
            );

            // Notify all listenable layouts to repaint simultaneously
            DatabaseHelper.instance.syncNotifier.value++;
            break;
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Validation submission error: $e');
    }
  }

  Future<Map<String, String>> _loadCommunityStats() async {
    return {
      'name': _communityName,
      'households': _householdsCount,
      'members': _membersCount,
    };
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
      body: _isNetworkLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4DB6AC)),
              ),
            )
          : ValueListenableBuilder<int>(
              // Forces reactive rebuilding on incoming real-time notifications
              valueListenable: DatabaseHelper.instance.syncNotifier,
              builder: (context, syncValue, _) {
                // Auto-refresh data arrays when changes occur
                _syncLeaderDashboardPipeline();

                return FutureBuilder<Map<String, String>>(
                  future: _loadCommunityStats(),
                  builder: (context, snapshot) {
                    final name = snapshot.data?['name'] ?? _communityName;
                    final households =
                        snapshot.data?['households'] ?? _householdsCount;
                    final members = snapshot.data?['members'] ?? _membersCount;

                    return RefreshIndicator(
                      onRefresh: _syncLeaderDashboardPipeline,
                      color: const Color(0xFF4DB6AC),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            LeaderStatsHeader(
                              communityName: name,
                              householdsCount: households,
                              membersCount: members,
                            ),
                            const SizedBox(height: 24),
                            _buildDynamicBodyContent(),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildDynamicBodyContent() {
    if (_bottomIndex == 1) {
      return _buildPlaceholderCard(
        'Community Action Plan Matrix',
        Icons.assignment,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ActiveIncidentsSection(liveIncidents: _liveIncidents),
        const SizedBox(height: 16),
        ReportsLogSection(
          reports: _reports,
          onValidateReport: (String id, String notice) {
            submitReportValidationAction(id, notice);
          },
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
    return NavigationBar(
      selectedIndex: _bottomIndex > 1 ? 0 : _bottomIndex,
      onDestinationSelected: (idx) {
        if (idx == 2) {
          _showAnnouncementWizard();
        } else if (idx == 3) {
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
      ],
    );
  }

  void _showAnnouncementWizard() async {
    // Local state managers
    Map<String, String>? selectedLinkedEntity;
    final textController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    List<Map<String, String>> dropdownOptions = [];
    bool isDropdownLoading = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          // BACKGROUND WORKER: Pulls live cached records the millisecond the sheet opens on screen
          if (isDropdownLoading) {
            () async {
              try {
                final List<Map<String, dynamic>> allCachedRecords =
                    await DatabaseHelper.instance.fetchAllNotifications();
                final List<Map<String, String>> populatedOptions = [];

                for (var item in allCachedRecords) {
                  final String currentId = item['id']?.toString() ?? '';
                  final String rawType =
                      (item['event_type'] ?? item['type'] ?? '').toString();
                  final String rawTitle =
                      (item['title'] ?? item['description'] ?? 'Alert')
                          .toString();

                  // Format descriptive visual anchors to match your precise "incident-title" or "report-title" requirement
                  if (currentId.startsWith('unknown_incident') ||
                      currentId.contains('community_report')) {
                    // It's a citizen-submitted report: map its localized title text parameters
                    populatedOptions.add({
                      'id': currentId,
                      'display': 'REPORT - ${rawTitle.toUpperCase()}',
                    });
                  } else {
                    // It's an official verified community incident: map its event category type fields
                    populatedOptions.add({
                      'id': currentId,
                      'display': 'INCIDENT - ${rawType.toUpperCase()}',
                    });
                  }
                }

                setModalState(() {
                  dropdownOptions = populatedOptions;
                  isDropdownLoading = false;
                });
              } catch (e) {
                debugPrint(
                  'Failed to populate live wizard option dropdown maps: $e',
                );
                setModalState(() => isDropdownLoading = false);
              }
            }();
          }

          /// BROADCAST ROUTINE DISPATCHER
          Future<void> dispatchLiveBroadcastNotification() async {
            if (!formKey.currentState!.validate()) return;

            final String rawLeaderId =
                await DatabaseHelper.instance.getConfig('auth_leader_id') ??
                '1';
            final int parsedLeaderId = int.tryParse(rawLeaderId.trim()) ?? 1;

            // Build the string text message body. Include the linked entity identifier if one was selected
            String finalBroadcastMessage = textController.text.trim();
            if (selectedLinkedEntity != null) {
              finalBroadcastMessage +=
                  '\n\n[Linked Context: ${selectedLinkedEntity!['display']}]';
            }

            // SWAGGER BLUEPRINT ALIGNED SCHEMA PAYLOAD MODEL
            final Map<String, dynamic> broadcastPayload = {
              'id': parsedLeaderId,
              'body': finalBroadcastMessage,
            };

            try {
              // Dispatch clean post request payload out to live server address nodes
              final response = await _executeAdaptivePost(
                '/community-leader/publish-notification',
                body: broadcastPayload,
              );

              if (response.statusCode == 200) {
                if (context.mounted) Navigator.pop(context);
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Announcement broadcast sent via FCM successfully.',
                    ),
                    backgroundColor: Colors.teal,
                  ),
                );
              }
            } catch (err) {
              debugPrint('FCM Notification dispatch error failure: $err');
            }
          }

          return AlertDialog(
            backgroundColor: const Color(0xFF1E2225),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Publish Community Broadcast',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            content: SizedBox(
              width: 460,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // DYNAMIC RENDERING DROPDOWN SELECTION WINDOW
                    isDropdownLoading
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12.0),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFF4DB6AC),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Loading list options...',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : DropdownButtonFormField<Map<String, String>>(
                            value: selectedLinkedEntity,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF14171A),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Target Incident Link (Optional)',
                              labelStyle: TextStyle(color: Colors.white60),
                              border: OutlineInputBorder(),
                            ),
                            items: dropdownOptions.map((
                              Map<String, String> option,
                            ) {
                              return DropdownMenuItem<Map<String, String>>(
                                value: option,
                                child: Text(
                                  option['display']!,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList(),
                            onChanged: (v) =>
                                setModalState(() => selectedLinkedEntity = v),
                          ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: textController,
                      maxLines: 4,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Type announcement message...',
                        hintStyle: TextStyle(color: Colors.white38),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Announcement body text details required.'
                          : null,
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: dispatchLiveBroadcastNotification,
                child: const Text(
                  'Send Broadcast',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
