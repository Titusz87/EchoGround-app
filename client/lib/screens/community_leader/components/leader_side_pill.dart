import 'package:flutter/material.dart';

/// Vertical pill rail positioned on the left edge of the Leader dashboard screen.
class LeaderSidePill extends StatelessWidget {
  final int? sideIndex;
  final ValueChanged<int?> onChanged;
  final VoidCallback onOpenAnnouncementWizard;

  const LeaderSidePill({
    super.key,
    required this.sideIndex,
    required this.onChanged,
    required this.onOpenAnnouncementWizard,
  });

  Widget _buildRailIcon(
    BuildContext context, {
    required IconData icon,
    required IconData selectedIcon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return InkResponse(
      onTap: onTap,
      radius: 24,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: selected ? scheme.secondaryContainer : Colors.transparent,
        ),
        child: Icon(
          selected ? selectedIcon : icon,
          size: 22,
          color: selected
              ? scheme.onSecondaryContainer
              : scheme.onSurfaceVariant,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer
            .withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildRailIcon(
            context,
            icon: Icons.notifications_none_outlined,
            selectedIcon: Icons.notifications,
            selected: sideIndex == 1,
            onTap: () {
              onChanged(sideIndex == 1 ? null : 1);
              if (sideIndex != 1) onOpenAnnouncementWizard();
            },
          ),
          const SizedBox(height: 12),
          _buildRailIcon(
            context,
            icon: Icons.assignment_outlined,
            selectedIcon: Icons.assignment,
            selected: sideIndex == 2,
            onTap: () => onChanged(sideIndex == 2 ? null : 2),
          ),
        ],
      ),
    );
  }
}
