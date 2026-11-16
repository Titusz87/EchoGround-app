import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'guest_theme.dart';

/// Summary card displaying the active incident count with a decorative
/// topographic background pattern and an animated perimeter light for unread alerts.
class GuestActiveIncidentsBanner extends StatefulWidget {
  final int activeCount;
  final bool showRunningBorder;
  final VoidCallback onTap;

  const GuestActiveIncidentsBanner({
    super.key,
    required this.activeCount,
    this.showRunningBorder = false,
    required this.onTap,
  });

  @override
  State<GuestActiveIncidentsBanner> createState() =>
      _GuestActiveIncidentsBannerState();
}

class _GuestActiveIncidentsBannerState extends State<GuestActiveIncidentsBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _borderController;

  bool get _shouldAnimate => widget.activeCount > 0 && widget.showRunningBorder;

  @override
  void initState() {
    super.initState();
    _borderController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3400),
    );
    if (_shouldAnimate) {
      _borderController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant GuestActiveIncidentsBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_shouldAnimate && !_borderController.isAnimating) {
      _borderController.repeat();
    } else if (!_shouldAnimate && _borderController.isAnimating) {
      _borderController.stop();
    }
  }

  @override
  void dispose() {
    _borderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int safeCount = widget.activeCount < 0 ? 0 : widget.activeCount;
    final bool hasActiveIncidents = safeCount > 0;
    final String countLabel = safeCount == 1
        ? '1 active incident'
        : '$safeCount active incidents';
    final Color warningIconColor = hasActiveIncidents
        ? GuestTheme.warningAmber
        : GuestTheme.iconDisabled;

    return Stack(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(18),
            child: Ink(
              decoration: BoxDecoration(
                color: GuestTheme.surfaceCard,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: GuestTheme.border, width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  children: [
                    Positioned(
                      right: -10,
                      top: -10,
                      bottom: -10,
                      width: 150,
                      child: CustomPaint(painter: _TopographicLinesPainter()),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 20,
                      ),
                      child: Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: hasActiveIncidents
                                  ? [
                                      BoxShadow(
                                        color: GuestTheme.warningAmber
                                            .withValues(alpha: 0.14),
                                        blurRadius: 10,
                                        spreadRadius: 0,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Icon(
                              Icons.warning_amber_rounded,
                              color: warningIconColor,
                              size: 36,
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Active Incidents',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: GuestTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  countLabel,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    color: GuestTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: GuestTheme.accentCyan,
                            size: 26,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_shouldAnimate)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _borderController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _RunningBorderPainter(
                      progress: _borderController.value,
                      accentColor: GuestTheme.accentCyan,
                      borderRadius: 18,
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

/// Paints a smooth, continuous rotating light sweep along the card's border.
class _RunningBorderPainter extends CustomPainter {
  final double progress;
  final Color accentColor;
  final double borderRadius;

  const _RunningBorderPainter({
    required this.progress,
    required this.accentColor,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(0.75),
      Radius.circular(borderRadius),
    );

    final sweepGradient = SweepGradient(
      colors: [
        Colors.transparent,
        accentColor.withValues(alpha: 0.18),
        accentColor.withValues(alpha: 0.95),
        Colors.transparent,
      ],
      stops: const [0.0, 0.12, 0.24, 0.34],
      transform: GradientRotation(progress * 2 * math.pi),
    );

    final paint = Paint()
      ..shader = sweepGradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant _RunningBorderPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.accentColor != accentColor;
  }
}

/// Paints curved contour lines along the trailing edge of the incident card.
class _TopographicLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final paint = Paint()
      ..color = GuestTheme.accentTeal.withValues(alpha: 0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (int i = 0; i < 5; i++) {
      final double offset = i * 16.0;
      final path = Path()
        ..moveTo(size.width * 0.25 + offset, 0)
        ..quadraticBezierTo(
          size.width * 0.05 + offset,
          size.height * 0.45,
          size.width * 0.45 + offset,
          size.height * 0.65,
        )
        ..quadraticBezierTo(
          size.width * 0.85 + offset,
          size.height * 0.85,
          size.width * 0.55 + offset,
          size.height,
        );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
