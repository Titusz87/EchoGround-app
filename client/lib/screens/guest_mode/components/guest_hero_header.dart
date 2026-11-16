import 'package:flutter/material.dart';

import 'guest_theme.dart';

/// Displays the Guest Mode header emblem, screen title, and tagline.
class GuestHeroHeader extends StatelessWidget {
  const GuestHeroHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        SizedBox(
          width: 56,
          height: 56,
          child: CustomPaint(
            painter: _ThinOpenLockPainter(
              color: GuestTheme.accentCyan,
              strokeWidth: 2.2,
            ),
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Guest Mode',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.w700,
            color: GuestTheme.accentCyan,
            letterSpacing: -0.3,
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Stay informed. Be prepared.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: GuestTheme.textSecondary,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

/// Paints a thin-stroke unlocked padlock vector emblem.
class _ThinOpenLockPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;

  const _ThinOpenLockPainter({required this.color, this.strokeWidth = 2.2});

  @override
  void paint(Canvas canvas, Size size) {
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // Padlock body rectangle
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.21,
        size.height * 0.44,
        size.width * 0.58,
        size.height * 0.46,
      ),
      Radius.circular(size.width * 0.11),
    );
    canvas.drawRRect(bodyRect, strokePaint);

    // Open shackle arc
    final shackleRadius = size.width * 0.18;
    final shackleCenter = Offset(size.width * 0.50, size.height * 0.28);
    final shacklePath = Path()
      ..moveTo(
        shackleCenter.dx - shackleRadius,
        shackleCenter.dy + size.height * 0.03,
      )
      ..arcTo(
        Rect.fromCircle(center: shackleCenter, radius: shackleRadius),
        3.14159265,
        3.14159265,
        false,
      )
      ..lineTo(shackleCenter.dx + shackleRadius, size.height * 0.44);
    canvas.drawPath(shacklePath, strokePaint);

    // Center keyhole dot
    canvas.drawCircle(
      Offset(size.width * 0.50, size.height * 0.67),
      strokeWidth * 1.1,
      fillPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ThinOpenLockPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}
