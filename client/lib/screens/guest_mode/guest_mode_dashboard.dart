import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:maplibre_gl/maplibre_gl.dart';

import '../../services/database_helper.dart';
import '../../widgets/active_incidents_card.dart';
import '../../widgets/embedded_street_map.dart';
import '../login_page.dart';
import 'components/guest_action_grid.dart';
import 'components/guest_active_incidents_banner.dart';
import 'components/guest_hero_header.dart';
import 'components/guest_location_footer.dart';
import 'components/guest_location_service.dart';
import 'components/guest_map_incident_bubble.dart';
import 'components/guest_theme.dart';

/// Main dashboard screen for unauthenticated Guest Mode users.
///
/// Runs a focused three-step startup sequence on initial launch—checking
/// network connectivity, verifying server reachability, and syncing local
/// incident records—before smoothly revealing the full dashboard layout.
class GuestModeDashboard extends StatefulWidget {
  const GuestModeDashboard({super.key});

  @override
  State<GuestModeDashboard> createState() => _GuestModeDashboardState();
}

class _GuestModeDashboardState extends State<GuestModeDashboard>
    with SingleTickerProviderStateMixin {
  static const int _homeNavIndex = 0;
  static const int _profileNavIndex = 1;

  /// Persists acknowledged incident IDs across map navigation and logout transitions.
  static final Set<String> _acknowledgedIncidentIds = <String>{};

  /// Tracks whether the initial startup sequence has completed in this session.
  static bool _hasCompletedStartup = false;

  final GlobalKey _mapKey = GlobalKey();
  final GuestLocationService _locationService = GuestLocationService();

  late final AnimationController _revealController;
  late final Animation<double> _contentOpacity;
  late final Animation<Offset> _contentSlide;

  bool _isInitializing = !_hasCompletedStartup;
  String? _startupStatusText = !_hasCompletedStartup
      ? 'Checking network connection…'
      : null;

  List<String> _currentIncidentIds = const [];
  bool _isMapOpen = false;
  LatLng? _deviceLocation;
  String _localityLabel = 'Finding your location…';
  String _territoryLabel = '';
  bool _isLocating = false;
  Map<String, dynamic>? _selectedMapIncident;

  @override
  void initState() {
    super.initState();

    _revealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
      value: _hasCompletedStartup ? 1.0 : 0.0,
    );

    final curvedReveal = CurvedAnimation(
      parent: _revealController,
      curve: Curves.easeOutCubic,
    );

    _contentOpacity = curvedReveal;
    _contentSlide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(curvedReveal);

    _refreshLocation();

    if (!_hasCompletedStartup) {
      _runStartupSequence();
    }
  }

  @override
  void dispose() {
    _revealController.dispose();
    super.dispose();
  }

  /// Executes the three-stage startup sequence (~5s total) before revealing
  /// the full Guest Mode dashboard layout.
  Future<void> _runStartupSequence() async {
    // Stage 1: Network connectivity check (~1.6s)
    await Future.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;

    // Stage 2: Server reachability check (~1.8s)
    setState(() => _startupStatusText = 'Connecting to EchoGround server…');
    await _pingBackendServer(minDisplayMs: 1800);
    if (!mounted) return;

    // Stage 3: Incident dataset check (~1.6s)
    setState(() => _startupStatusText = 'Updating incident data…');
    await _loadIncidents();
    await Future.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;

    _hasCompletedStartup = true;
    setState(() {
      _startupStatusText = null;
      _isInitializing = false;
    });

    await _revealController.forward();
  }

  /// Performs a lightweight reachability check against the configured backend.
  Future<void> _pingBackendServer({int minDisplayMs = 1800}) async {
    const String injectedBaseUrl = String.fromEnvironment('BACKEND_URL');
    final List<String> candidates = [
      if (injectedBaseUrl.isNotEmpty) injectedBaseUrl,
      'http://127.0.0.1:8000',
    ];

    final stopwatch = Stopwatch()..start();

    for (final baseUrl in candidates) {
      try {
        final cleanUrl = baseUrl.endsWith('/')
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl;
        await http
            .get(Uri.parse('$cleanUrl/'))
            .timeout(const Duration(seconds: 2));
        break;
      } catch (_) {}
    }

    final remainingMs = minDisplayMs - stopwatch.elapsedMilliseconds;
    if (remainingMs > 0) {
      await Future.delayed(Duration(milliseconds: remainingMs));
    }
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

  /// Fetches official active incidents from SQLite/Web cache, excluding
  /// announcements and unvalidated community reports.
  Future<List<Map<String, dynamic>>> _loadIncidents() async {
    try {
      final rawNotifications = await DatabaseHelper.instance
          .fetchAllNotifications();

      return rawNotifications.where((item) {
        final id = item['id']?.toString() ?? '';
        final rawType = item['event_type'] ?? item['type'] ?? '';
        final normalizedType = rawType.toString().toLowerCase();

        return !id.startsWith('unknown_incident') &&
            !id.contains('community_report') &&
            !normalizedType.contains('announcement');
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Opens a compact bottom-up animated modal displaying the active incident list.
  void _openActiveIncidentsSheet() {
    if (!mounted) return;

    setState(() {
      _acknowledgedIncidentIds.addAll(_currentIncidentIds);
    });

    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss active incidents',
      barrierColor: Colors.black.withValues(alpha: 0.28),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (_, _, _) {
        return SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
              child: Material(
                color: GuestTheme.surfaceCard,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: GuestTheme.border, width: 1),
                ),
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 400,
                    maxHeight: 440,
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
                    child: const ActiveIncidentsCard(showCardChrome: false),
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

  /// Handles bottom navigation selection between Home and Profile.
  void _onNavigationTabSelected(int index) {
    if (index == _profileNavIndex) {
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => const LoginPage()));
      return;
    }

    if (index == _homeNavIndex) {
      setState(() {
        _isMapOpen = false;
        _selectedMapIncident = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GuestTheme.background,
      body: _isMapOpen
          ? _buildFullScreenMapView()
          : SafeArea(child: _buildHomeView()),
      bottomNavigationBar: _isInitializing
          ? null
          : FadeTransition(opacity: _contentOpacity, child: _buildBottomNav()),
    );
  }

  /// Builds the centered startup splash state that transitions smoothly into
  /// the full Guest Mode overview layout.
  Widget _buildHomeView() {
    if (_isInitializing) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: GuestHeroHeader(statusMessage: _startupStatusText),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 36),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - 52).clamp(
                    0.0,
                    double.infinity,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GuestHeroHeader(statusMessage: _startupStatusText),
                    const SizedBox(height: 22),
                    FadeTransition(
                      opacity: _contentOpacity,
                      child: SlideTransition(
                        position: _contentSlide,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ValueListenableBuilder(
                              valueListenable:
                                  DatabaseHelper.instance.syncNotifier,
                              builder: (_, _, _) {
                                return FutureBuilder<
                                  List<Map<String, dynamic>>
                                >(
                                  future: _loadIncidents(),
                                  builder: (_, snapshot) {
                                    final List<Map<String, dynamic>> incidents =
                                        snapshot.hasError
                                        ? const []
                                        : (snapshot.data ?? const []);

                                    final int incidentCount = incidents.length;

                                    final List<String> activeIds = incidents
                                        .map(
                                          (item) =>
                                              item['id']?.toString() ?? '',
                                        )
                                        .where((id) => id.isNotEmpty)
                                        .toList();

                                    _currentIncidentIds = activeIds;

                                    final bool hasUnseenIncidents = activeIds
                                        .any(
                                          (id) => !_acknowledgedIncidentIds
                                              .contains(id),
                                        );

                                    return GuestActiveIncidentsBanner(
                                      activeCount: incidentCount,
                                      showRunningBorder: hasUnseenIncidents,
                                      onTap: _openActiveIncidentsSheet,
                                    );
                                  },
                                );
                              },
                            ),
                            const SizedBox(height: 18),
                            GuestActionGrid(
                              onMapTap: () => setState(() => _isMapOpen = true),
                            ),
                            const SizedBox(height: 16),
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
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Builds the full-screen map view with an interactive incident preview card.
  Widget _buildFullScreenMapView() {
    return ValueListenableBuilder(
      valueListenable: DatabaseHelper.instance.syncNotifier,
      builder: (_, _, _) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _loadIncidents(),
          builder: (_, snapshot) {
            final List<Map<String, dynamic>> incidentList = snapshot.hasError
                ? const []
                : (snapshot.data ?? const []);

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
                        incidentMarkers: incidentList,
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

  /// Builds the bottom navigation bar.
  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: GuestTheme.navBackground,
        border: Border(top: BorderSide(color: GuestTheme.border, width: 1)),
      ),
      child: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: GuestTheme.navBackground,
          indicatorColor: Colors.transparent,
          height: 68,
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            final isSelected = states.contains(WidgetState.selected);

            return TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? GuestTheme.accentCyan : GuestTheme.textMuted,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            final isSelected = states.contains(WidgetState.selected);

            return IconThemeData(
              color: isSelected ? GuestTheme.accentCyan : GuestTheme.textMuted,
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
