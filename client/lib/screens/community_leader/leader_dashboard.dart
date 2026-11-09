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

  static const String _backendBaseUrl = String.fromEnvironment('BACKEND_URL');

  List<Map<String, dynamic>> _liveIncidents = [];
  List<Map<String, dynamic>> _reports = [];

  String _communityName = 'Unknown Community';
  String _householdsCount = '1';
  String _membersCount = '1';

  @override
  void initState() {
    super.initState();
    if (widget.communityFallback != null &&
        widget.communityFallback!.trim().isNotEmpty) {
      _communityName = widget.communityFallback!.trim();
    }
    _syncLeaderDashboardPipeline();
  }

  Future<http.Response> _executeAdaptivePost(
    String endpointPath, {
    Object? body,
  }) async {
    const String injectedBaseUrl = String.fromEnvironment('BACKEND_URL');

    final List<String> targetBaseUrls = [
      // Option 1: Prioritize the live cloud environment if configured
      if (injectedBaseUrl.isNotEmpty) injectedBaseUrl,

      // Only attempt the local fallback port if we are running a local debug layout session,
      // avoiding Cross-Origin blocks completely in live browser deployments!
      if (injectedBaseUrl.isEmpty) 'http://127.0.0.1:8000',
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
          debugPrint(
            'ECO NETWORK: Connected successfully via node: $cleanBaseUrl',
          );
          return finalResponse;
        }
      } catch (err) {
        debugPrint('ECO NETWORK: Skipping node $baseUrl due to fault: $err');
      }
    }
    if (finalResponse != null) return finalResponse;
    throw Exception(
      'Adaptive system network configuration routing parameters exhausted.',
    );
  }

  /// Prioritizes local disk data rows to ensure 100% cross-device rendering alignment
  Future<void> _syncLeaderDashboardPipeline() async {
    if (!mounted) return;
    setState(() => _isNetworkLoading = true);

    try {
      final String rawLeaderId =
          await DatabaseHelper.instance.getConfig('auth_leader_id') ?? '1';
      final int parsedLeaderId = int.tryParse(rawLeaderId.trim()) ?? 1;

      String currentCommunity = _communityName;
      if (widget.communityFallback == null ||
          widget.communityFallback!.trim().isEmpty) {
        final String rawCommunity =
            await DatabaseHelper.instance.getConfig('auth_community_name') ??
            await DatabaseHelper.instance.getConfig('community_name') ??
            'Unknown Community';
        currentCommunity = rawCommunity.trim();
      }

      final String rawHouseholds =
          await DatabaseHelper.instance.getConfig(
            'community_households_count',
          ) ??
          '1';
      final String rawMembers =
          await DatabaseHelper.instance.getConfig('community_members_count') ??
          '1';

      final Map<String, int> requestPayload = {'id': parsedLeaderId};

      // 1. Dispatch background HTTP requests to refresh server counters status rows
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

      // THE CRITICAL UI RENDERING HANDSHAKE LINK:
      // Instead of relying on fluctuating online JSON keys shape formats, read rows straight from SQLite cache
      // where the background synchronizer has already validated and saved the incoming data entries
      final List<Map<String, dynamic>> allCachedRecords = await DatabaseHelper
          .instance
          .fetchAllNotifications();

      setState(() {
        _communityName = currentCommunity;
        _householdsCount = householdsUpdated.toString();
        _membersCount = membersUpdated.toString();

        // Populate Authoritative Incidents (exclusively items that are not unknown user logs)
        _liveIncidents = allCachedRecords.where((item) {
          final idStr = item['id']?.toString() ?? '';
          return !idStr.startsWith('unknown_incident') &&
              !idStr.contains('community_report');
        }).toList();

        // Populate User-Submitted Reports Feed items matching your household logs schema signatures
        _reports = allCachedRecords.where((item) {
          final idStr = item['id']?.toString() ?? '';
          return idStr.startsWith('unknown_incident') ||
              idStr.contains('community_report');
        }).toList();
      });
    } catch (e) {
      debugPrint('Leader Local Cache Engine Fallback: $e');
      final List<Map<String, dynamic>> allCachedRecords = await DatabaseHelper
          .instance
          .fetchAllNotifications();
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
    } finally {
      if (mounted) setState(() => _isNetworkLoading = false);
    }
  }

  /// CONNECTED REVIEWS PIPELINE ACTION: Dispatches PUT validations as structured inside Swagger
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
        if (injectedBaseUrl.isEmpty) 'http://127.0.0.1:8000',
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
            debugPrint('✅ VALIDATION PASSED');

            // Paint validation color status changes on local views instantly
            setState(() {
              for (var report in _reports) {
                if (report['id']?.toString() == targetReportId) {
                  report['status'] = 'validated';
                }
              }
            });

            // Write change to local cache permanently
            final db = await DatabaseHelper.instance.database;
            await db.execute(
              "UPDATE notifications SET status = 'validated' WHERE id = ?",
              [targetReportId],
            );

            // Force dynamic rebuild trigger pass
            DatabaseHelper.instance.syncNotifier.value++;
            break;
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Validation submission fault error: $e');
    }
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
              // THE LIVE LISTENING GATEWAY: Listens directly to incoming background dataset mutations!
              valueListenable: DatabaseHelper.instance.syncNotifier,
              builder: (context, syncCount, _) {
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

        //  Feeds the callback execution action handler cleanly across components
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
                    value: selectedIncident,
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

  /// Re-establishes the missing stats loader method for the build frame loop
  Future<Map<String, String>> _loadCommunityStats() async {
    return {
      'name': _communityName,
      'households': _householdsCount,
      'members': _membersCount,
    };
  }
}
