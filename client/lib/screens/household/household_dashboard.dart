import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../services/database_helper.dart';
import '../../widgets/active_incidents_card.dart';
import '../../widgets/embedded_street_map.dart';
import '../../widgets/household/household_checklist_choice.dart';
import '../../widgets/incident_tile.dart';
import '../../widgets/report_dialog.dart';
import '../guest_mode/components/guest_location_footer.dart';
import '../guest_mode/components/guest_location_service.dart';
import '../guest_mode/components/guest_map_incident_bubble.dart';
import '../login_page.dart';
import 'components/household_announcement_bar.dart';
import 'components/household_hero_header.dart';
import 'components/household_quick_actions_grid.dart';
import 'components/household_summary_banners.dart';
import 'components/household_theme.dart';

/// Active sub-view rendered inside the Household dashboard.
enum _HouseholdViewMode { home, map, checklist }

/// Main dashboard screen for authenticated Household users.
///
/// Displays real-time community announcements, active official incidents with
/// an inline quick-view action, sector community reports, and quick navigation
/// to the sector map, preparedness checklist, and incident reporting.
class HouseholdDashboard extends StatefulWidget {
  const HouseholdDashboard({super.key});

  @override
  State<HouseholdDashboard> createState() => _HouseholdDashboardState();
}

class _HouseholdDashboardState extends State<HouseholdDashboard> {
  static const int _homeNavIndex = 0;
  static const int _profileNavIndex = 1;

  /// Persists acknowledged incident and report IDs across sub-views and rebuilds.
  static final Set<String> _acknowledgedIncidentIds = <String>{};
  static final Set<String> _acknowledgedReportIds = <String>{};

  final GlobalKey _mapKey = GlobalKey();
  final GuestLocationService _locationService = GuestLocationService();

  StreamSubscription<RemoteMessage>? _fcmSubscription;

  _HouseholdViewMode _activeView = _HouseholdViewMode.home;
  String _familyLastName = '';
  String _activeAnnouncementText = 'No active announcements';

  LatLng? _deviceLocation;
  String _localityLabel = 'Finding your location…';
  String _territoryLabel = '';
  bool _isLocating = false;
  Map<String, dynamic>? _selectedMapIncident;

  @override
  void initState() {
    super.initState();
    _loadHouseholdProfile();
    _recoverStoredAnnouncement();
    _establishRealtimeBannerListener();
    _refreshLocation();
  }

  @override
  void dispose() {
    _fcmSubscription?.cancel();
    super.dispose();
  }

  /// Loads the saved household family name from local configuration storage.
  Future<void> _loadHouseholdProfile() async {
    final lastName =
        await DatabaseHelper.instance.getConfig('household_last_name') ?? '';

    if (mounted) {
      setState(() => _familyLastName = lastName.trim());
    }
  }

  /// Restores the last active cloud announcement text from local storage.
  Future<void> _recoverStoredAnnouncement() async {
    final String? cachedAnnouncement = await DatabaseHelper.instance.getConfig(
      'last_live_announcement',
    );

    if (mounted &&
        cachedAnnouncement != null &&
        cachedAnnouncement.trim().isNotEmpty) {
      setState(() => _activeAnnouncementText = cachedAnnouncement.trim());
    }
  }

  /// Intercepts incoming FCM foreground announcement broadcast payloads.
  void _establishRealtimeBannerListener() {
    _fcmSubscription = FirebaseMessaging.onMessage.listen((message) {
      final Map<String, dynamic> cleanData = Map<String, dynamic>.from(
        message.data,
      );

      final String typeStr = (cleanData['type'] ?? '').toString();

      if (typeStr.contains('Announcement')) {
        final String? incomingBody =
            cleanData['Message']?.toString() ??
            cleanData['body']?.toString() ??
            cleanData['message']?.toString();

        if (incomingBody != null && mounted) {
          setState(() => _activeAnnouncementText = incomingBody.trim());
        }
      }
    });
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

  /// Splits cached notifications into official incidents and unique citizen reports.
  Future<
    ({List<Map<String, dynamic>> incidents, List<Map<String, dynamic>> reports})
  >
  _loadFilteredRecords() async {
    try {
      final rawList = await DatabaseHelper.instance.fetchAllNotifications();

      final incidents = rawList.where((item) {
        final id = item['id']?.toString() ?? '';
        final rawType = (item['event_type'] ?? item['type'] ?? '')
            .toString()
            .toLowerCase();

        return !id.startsWith('unknown_incident') &&
            !id.contains('community_report') &&
            !rawType.contains('announcement');
      }).toList();

      final rawReports = rawList.where((item) {
        final id = item['id']?.toString() ?? '';
        final typeStr = (item['event_type'] ?? item['type'] ?? '')
            .toString()
            .toLowerCase();
        final descStr = (item['description'] ?? '').toString().toLowerCase();
        final titleStr = (item['title'] ?? '').toString().toLowerCase();

        final bool isReportId =
            id.startsWith('unknown_incident') ||
            id.contains('community_report');

        final bool isAnnouncement =
            typeStr.contains('announcement') ||
            titleStr.contains('announcement') ||
            descStr.contains('linked context') ||
            descStr.contains('[linked');

        return isReportId && !isAnnouncement;
      }).toList();

      final List<Map<String, dynamic>> uniqueReports = [];
      final Set<String> seenSignatures = {};

      for (final r in rawReports) {
        final type = r['event_type']?.toString().toLowerCase().trim() ?? '';
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

      return (incidents: incidents, reports: uniqueReports);
    } catch (_) {
      return (
        incidents: const <Map<String, dynamic>>[],
        reports: const <Map<String, dynamic>>[],
      );
    }
  }

  /// Opens a compact bottom-up animated modal showing incidents or reports.
  void _openAnimatedListModal({
    required String barrierLabel,
    required Widget content,
    VoidCallback? onOpen,
  }) {
    if (!mounted) return;

    onOpen?.call();

    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: barrierLabel,
      barrierColor: Colors.black.withValues(alpha: 0.28),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, _, _) {
        return SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
              child: Material(
                color: HouseholdTheme.surfaceCard,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(
                    color: HouseholdTheme.border,
                    width: 1,
                  ),
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
      transitionBuilder: (_, animation, _, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );

        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.35),
            end: Offset.zero,
          ).animate(curvedAnimation),
          child: FadeTransition(opacity: curvedAnimation, child: child),
        );
      },
    );
  }

  void _openActiveIncidentsModal(List<Map<String, dynamic>> incidents) {
    final activeIds = incidents
        .map((item) => item['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty);

    _openAnimatedListModal(
      barrierLabel: 'Dismiss active incidents',
      onOpen: () => setState(() => _acknowledgedIncidentIds.addAll(activeIds)),
      content: const ActiveIncidentsCard(showCardChrome: false),
    );
  }

  void _openCommunityReportsModal(List<Map<String, dynamic>> reports) {
    final activeReportIds = reports
        .map((item) => item['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty);

    _openAnimatedListModal(
      barrierLabel: 'Dismiss community reports',
      onOpen: () =>
          setState(() => _acknowledgedReportIds.addAll(activeReportIds)),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Row(
            children: [
              Icon(
                Icons.assignment_turned_in_outlined,
                color: HouseholdTheme.reportBlue,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'COMMUNITY REPORTS FEED',
                style: TextStyle(
                  color: HouseholdTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (reports.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'No public community reports active in your sector.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: HouseholdTheme.textMuted,
                    fontSize: 13,
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: reports.length,
              separatorBuilder: (_, _) =>
                  const Divider(color: HouseholdTheme.border, height: 16),
              itemBuilder: (_, index) => IncidentTile(incident: reports[index]),
            ),
        ],
      ),
    );
  }

  /// Displays the full community announcement dialog.
  void _showAnnouncementDetails(String fallbackText) {
    showDialog(
      context: context,
      builder: (dialogContext) => FutureBuilder(
        future: DatabaseHelper.instance
            .getConfig('last_live_announcement')
            .then((v) => v ?? fallbackText),
        builder: (_, snapshot) {
          final contentText = snapshot.data ?? fallbackText;

          return AlertDialog(
            backgroundColor: HouseholdTheme.surfaceCard,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: HouseholdTheme.border),
            ),
            title: const Row(
              children: [
                Icon(Icons.campaign_outlined, color: HouseholdTheme.brandTeal),
                SizedBox(width: 8),
                Text(
                  'Community Announcement',
                  style: TextStyle(
                    color: HouseholdTheme.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            content: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: HouseholdTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: HouseholdTheme.border),
              ),
              child: SingleChildScrollView(
                child: Text(
                  contentText,
                  style: const TextStyle(
                    color: HouseholdTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    color: HouseholdTheme.brandTeal,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          );
        },
      ),
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
        _activeView = _HouseholdViewMode.home;
        _selectedMapIncident = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HouseholdTheme.background,
      body: _buildBodyForCurrentView(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBodyForCurrentView() {
    switch (_activeView) {
      case _HouseholdViewMode.map:
        return _buildFullScreenMapView();

      case _HouseholdViewMode.checklist:
        return const SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: HouseholdChecklistChoice(),
          ),
        );

      case _HouseholdViewMode.home:
        return SafeArea(child: _buildHomeView());
    }
  }

  /// Builds the scrollable Household overview layout anchored above the bottom bar.
  Widget _buildHomeView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - 8).clamp(
                    0.0,
                    double.infinity,
                  ),
                ),
                child: ValueListenableBuilder<int>(
                  valueListenable: DatabaseHelper.instance.syncNotifier,
                  builder: (_, _, _) {
                    return FutureBuilder<
                      ({
                        List<Map<String, dynamic>> incidents,
                        List<Map<String, dynamic>> reports,
                      })
                    >(
                      future: _loadFilteredRecords(),
                      builder: (_, snapshot) {
                        final incidents = snapshot.data?.incidents ?? const [];
                        final reports = snapshot.data?.reports ?? const [];

                        final activeIncidentIds = incidents
                            .map((e) => e['id']?.toString() ?? '')
                            .where((id) => id.isNotEmpty)
                            .toList();

                        final activeReportIds = reports
                            .map((e) => e['id']?.toString() ?? '')
                            .where((id) => id.isNotEmpty)
                            .toList();

                        final bool hasUnseenIncidents = activeIncidentIds.any(
                          (id) => !_acknowledgedIncidentIds.contains(id),
                        );

                        final bool hasUnseenReports = activeReportIds.any(
                          (id) => !_acknowledgedReportIds.contains(id),
                        );

                        return Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            HouseholdHeroHeader(
                              familyLastName: _familyLastName,
                            ),
                            const SizedBox(height: 6),
                            FutureBuilder<String>(
                              future: DatabaseHelper.instance
                                  .getConfig('last_live_announcement')
                                  .then((v) => v ?? _activeAnnouncementText),
                              builder: (_, annSnap) {
                                final currentAnnouncement =
                                    annSnap.data ?? _activeAnnouncementText;
                                return HouseholdAnnouncementBar(
                                  text: currentAnnouncement,
                                  onTap: () => _showAnnouncementDetails(
                                    currentAnnouncement,
                                  ),
                                );
                              },
                            ),
                            const SizedBox(height: 8),
                            HouseholdActiveIncidentsCard(
                              activeCount: incidents.length,
                              latestIncident: incidents.isNotEmpty
                                  ? incidents.first
                                  : null,
                              showRunningBorder: hasUnseenIncidents,
                              onCardTap: () =>
                                  _openActiveIncidentsModal(incidents),
                              onViewLatestTap: () =>
                                  _openActiveIncidentsModal(incidents),
                            ),
                            const SizedBox(height: 6),
                            HouseholdReportsFeedBanner(
                              reportCount: reports.length,
                              showRunningBorder: hasUnseenReports,
                              onTap: () => _openCommunityReportsModal(reports),
                            ),
                            const SizedBox(height: 8),
                            HouseholdQuickActionsGrid(
                              onMapTap: () => setState(
                                () => _activeView = _HouseholdViewMode.map,
                              ),
                              onChecklistTap: () => setState(
                                () =>
                                    _activeView = _HouseholdViewMode.checklist,
                              ),
                              onReportTap: () => showReportDialog(context),
                            ),
                            const SizedBox(height: 4),
                            GuestLocationFooter(
                              localityText: _localityLabel,
                              territoryText: _territoryLabel,
                              isLoading: _isLocating,
                              onTap: _refreshLocation,
                            ),
                          ],
                        );
                      },
                    );
                  },
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
    return ValueListenableBuilder(
      valueListenable: DatabaseHelper.instance.syncNotifier,
      builder: (_, _, _) {
        return FutureBuilder<
          ({
            List<Map<String, dynamic>> incidents,
            List<Map<String, dynamic>> reports,
          })
        >(
          future: _loadFilteredRecords(),
          builder: (_, snapshot) {
            final List<Map<String, dynamic>> allMarkers = [
              ...(snapshot.data?.incidents ?? const <Map<String, dynamic>>[]),
              ...(snapshot.data?.reports ?? const <Map<String, dynamic>>[]),
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
                          onClose: () =>
                              setState(() => _selectedMapIncident = null),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  /// Builds the two-tab bottom navigation bar (Home and Profile).
  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: HouseholdTheme.navBackground,
        border: Border(top: BorderSide(color: HouseholdTheme.border, width: 1)),
      ),
      child: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: HouseholdTheme.navBackground,
          indicatorColor: Colors.transparent,
          height: 68,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final isSelected = states.contains(WidgetState.selected);

            return TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected
                  ? HouseholdTheme.brandTeal
                  : HouseholdTheme.textMuted,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final isSelected = states.contains(WidgetState.selected);

            return IconThemeData(
              color: isSelected
                  ? HouseholdTheme.brandTeal
                  : HouseholdTheme.textMuted,
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
