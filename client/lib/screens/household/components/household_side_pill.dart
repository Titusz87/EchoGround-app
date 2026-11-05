import 'package:flutter/material.dart';

/// Vertical pill rail positioned on the left edge of the Household dashboard screen.
class HouseholdSidePill extends StatelessWidget {
  final int? sideIndex;
  final ValueChanged<int?> onChanged;

  const HouseholdSidePill({
    super.key,
    required this.sideIndex,
    required this.onChanged,
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
    final theme = Theme.of(context);
    final barColor =
        theme.navigationBarTheme.backgroundColor ??
        theme.colorScheme.surfaceContainer;

    return Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: barColor.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildRailIcon(
            context,
            icon: Icons.checklist_outlined,
            selectedIcon: Icons.checklist,
            selected: sideIndex == 0,
            onTap: () => onChanged(sideIndex == 0 ? null : 0),
          ),
          const SizedBox(height: 12),
          _buildRailIcon(
            context,
            icon: Icons.groups_outlined,
            selectedIcon: Icons.groups,
            selected: sideIndex == 1,
            onTap: () => onChanged(sideIndex == 1 ? null : 1),
          ),
        ],
      ),
    );
  }
}
