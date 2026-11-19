import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'household_theme.dart';

/// Active Incidents card with an optional inline latest-incident preview row
/// featuring a dedicated [View] pill button, amber icon glow, and perimeter sweep.
class HouseholdActiveIncidentsCard extends StatefulWidget {
  final int activeCount;
  final Map<String, dynamic>? latestIncident;
  final bool showRunningBorder;
  final VoidCallback onCardTap;
  final VoidCallback? onViewLatestTap;

  const HouseholdActiveIncidentsCard({
    super.key,
    required this.activeCount,
    this.latestIncident,
    this.showRunningBorder = false,
    required this.onCardTap,
    this.onViewLatestTap,
  });

  @override
  State<HouseholdActiveIncidentsCard> createState() =>
      _HouseholdActiveIncidentsCardState();
}

class _HouseholdActiveIncidentsCardState
    extends State<HouseholdActiveIncidentsCard>
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
  void didUpdateWidget(covariant HouseholdActiveIncidentsCard oldWidget) {
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
    final bool hasItems = widget.activeCount > 0;
    final String subtitle = widget.activeCount == 1
        ? '1 active incident'
        : '${widget.activeCount} active incidents';

    final String latestTitle =
        (widget.latestIncident?['event_type'] ??
                widget.latestIncident?['title'] ??
                'Active Alert')
            .toString();

    final String latestDesc =
        (widget.latestIncident?['description'] ??
                'No further details available at this time.')
            .toString();

    return Stack(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onCardTap,
            borderRadius: BorderRadius.circular(18),
            child: Ink(
              decoration: BoxDecoration(
                color: HouseholdTheme.surfaceCard,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: HouseholdTheme.border, width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  boxShadow: hasItems
                                      ? [
                                          BoxShadow(
                                            color: HouseholdTheme.warningAmber
                                                .withValues(alpha: 0.16),
                                            blurRadius: 10,
                                            spreadRadius: 0,
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Icon(
                                  Icons.warning_amber_rounded,
                                  color: hasItems
                                      ? HouseholdTheme.warningAmber
                                      : HouseholdTheme.iconDisabled,
                                  size: 32,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Active Incidents',
                                      style: TextStyle(
                                        fontSize: 15.5,
                                        fontWeight: FontWeight.w700,
                                        color: HouseholdTheme.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      subtitle,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: HouseholdTheme.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right_rounded,
                                color: HouseholdTheme.brandTeal,
                                size: 24,
                              ),
                            ],
                          ),

                          // Inline latest incident preview with View pill button
                          if (hasItems && widget.latestIncident != null) ...[
                            const Divider(
                              color: HouseholdTheme.border,
                              height: 18,
                              thickness: 1,
                            ),
                            Row(
                              children: [
                                const Icon(
                                  Icons.radar_rounded,
                                  color: HouseholdTheme.brandTeal,
                                  size: 24,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        latestTitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w700,
                                          color: HouseholdTheme.textSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        latestDesc,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          color: HouseholdTheme.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: HouseholdTheme.brandTeal,
                                    side: const BorderSide(
                                      color: HouseholdTheme.brandTeal,
                                      width: 1.2,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 6,
                                    ),
                                    minimumSize: const Size(0, 30),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed:
                                      widget.onViewLatestTap ??
                                      widget.onCardTap,
                                  child: const Text(
                                    'View',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
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
                      accentColor: HouseholdTheme.brandTeal,
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

/// Community Reports Feed summary card with cyan-blue icon glow and an
/// offset perimeter light sweep for unseen sector reports.
class HouseholdReportsFeedBanner extends StatefulWidget {
  final int reportCount;
  final bool showRunningBorder;
  final VoidCallback onTap;

  const HouseholdReportsFeedBanner({
    super.key,
    required this.reportCount,
    this.showRunningBorder = false,
    required this.onTap,
  });

  @override
  State<HouseholdReportsFeedBanner> createState() =>
      _HouseholdReportsFeedBannerState();
}

class _HouseholdReportsFeedBannerState extends State<HouseholdReportsFeedBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _borderController;

  bool get _shouldAnimate => widget.reportCount > 0 && widget.showRunningBorder;

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
  void didUpdateWidget(covariant HouseholdReportsFeedBanner oldWidget) {
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
    final bool hasReports = widget.reportCount > 0;

    final String subtitle = hasReports
        ? (widget.reportCount == 1
              ? '1 active community report in your sector'
              : '${widget.reportCount} active community reports in your sector')
        : 'No public community reports active in your sector.';

    return Stack(
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(18),
            child: Ink(
              decoration: BoxDecoration(
                color: HouseholdTheme.surfaceCard,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: HouseholdTheme.border, width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Stack(
                  children: [
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
                              boxShadow: hasReports
                                  ? [
                                      BoxShadow(
                                        color: HouseholdTheme.reportBlue
                                            .withValues(alpha: 0.16),
                                        blurRadius: 10,
                                        spreadRadius: 0,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Icon(
                              Icons.assignment_turned_in_outlined,
                              color: hasReports
                                  ? HouseholdTheme.reportBlue
                                  : HouseholdTheme.iconDisabled,
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Community Reports Feed',
                                  style: TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w700,
                                    color: HouseholdTheme.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: HouseholdTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: HouseholdTheme.brandTeal,
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
                      (_borderController.value + 0.5) % 1.0;

                  return CustomPaint(
                    painter: _RunningBorderPainter(
                      progress: shiftedProgress,
                      accentColor: HouseholdTheme.brandTeal,
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

/// Paints curved contour lines along the trailing edge of the summary cards.
class _TopographicLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final paint = Paint()
      ..color = HouseholdTheme.brandTealMuted.withValues(alpha: 0.14)
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
