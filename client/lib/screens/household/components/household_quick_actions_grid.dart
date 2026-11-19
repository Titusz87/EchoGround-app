import 'package:flutter/material.dart';

import 'household_theme.dart';

/// Compact 2x2 Quick Actions grid for Household users providing access to the
/// Map, Contacts, Preparedness Checklist/Plan, and Incident Reporting.
class HouseholdQuickActionsGrid extends StatelessWidget {
  final VoidCallback onMapTap;
  final VoidCallback onChecklistTap;
  final VoidCallback onReportTap;

  const HouseholdQuickActionsGrid({
    super.key,
    required this.onMapTap,
    required this.onChecklistTap,
    required this.onReportTap,
  });

  /// Displays a notice dialog when Contacts is selected.
  void _showContactsUnavailableDialog(BuildContext context) {
    if (!context.mounted) return;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: HouseholdTheme.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: HouseholdTheme.border),
        ),
        title: const Row(
          children: [
            Icon(
              Icons.info_outline_rounded,
              color: HouseholdTheme.textSecondary,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Emergency Contacts',
                style: TextStyle(
                  color: HouseholdTheme.textPrimary,
                  fontSize: 17,
                ),
              ),
            ),
          ],
        ),
        content: const Text(
          'This feature is not available at the moment',
          style: TextStyle(color: HouseholdTheme.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(
              'OK',
              style: TextStyle(
                color: HouseholdTheme.brandTeal,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 2, bottom: 6),
          child: Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: HouseholdTheme.textSecondary,
              letterSpacing: -0.1,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: _HouseholdActionTile(
                icon: Icons.location_on_rounded,
                iconColor: HouseholdTheme.brandTeal,
                label: 'Map',
                textColor: HouseholdTheme.textSecondary,
                backgroundColor: HouseholdTheme.surfaceElevated,
                onTap: onMapTap,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _HouseholdActionTile(
                icon: Icons.info_rounded,
                iconColor: HouseholdTheme.iconDisabled,
                label: 'Contacts',
                textColor: HouseholdTheme.textDisabled,
                backgroundColor: HouseholdTheme.surfaceDisabled,
                isDisabled: true,
                onTap: () => _showContactsUnavailableDialog(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _HouseholdActionTile(
                icon: Icons.checklist_rounded,
                iconColor: HouseholdTheme.brandTeal,
                label: 'Checklist',
                textColor: HouseholdTheme.textSecondary,
                backgroundColor: HouseholdTheme.surfaceElevated,
                onTap: onChecklistTap,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _HouseholdActionTile(
                icon: Icons.description_outlined,
                iconColor: HouseholdTheme.brandTeal,
                label: 'Report',
                textColor: HouseholdTheme.textSecondary,
                backgroundColor: HouseholdTheme.surfaceElevated,
                onTap: onReportTap,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Interactive compact horizontal action tile with aligned icon columns.
class _HouseholdActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final Color textColor;
  final Color backgroundColor;
  final bool isDisabled;
  final VoidCallback onTap;

  const _HouseholdActionTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.textColor,
    required this.backgroundColor,
    this.isDisabled = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDisabled
                  ? HouseholdTheme.border.withValues(alpha: 0.55)
                  : HouseholdTheme.border,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    height: 1.15,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
