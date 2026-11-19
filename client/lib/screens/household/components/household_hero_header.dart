import 'dart:async';

import 'package:flutter/material.dart';

import 'household_theme.dart';

/// Displays the Households thin-stroke three-person vector emblem, title,
/// tagline, and a 5-second personalized welcome transition.
class HouseholdHeroHeader extends StatefulWidget {
  final String familyLastName;

  const HouseholdHeroHeader({super.key, required this.familyLastName});

  @override
  State<HouseholdHeroHeader> createState() => _HouseholdHeroHeaderState();
}

class _HouseholdHeroHeaderState extends State<HouseholdHeroHeader> {
  bool _showWelcomeMessage = true;
  Timer? _welcomeTimer;

  @override
  void initState() {
    super.initState();
    _welcomeTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() => _showWelcomeMessage = false);
      }
    });
  }

  @override
  void dispose() {
    _welcomeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String cleanedName = widget.familyLastName.trim();
    final bool hasFamilyName =
        cleanedName.isNotEmpty &&
        ![
          'unknown',
          'unknown household',
          '—',
        ].contains(cleanedName.toLowerCase());

    final String welcomeText = hasFamilyName
        ? 'Welcome back, $cleanedName family!'
        : 'Welcome back! Glad you’re here.';

    final String subtitleText = hasFamilyName
        ? '$cleanedName Household'
        : 'Preparedness & Alerts';

    return Column(
      children: [
        const SizedBox(
          width: 58,
          height: 46,
          child: CustomPaint(
            painter: _ThinHouseholdGroupPainter(
              color: HouseholdTheme.brandTeal,
              strokeWidth: 2.1,
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Households',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22.5,
            fontWeight: FontWeight.w700,
            color: HouseholdTheme.brandTeal,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 2),
        const Text(
          'Know your plan. Be ready.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: HouseholdTheme.textSecondary,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 18,
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
                    key: const ValueKey('household_welcome_msg'),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: HouseholdTheme.brandTeal,
                    ),
                  )
                : Text(
                    subtitleText,
                    key: const ValueKey('household_family_label'),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: HouseholdTheme.textMuted,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

/// Paints a thin-stroke vector emblem depicting three household members.
class _ThinHouseholdGroupPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const _ThinHouseholdGroupPainter({
    required this.color,
    this.strokeWidth = 2.1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Left member head & shoulder
    canvas.drawCircle(
      Offset(size.width * 0.23, size.height * 0.36),
      size.width * 0.08,
      strokePaint,
    );
    final leftShoulder = Path()
      ..moveTo(size.width * 0.11, size.height * 0.72)
      ..quadraticBezierTo(
        size.width * 0.11,
        size.height * 0.53,
        size.width * 0.24,
        size.height * 0.53,
      )
      ..quadraticBezierTo(
        size.width * 0.30,
        size.height * 0.53,
        size.width * 0.34,
        size.height * 0.57,
      );
    canvas.drawPath(leftShoulder, strokePaint);

    // Right member head & shoulder
    canvas.drawCircle(
      Offset(size.width * 0.77, size.height * 0.36),
      size.width * 0.08,
      strokePaint,
    );
    final rightShoulder = Path()
      ..moveTo(size.width * 0.89, size.height * 0.72)
      ..quadraticBezierTo(
        size.width * 0.89,
        size.height * 0.53,
        size.width * 0.76,
        size.height * 0.53,
      )
      ..quadraticBezierTo(
        size.width * 0.70,
        size.height * 0.53,
        size.width * 0.66,
        size.height * 0.57,
      );
    canvas.drawPath(rightShoulder, strokePaint);

    // Centre foreground figure head & closed shoulder loop
    canvas.drawCircle(
      Offset(size.width * 0.50, size.height * 0.25),
      size.width * 0.105,
      strokePaint,
    );
    final centreBody = Path()
      ..moveTo(size.width * 0.29, size.height * 0.76)
      ..quadraticBezierTo(
        size.width * 0.30,
        size.height * 0.45,
        size.width * 0.50,
        size.height * 0.45,
      )
      ..quadraticBezierTo(
        size.width * 0.70,
        size.height * 0.45,
        size.width * 0.71,
        size.height * 0.76,
      )
      ..close();
    canvas.drawPath(centreBody, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _ThinHouseholdGroupPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}
