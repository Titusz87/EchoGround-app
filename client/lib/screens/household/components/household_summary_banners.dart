import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'household_theme.dart';

/// Active Incidents card featuring an animated slide-down inline preview
/// for the latest incident, a dedicated [View] pill button, amber icon glow,
/// and a rotating perimeter light sweep for unseen alerts.
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
    final bool showPreview = hasItems && widget.latestIncident != null;

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
            borderRadius: BorderRadius.circular(16),
            child: Ink(
              decoration: BoxDecoration(
                color: HouseholdTheme.surfaceCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: HouseholdTheme.border, width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 9,
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
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Active Incidents',
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: HouseholdTheme.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  subtitle,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: HouseholdTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: HouseholdTheme.brandTeal,
                            size: 22,
                          ),
                        ],
                      ),

                      // Smooth slide-down expansion when an active incident arrives.
                      AnimatedSize(
                        duration: const Duration(milliseconds: 360),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topCenter,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 280),
                          switchInCurve: Curves.easeOut,
                          switchOutCurve: Curves.easeIn,
                          transitionBuilder: (child, animation) {
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, -0.15),
                                  end: Offset.zero,
                                ).animate(animation),
                                child: child,
                              ),
                            );
                          },
                          child: showPreview
                              ? Column(
                                  key: ValueKey(
                                    'incident_preview_${widget.latestIncident?['id'] ?? latestTitle}',
                                  ),
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Divider(
                                      color: HouseholdTheme.border,
                                      height: 12,
                                      thickness: 1,
                                    ),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.radar_rounded,
                                          color: HouseholdTheme.brandTeal,
                                          size: 22,
                                        ),
                                        const SizedBox(width: 12),
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
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color: HouseholdTheme
                                                      .textSecondary,
                                                ),
                                              ),
                                              Text(
                                                latestDesc,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color:
                                                      HouseholdTheme.textMuted,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor:
                                                HouseholdTheme.brandTeal,
                                            side: const BorderSide(
                                              color: HouseholdTheme.brandTeal,
                                              width: 1.2,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(9),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 4,
                                            ),
                                            minimumSize: const Size(0, 26),
                                            tapTargetSize: MaterialTapTargetSize
                                                .shrinkWrap,
                                          ),
                                          onPressed:
                                              widget.onViewLatestTap ??
                                              widget.onCardTap,
                                          child: const Text(
                                            'View',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                )
                              : const SizedBox.shrink(
                                  key: ValueKey('incident_preview_empty'),
                                ),
                        ),
                      ),
                    ],
                  ),
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
                      borderRadius: 16,
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

/// Compact Community Reports Feed summary card with cyan-blue icon glow
/// and an offset perimeter light sweep for unseen sector reports.
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
            borderRadius: BorderRadius.circular(16),
            child: Ink(
              decoration: BoxDecoration(
                color: HouseholdTheme.surfaceCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: HouseholdTheme.border, width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 9,
                  ),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: hasReports
                              ? [
                                  BoxShadow(
                                    color: HouseholdTheme.reportBlue.withValues(
                                      alpha: 0.16,
                                    ),
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
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Community Reports Feed',
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w700,
                                color: HouseholdTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: HouseholdTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: HouseholdTheme.brandTeal,
                        size: 22,
                      ),
                    ],
                  ),
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
                      borderRadius: 16,
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
