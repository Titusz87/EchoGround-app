import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'leader_theme.dart';

/// Interactive status banner used for Active Incidents and Community Reports.
///
/// Renders a leading status icon, count subtitle, decorative topographic lines,
/// and an optional animated perimeter sweep when unread items exist.
class LeaderSummaryBanner extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color activeIconColor;
  final bool hasItems;
  final bool showRunningBorder;
  final bool showIconGlow;
  final double beamPhaseOffset;
  final VoidCallback onTap;

  const LeaderSummaryBanner({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.activeIconColor,
    required this.hasItems,
    this.showRunningBorder = false,
    this.showIconGlow = false,
    this.beamPhaseOffset = 0.0,
    required this.onTap,
  });

  @override
  State<LeaderSummaryBanner> createState() => _LeaderSummaryBannerState();
}

class _LeaderSummaryBannerState extends State<LeaderSummaryBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _borderController;

  bool get _shouldAnimate => widget.hasItems && widget.showRunningBorder;

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
  void didUpdateWidget(covariant LeaderSummaryBanner oldWidget) {
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
    final Color resolvedIconColor = widget.hasItems
        ? widget.activeIconColor
        : LeaderTheme.iconDisabled;

    return Stack(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(18),
            child: Ink(
              decoration: BoxDecoration(
                color: LeaderTheme.surfaceCard,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: LeaderTheme.border, width: 1),
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
                        horizontal: 18,
                        vertical: 11,
                      ),
                      child: Row(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow:
                                  (widget.hasItems && widget.showIconGlow)
                                  ? [
                                      BoxShadow(
                                        color: widget.activeIconColor
                                            .withValues(alpha: 0.16),
                                        blurRadius: 10,
                                        spreadRadius: 0,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Icon(
                              widget.icon,
                              color: resolvedIconColor,
                              size: 32,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.title,
                                  style: const TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w700,
                                    color: LeaderTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.subtitle,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: LeaderTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: LeaderTheme.brandTeal,
                            size: 24,
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
                  final double shiftedProgress =
                      (_borderController.value + widget.beamPhaseOffset) % 1.0;

                  return CustomPaint(
                    painter: _RunningBorderPainter(
                      progress: shiftedProgress,
                      accentColor: LeaderTheme.brandTeal,
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

/// Paints curved contour lines along the trailing edge of the summary card.
class _TopographicLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final paint = Paint()
      ..color = LeaderTheme.brandTealMuted.withValues(alpha: 0.14)
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
