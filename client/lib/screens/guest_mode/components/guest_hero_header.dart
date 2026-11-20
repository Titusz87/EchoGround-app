import 'package:flutter/material.dart';

import 'guest_theme.dart';

/// Displays the Guest Mode thin-stroke open padlock vector, title, tagline,
/// and an optional animated startup status line during initial connection checks.
class GuestHeroHeader extends StatelessWidget {
  final String? statusMessage;

  const GuestHeroHeader({super.key, this.statusMessage});

  @override
  Widget build(BuildContext context) {
    final bool isChecking =
        statusMessage != null && statusMessage!.trim().isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 56,
          height: 56,
          child: CustomPaint(
            painter: _ThinOpenPadlockPainter(
              color: GuestTheme.accentCyan,
              strokeWidth: 2.2,
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Guest Mode',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w700,
            color: GuestTheme.accentCyan,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Stay informed. Be prepared.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.5,
            color: GuestTheme.textSecondary,
            fontWeight: FontWeight.w400,
          ),
        ),
        // Smoothly expands during startup checks and collapses once ready
        AnimatedSize(
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          child: isChecking
              ? Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: SizedBox(
                    height: 22,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 340),
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
                        key: ValueKey(statusMessage),
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
                              statusMessage!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: GuestTheme.accentCyan,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// Paints a thin-stroke open padlock vector matching the Guest Mode emblem.
class _ThinOpenPadlockPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const _ThinOpenPadlockPainter({required this.color, this.strokeWidth = 2.2});

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final dotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Open shackle arc on top
    final shacklePath = Path()
      ..moveTo(size.width * 0.36, size.height * 0.44)
      ..lineTo(size.width * 0.36, size.height * 0.29)
      ..arcToPoint(
        Offset(size.width * 0.64, size.height * 0.29),
        radius: Radius.circular(size.width * 0.14),
        clockwise: true,
      )
      ..lineTo(size.width * 0.64, size.height * 0.33);

    canvas.drawPath(shacklePath, strokePaint);

    // Rounded rectangular padlock body
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.27,
        size.height * 0.44,
        size.width * 0.46,
        size.height * 0.38,
      ),
      Radius.circular(size.width * 0.10),
    );
    canvas.drawRRect(bodyRect, strokePaint);

    // Centred keyhole dot
    canvas.drawCircle(
      Offset(size.width * 0.50, size.height * 0.63),
      size.width * 0.036,
      dotPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ThinOpenPadlockPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}
