import 'dart:async';

import 'package:flutter/material.dart';

import '../../../services/database_helper.dart';
import 'leader_theme.dart';

/// Displays the Community Leader thin-stroke shield emblem, title, tagline,
/// and a 5-second personalized welcome message that transitions into the
/// community name and membership counts.
class LeaderHeroHeader extends StatefulWidget {
  final String communityName;
  final String householdsCount;
  final String membersCount;

  const LeaderHeroHeader({
    super.key,
    required this.communityName,
    required this.householdsCount,
    required this.membersCount,
  });

  @override
  State<LeaderHeroHeader> createState() => _LeaderHeroHeaderState();
}

class _LeaderHeroHeaderState extends State<LeaderHeroHeader> {
  bool _showWelcomeMessage = true;
  String _leaderName = '';
  Timer? _welcomeTimer;

  @override
  void initState() {
    super.initState();
    _loadLeaderName();
    _welcomeTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _showWelcomeMessage = false);
      }
    });
  }

  /// Reads the saved leader display name from local configuration storage.
  Future<void> _loadLeaderName() async {
    try {
      final rawName =
          await DatabaseHelper.instance.getConfig('auth_leader_name') ?? '';
      final trimmed = rawName.trim();
      if (mounted && trimmed.isNotEmpty && trimmed.toLowerCase() != 'unknown') {
        setState(() => _leaderName = trimmed);
      }
    } catch (_) {
      // Fall back to generic greeting if local config is unavailable
    }
  }

  @override
  void dispose() {
    _welcomeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String safeCommunity = widget.communityName.trim().isNotEmpty
        ? widget.communityName.trim()
        : 'Community';

    final String welcomeText = _leaderName.isNotEmpty
        ? 'Good to see you again, $_leaderName!'
        : 'Good to see you again!';

    return Column(
      children: [
        const SizedBox(
          width: 48,
          height: 48,
          child: CustomPaint(
            painter: _ThinShieldCheckPainter(
              color: LeaderTheme.brandTeal,
              strokeWidth: 2.1,
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Community Leader',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22.5,
            fontWeight: FontWeight.w700,
            color: LeaderTheme.brandTeal,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'Organise. Communicate. Support.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: LeaderTheme.textSecondary,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 12),
        // Fixed-height slot preventing layout shift between welcome and stats
        SizedBox(
          height: 32,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.2),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: _showWelcomeMessage
                  ? Text(
                      welcomeText,
                      key: const ValueKey('leader_welcome_block'),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: LeaderTheme.brandTeal,
                      ),
                    )
                  : Column(
                      key: const ValueKey('leader_community_block'),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 11,
                              color: LeaderTheme.textSecondary,
                            ),
                            children: [
                              const TextSpan(text: 'Your community: '),
                              TextSpan(
                                text: safeCommunity,
                                style: const TextStyle(
                                  color: LeaderTheme.brandTeal,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Households: ${widget.householdsCount}  •  Members: ${widget.membersCount}',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: LeaderTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Paints a thin-stroke shield emblem with a centred verification checkmark.
class _ThinShieldCheckPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const _ThinShieldCheckPainter({required this.color, this.strokeWidth = 2.1});

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final shieldPath = Path()
      ..moveTo(size.width * 0.50, size.height * 0.12)
      ..lineTo(size.width * 0.80, size.height * 0.24)
      ..lineTo(size.width * 0.80, size.height * 0.50)
      ..quadraticBezierTo(
        size.width * 0.80,
        size.height * 0.76,
        size.width * 0.50,
        size.height * 0.89,
      )
      ..quadraticBezierTo(
        size.width * 0.20,
        size.height * 0.76,
        size.width * 0.20,
        size.height * 0.50,
      )
      ..lineTo(size.width * 0.20, size.height * 0.24)
      ..close();

    canvas.drawPath(shieldPath, strokePaint);

    final checkPath = Path()
      ..moveTo(size.width * 0.37, size.height * 0.51)
      ..lineTo(size.width * 0.46, size.height * 0.60)
      ..lineTo(size.width * 0.64, size.height * 0.41);

    canvas.drawPath(checkPath, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _ThinShieldCheckPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}
