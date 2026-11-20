import 'package:flutter/material.dart';

import 'guest_theme.dart';

/// Displays the Guest Mode thin-stroke open padlock vector, title, and tagline.
class GuestHeroHeader extends StatelessWidget {
  const GuestHeroHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 56,
          height: 56,
          child: CustomPaint(
            painter: _ThinOpenPadlockPainter(
              color: GuestTheme.accentCyan,
              strokeWidth: 2.2,
            ),
          ),
        ),
        SizedBox(height: 10),
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
            fontSize: 13.5,
            color: GuestTheme.textSecondary,
            fontWeight: FontWeight.w400,
          ),
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
