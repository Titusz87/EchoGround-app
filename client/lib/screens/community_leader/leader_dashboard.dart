import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../services/database_helper.dart';
import '../../widgets/embedded_street_map.dart';
import '../../widgets/planning/community_plan_panel.dart';
import '../guest_mode/components/guest_location_footer.dart';
import '../guest_mode/components/guest_location_service.dart';
import '../guest_mode/components/guest_map_incident_bubble.dart';
import '../login_page.dart';
import 'components/active_incidents_section.dart';
import 'components/leader_broadcast_dialog.dart';
import 'components/leader_hero_header.dart';
import 'components/leader_quick_actions_grid.dart';
import 'components/leader_summary_banner.dart';
import 'components/leader_theme.dart';
import 'components/reports_log_section.dart';

/// Active sub-view rendered inside the Community Leader dashboard.
enum _LeaderViewMode { home, map, plan }

/// Main dashboard screen for authenticated Community Leaders.
///
/// Synchronises community telemetry, active incidents, and citizen reports,
/// while providing quick access to the sector map, emergency plan, and
/// community-wide broadcast tools.
class LeaderDashboard extends StatefulWidget {
  final String? communityFallback;

  const LeaderDashboard({super.key, this.communityFallback});

  @override
  State<LeaderDashboard> createState() => _LeaderDashboardState();
}

class _LeaderDashboardState extends State<LeaderDashboard> {
  static const int _homeNavIndex = 0;
  static const int _profileNavIndex = 1;

  /// Persists acknowledged incident and report IDs across sub-views and rebuilds.
  static final Set<String> _acknowledgedIncidentIds = <String>{};
  static final Set<String> _acknowledgedReportIds = <String>{};

  final GlobalKey _mapKey = GlobalKey();
  final GuestLocationService _locationService = GuestLocationService();

  _LeaderViewMode _activeView = _LeaderViewMode.home;
  List<Map<String, dynamic>> _liveIncidents = [];
  List<Map<String, dynamic>> _reports = [];

  String _communityName = 'Bruhyna';
  String _householdsCount = '1';
  String _membersCount = '1';

  LatLng? _deviceLocation;
  String _localityLabel = 'Finding your location…';
  String _territoryLabel = '';
  bool _isLocating = false;

  Map<String, dynamic>? _selectedMapIncident;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    DatabaseHelper.instance.syncNotifier.addListener(_onDatabaseChanged);
    _initializeDashboardState();
    _refreshLocation();
  }

  @override
  void dispose() {
    DatabaseHelper.instance.syncNotifier.removeListener(_onDatabaseChanged);
    super.dispose();
  }

  void _onDatabaseChanged() {
    DatabaseHelper.instance.fetchAllNotifications().then((records) {
      if (mounted) {
        setState(() => _applyCachedRecordFilters(records));
      }
    });
    _syncLeaderDashboardPipeline();
  }

  /// Recovers saved community labels and triggers initial telemetry sync.
  Future<void> _initializeDashboardState() async {
    final String savedComm =
        await DatabaseHelper.instance.getConfig('auth_community_name') ??
        await DatabaseHelper.instance.getConfig('community_name') ??
        '';

    if (!mounted) return;

    setState(() {
      if (widget.communityFallback != null &&
          widget.communityFallback!.trim().isNotEmpty) {
        _communityName = widget.communityFallback!.trim();
      } else if (savedComm.trim().isNotEmpty) {
        _communityName = savedComm.trim();
      }
    });

    await _syncLeaderDashboardPipeline();
  }

  /// Resolves device coordinates, locality name, and First Nations territory.
  Future<void> _refreshLocation() async {
    if (_isLocating) return;

    setState(() {
      _isLocating = true;
      _localityLabel = 'Finding your location…';
      _territoryLabel = '';
    });

    final result = await _locationService.fetchLocationDetails();
    if (!mounted) return;

    setState(() {
      _deviceLocation = result.coordinates;
      _localityLabel = result.locality;
      _territoryLabel = result.territory;
      _isLocating = false;
    });
  }

  /// Sends a POST request against the configured backend URL with local fallback.
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
    for (final baseUrl in targetBaseUrls) {
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
            .timeout(const Duration(seconds: 5));

        if (finalResponse.statusCode == 200) {
          return finalResponse;
        }
      } catch (_) {}
    }

    if (finalResponse != null) return finalResponse;
    throw Exception('Backend endpoints unreachable for $endpointPath');
  }

  /// Synchronises community counts, active incidents, and citizen reports.
  Future<void> _syncLeaderDashboardPipeline() async {
    if (_isSyncing) return;
    _isSyncing = true;

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

      await _executeAdaptivePost(
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
        final decoded = json.decode(reportsRes.body);
        if (decoded is Map<String, dynamic>) {
          householdsUpdated = decoded['households_count'] ?? householdsUpdated;
          membersUpdated = decoded['members_count'] ?? membersUpdated;
        }
      }

      final allCachedRecords = await DatabaseHelper.instance
          .fetchAllNotifications();

      if (mounted) {
        setState(() {
          _householdsCount = householdsUpdated.toString();
          _membersCount = membersUpdated.toString();
          _applyCachedRecordFilters(allCachedRecords);
        });
      }
    } catch (e) {
      debugPrint('Leader dashboard sync fallback: $e');
      final allCachedRecords = await DatabaseHelper.instance
          .fetchAllNotifications();

      if (mounted) {
        setState(() {
          _applyCachedRecordFilters(allCachedRecords);
        });
      }
    } finally {
      _isSyncing = false;
    }
  }

  /// Splits cached records into official incidents and deduplicated citizen reports.
  void _applyCachedRecordFilters(List<Map<String, dynamic>> records) {
    _liveIncidents = records.where((item) {
      final idStr = item['id']?.toString() ?? '';
      final typeStr = (item['event_type'] ?? item['type'] ?? '').toString();

      return !idStr.startsWith('unknown_incident') &&
          !idStr.contains('community_report') &&
          !typeStr.contains('Announcement');
    }).toList();

    final rawReports = records.where((item) {
      final idStr = item['id']?.toString() ?? '';
      final typeStr = (item['event_type'] ?? item['type'] ?? '').toString();

      final bool isReportRow =
          idStr.startsWith('unknown_incident') ||
          idStr.contains('community_report');
      final bool isAnnouncement = typeStr.contains('Announcement');

      return isReportRow && !isAnnouncement;
    }).toList();

    // Sort server-synced records (community_report_*) ahead of local fallbacks
    // so deduplication keeps the real backend ID for validation actions.
    rawReports.sort((a, b) {
      final aIsServer = (a['id']?.toString() ?? '').contains(
        'community_report',
      );
      final bIsServer = (b['id']?.toString() ?? '').contains(
        'community_report',
      );
      if (aIsServer != bIsServer) return aIsServer ? -1 : 1;
      return 0;
    });

    final List<Map<String, dynamic>> uniqueReports = [];
    final Set<String> seenSignatures = {};

    for (final report in rawReports) {
      final type = (report['event_type'] ?? report['title'] ?? '')
          .toString()
          .toLowerCase()
          .trim();
      final desc = (report['description'] ?? '')
          .toString()
          .toLowerCase()
          .trim();
      final created = (report['created'] ?? '').toString().trim();
      final timeSig = created.length > 16 ? created.substring(0, 16) : created;
      final signature = '${type}_${desc}_$timeSig';

      if (!seenSignatures.contains(signature)) {
        seenSignatures.add(signature);
        uniqueReports.add(report);
      }
    }

    _reports = uniqueReports;
  }

  /// Validates a citizen report on the backend and updates local storage state.
  Future<void> submitReportValidationAction(
    String targetReportId,
    String broadcastNotice,
  ) async {
    final String rawLeaderId =
        await DatabaseHelper.instance.getConfig('auth_leader_id') ?? '1';
    final int parsedLeaderId = int.tryParse(rawLeaderId.trim()) ?? 1;
    final String numericIdOnly = targetReportId.replaceAll(RegExp(r'\D'), '');
    final int? parsedIncidentId = int.tryParse(numericIdOnly);

    if (parsedIncidentId == null) {
      debugPrint(
        'Validation aborted: no valid numeric ID found in "$targetReportId"',
      );
      return;
    }

    final String resolvedNotice = broadcastNotice.trim().isNotEmpty
        ? broadcastNotice.trim()
        : 'Verified by sector community leader.';

    final Map<String, dynamic> validationPayload = {
      'id': parsedLeaderId,
      'validated_incidents': {parsedIncidentId.toString(): resolvedNotice},
      'notice': resolvedNotice,
    };

    try {
      const String injectedBaseUrl = String.fromEnvironment('BACKEND_URL');
      final List<String> targetBaseUrls = [
        if (injectedBaseUrl.isNotEmpty) injectedBaseUrl,
        'http://127.0.0.1:8000',
      ];

      for (final baseUrl in targetBaseUrls) {
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
              .timeout(const Duration(seconds: 5));

          if (response.statusCode == 200) {
            await DatabaseHelper.instance.updateNotificationStatus(
              targetReportId,
              'validated',
            );
            if (mounted) {
              setState(() {
                for (final item in _reports) {
                  if (item['id']?.toString() == targetReportId) {
                    item['status'] = 'validated';
                  }
                }
              });
            }
            DatabaseHelper.instance.syncNotifier.value++;
            break;
          } else {
            debugPrint(
              'Validation failed (${response.statusCode}): ${response.body}',
            );
          }
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Validation submission error: $e');
    }
  }

  /// Dispatches an announcement payload to the backend broadcast endpoint.
  Future<bool> _dispatchBroadcastMessage(String finalBroadcastMessage) async {
    try {
      final String rawLeaderId =
          await DatabaseHelper.instance.getConfig('auth_leader_id') ?? '1';
      final int parsedLeaderId = int.tryParse(rawLeaderId.trim()) ?? 1;

      final response = await _executeAdaptivePost(
        '/community-leader/publish-notification',
        body: {'id': parsedLeaderId, 'body': finalBroadcastMessage},
      );

      if (response.statusCode == 200) {
        await DatabaseHelper.instance.saveConfig(
          'last_live_announcement',
          finalBroadcastMessage.trim(),
        );
        DatabaseHelper.instance.syncNotifier.value++;
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Broadcast dispatch error: $e');
      return false;
    }
  }

  /// Opens a compact bottom-up animated modal showing active incidents or reports.
  void _openAnimatedListModal({
    required String barrierLabel,
    required Widget content,
    VoidCallback? onOpen,
  }) {
    if (!mounted) return;
    onOpen?.call();

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: barrierLabel,
      barrierColor: Colors.black.withValues(alpha: 0.28),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (context, animation, secondaryAnimation) {
        return SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
              child: Material(
                color: LeaderTheme.surfaceCard,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: LeaderTheme.border, width: 1),
                ),
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 420,
                    maxHeight: 460,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                    child: content,
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        return SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.35),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: FadeTransition(opacity: curvedAnimation, child: child),
        );
      },
    );
  }

  void _openActiveIncidentsModal() {
    final activeIds = _liveIncidents
        .map((item) => item['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty);

    _openAnimatedListModal(
      barrierLabel: 'Dismiss active incidents',
      onOpen: () => setState(() => _acknowledgedIncidentIds.addAll(activeIds)),
      content: ActiveIncidentsSection(liveIncidents: _liveIncidents),
    );
  }

  void _openCommunityReportsModal() {
    final activeReportIds = _reports
        .map((item) => item['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty);

    _openAnimatedListModal(
      barrierLabel: 'Dismiss community reports',
      onOpen: () =>
          setState(() => _acknowledgedReportIds.addAll(activeReportIds)),
      content: ValueListenableBuilder<int>(
        valueListenable: DatabaseHelper.instance.syncNotifier,
        builder: (_, _, _) {
          return ReportsLogSection(
            reports: _reports,
            onValidateReport: (String id, String notice) {
              submitReportValidationAction(id, notice);
            },
          );
        },
      ),
    );
  }

  void _openBroadcastDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          LeaderBroadcastDialog(onSendBroadcast: _dispatchBroadcastMessage),
    );
  }

  void _onNavigationTabSelected(int index) {
    if (index == _profileNavIndex) {
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const LoginPage()));

      return;
    }

    if (index == _homeNavIndex) {
      setState(() {
        _activeView = _LeaderViewMode.home;
        _selectedMapIncident = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: LeaderTheme.background,
      body: _buildBodyForCurrentView(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBodyForCurrentView() {
    switch (_activeView) {
      case _LeaderViewMode.map:
        return _buildFullScreenMapView();

      case _LeaderViewMode.plan:
        return SafeArea(
          child: RefreshIndicator(
            onRefresh: _syncLeaderDashboardPipeline,
            color: LeaderTheme.brandTeal,
            child: const SingleChildScrollView(
              physics: AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.all(16),
              child: CommunityPlanPanel(isLeader: true),
            ),
          ),
        );

      case _LeaderViewMode.home:
        return SafeArea(child: _buildHomeView());
    }
  }

  /// Builds the Community Leader overview layout anchored above the bottom bar.
  Widget _buildHomeView() {
    final int incidentCount = _liveIncidents.length;
    final int reportCount = _reports.length;

    final List activeIncidentIds = _liveIncidents
        .map((item) => item['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();

    final List activeReportIds = _reports
        .map((item) => item['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList();

    final bool hasUnseenIncidents = activeIncidentIds.any(
      (id) => !_acknowledgedIncidentIds.contains(id),
    );

    final bool hasUnseenReports = activeReportIds.any(
      (id) => !_acknowledgedReportIds.contains(id),
    );

    final String incidentSubtitle = incidentCount == 1
        ? '1 active incident'
        : '$incidentCount active incidents';

    final String reportSubtitle = reportCount == 1
        ? '1 community report'
        : '$reportCount community reports';

    return LayoutBuilder(
      builder: (context, constraints) {
        return RefreshIndicator(
          onRefresh: _syncLeaderDashboardPipeline,
          color: LeaderTheme.brandTeal,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: (constraints.maxHeight - 20).clamp(
                      0.0,
                      double.infinity,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      LeaderHeroHeader(
                        communityName: _communityName,
                        householdsCount: _householdsCount,
                        membersCount: _membersCount,
                      ),
                      const SizedBox(height: 12),
                      LeaderSummaryBanner(
                        title: 'Active Incidents',
                        subtitle: incidentSubtitle,
                        icon: Icons.warning_amber_rounded,
                        activeIconColor: LeaderTheme.warningAmber,
                        hasItems: incidentCount > 0,
                        showRunningBorder: hasUnseenIncidents,
                        showIconGlow: true,
                        beamPhaseOffset: 0.0,
                        onTap: _openActiveIncidentsModal,
                      ),
                      const SizedBox(height: 8),
                      LeaderSummaryBanner(
                        title: 'Community Reports',
                        subtitle: reportSubtitle,
                        icon: Icons.assignment_turned_in_outlined,
                        activeIconColor: LeaderTheme.reportBlue,
                        hasItems: reportCount > 0,
                        showRunningBorder: hasUnseenReports,
                        showIconGlow: true,
                        beamPhaseOffset: 0.5,
                        onTap: _openCommunityReportsModal,
                      ),
                      const SizedBox(height: 12),
                      LeaderQuickActionsGrid(
                        onMapTap: () =>
                            setState(() => _activeView = _LeaderViewMode.map),
                        onPlanTap: () =>
                            setState(() => _activeView = _LeaderViewMode.plan),
                        onBroadcastTap: _openBroadcastDialog,
                      ),
                      const SizedBox(height: 6),
                      GuestLocationFooter(
                        localityText: _localityLabel,
                        territoryText: _territoryLabel,
                        isLoading: _isLocating,
                        onTap: _refreshLocation,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Builds the edge-to-edge map view displaying active incidents and reports.
  Widget _buildFullScreenMapView() {
    final List<Map<String, dynamic>> allMarkers = [
      ..._liveIncidents,
      ..._reports,
    ];

    return LayoutBuilder(
      builder: (_, constraints) {
        final double safeHeight = constraints.maxHeight > 0
            ? constraints.maxHeight
            : 400.0;

        return Stack(
          children: [
            SizedBox(
              width: constraints.maxWidth,
              height: safeHeight,
              child: EmbeddedStreetMap(
                key: _mapKey,
                dynamicCenter: _deviceLocation,
                incidentMarkers: allMarkers,
                initialZoom: 10.0,
                height: safeHeight,
                onIncidentSelected: (incident) {
                  setState(() => _selectedMapIncident = incident);
                },
              ),
            ),
            if (_selectedMapIncident != null)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: GuestMapIncidentBubble(
                  incident: _selectedMapIncident!,
                  onClose: () => setState(() => _selectedMapIncident = null),
                ),
              ),
          ],
        );
      },
    );
  }

  /// Builds the two-tab bottom navigation bar (Home and Profile).
  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: LeaderTheme.navBackground,
        border: Border(top: BorderSide(color: LeaderTheme.border, width: 1)),
      ),
      child: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: LeaderTheme.navBackground,
          indicatorColor: Colors.transparent,
          height: 68,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final isSelected = states.contains(WidgetState.selected);
            return TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? LeaderTheme.brandTeal : LeaderTheme.textMuted,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final isSelected = states.contains(WidgetState.selected);
            return IconThemeData(
              color: isSelected ? LeaderTheme.brandTeal : LeaderTheme.textMuted,
              size: 24,
            );
          }),
        ),
        child: NavigationBar(
          selectedIndex: _homeNavIndex,
          onDestinationSelected: _onNavigationTabSelected,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_circle_outlined),
              selectedIcon: Icon(Icons.account_circle_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
