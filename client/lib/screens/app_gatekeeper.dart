import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../services/database_helper.dart';
import 'community_leader/leader_dashboard.dart';
import 'guest_mode/components/guest_theme.dart';
import 'guest_mode/guest_mode_dashboard.dart';
import 'household/household_dashboard.dart';

/// Root startup gatekeeper displaying the EchoGround brand logo while
/// verifying server reachability and routing to the active role dashboard.
class AppGatekeeper extends StatefulWidget {
  const AppGatekeeper({super.key});

  @override
  State<AppGatekeeper> createState() => _AppGatekeeperState();
}

class _AppGatekeeperState extends State<AppGatekeeper> {
  String _statusMessage = 'Checking network & server connection…';
  bool _isFallbackNotice = false;

  @override
  void initState() {
    super.initState();
    _executeStartupSequence();
  }

  /// Runs the four-stage startup sequence (~8.4s total) and routes to the
  /// active role dashboard.
  Future<void> _executeStartupSequence() async {
    // Stage 1: Network & backend reachability check (~2.7s)
    await _pingBackendServer(minDisplayMs: 2700);
    if (!mounted) return;

    // Stage 2: Check for a saved Household or Community Leader session (~2.6s)
    setState(() {
      _statusMessage = 'Checking for registered account…';
    });

    final String leaderId =
        (await DatabaseHelper.instance.getConfig('auth_leader_id') ?? '')
            .trim();
    final String householdId =
        (await DatabaseHelper.instance.getConfig('auth_household_id') ?? '')
            .trim();
    final String communityName =
        (await DatabaseHelper.instance.getConfig('auth_community_name') ??
                await DatabaseHelper.instance.getConfig('community_name') ??
                'Bruhyna')
            .trim();

    await Future.delayed(const Duration(milliseconds: 2600));
    if (!mounted) return;

    if (leaderId.isNotEmpty) {
      _navigateWithFade(LeaderDashboard(communityFallback: communityName));
      return;
    }

    if (householdId.isNotEmpty) {
      _navigateWithFade(const HouseholdDashboard());
      return;
    }

    // Stage 3: Account lookup result notice (~1.6s)
    setState(() {
      _statusMessage = 'No registered account found for this device.';
    });

    await Future.delayed(const Duration(milliseconds: 1600));
    if (!mounted) return;

    // Stage 4: Transition to Guest Mode (~1.5s)
    setState(() {
      _statusMessage = 'Loading Guest Mode…';
    });

    try {
      await DatabaseHelper.instance.fetchAllNotifications();
    } catch (_) {}

    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    _navigateWithFade(const GuestModeDashboard());
  }

  /// Pings the configured backend URL with a graceful offline timeout.
  Future<void> _pingBackendServer({int minDisplayMs = 2700}) async {
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

  /// Smoothly dissolves the splash screen while scaling and sliding [destination]
  /// into view.
  void _navigateWithFade(Widget destination) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder<void>(
        transitionDuration: const Duration(milliseconds: 850),
        pageBuilder: (_, _, _) => destination,
        transitionsBuilder: (_, animation, _, child) {
          final curvedFade = CurvedAnimation(
            parent: animation,
            curve: const Interval(0.12, 1.0, curve: Curves.easeOutCubic),
          );

          final curvedSlide = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutQuart,
          );

          return FadeTransition(
            opacity: curvedFade,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.03),
                end: Offset.zero,
              ).animate(curvedSlide),
              child: ScaleTransition(
                scale: Tween<double>(
                  begin: 0.985,
                  end: 1.0,
                ).animate(curvedSlide),
                child: child,
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GuestTheme.background,
      body: Stack(
        children: [
          // Locked dead-center at exact native splash size and coordinates
          Center(
            child: Image.asset(
              'lib/assets/images/app/logo.png',
              width: 155,
              fit: BoxFit.contain,
            ),
          ),
          // Status row positioned cleanly below the centred logo
          Align(
            alignment: const Alignment(0, 0.34),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: SizedBox(
                height: 36,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 380),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.25),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: Row(
                    key: ValueKey(_statusMessage),
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.8,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            GuestTheme.accentCyan,
                          ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Flexible(
                        child: Text(
                          _statusMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12.5,
                            height: 1.35,
                            fontWeight: FontWeight.w500,
                            color: GuestTheme.accentCyan,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
