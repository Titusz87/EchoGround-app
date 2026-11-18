import 'package:flutter/material.dart';

import 'leader_theme.dart';

/// Quick Actions 2x2 grid providing Community Leader access to the Map,
/// Contacts, Community Plan, and Broadcast wizard.
class LeaderQuickActionsGrid extends StatelessWidget {
  final VoidCallback onMapTap;
  final VoidCallback onPlanTap;
  final VoidCallback onBroadcastTap;

  const LeaderQuickActionsGrid({
    super.key,
    required this.onMapTap,
    required this.onPlanTap,
    required this.onBroadcastTap,
  });

  /// Displays a notice dialog when Contacts is selected.
  void _showContactsUnavailableDialog(BuildContext context) {
    if (!context.mounted) return;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: LeaderTheme.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: LeaderTheme.border),
        ),
        title: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: LeaderTheme.textSecondary),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Emergency Contacts',
                style: TextStyle(color: LeaderTheme.textPrimary, fontSize: 17),
              ),
            ),
          ],
        ),
        content: const Text(
          'This feature is not available at the moment',
          style: TextStyle(color: LeaderTheme.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(
              'OK',
              style: TextStyle(
                color: LeaderTheme.brandTeal,
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
          padding: EdgeInsets.only(left: 2, bottom: 8),
          child: Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: LeaderTheme.textSecondary,
              letterSpacing: -0.1,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _LeaderActionTile(
                icon: Icons.location_on_rounded,
                iconColor: LeaderTheme.brandTeal,
                label: 'Map',
                textColor: LeaderTheme.textSecondary,
                backgroundColor: LeaderTheme.surfaceElevated,
                onTap: onMapTap,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _LeaderActionTile(
                icon: Icons.info_rounded,
                iconColor: LeaderTheme.iconDisabled,
                label: 'Contacts',
                textColor: LeaderTheme.textDisabled,
                backgroundColor: LeaderTheme.surfaceDisabled,
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
              child: _LeaderActionTile(
                icon: Icons.assignment_rounded,
                iconColor: LeaderTheme.brandTeal,
                label: 'Plan',
                textColor: LeaderTheme.textSecondary,
                backgroundColor: LeaderTheme.surfaceElevated,
                onTap: onPlanTap,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _LeaderActionTile(
                icon: Icons.campaign_rounded,
                iconColor: LeaderTheme.brandTeal,
                label: 'Broadcast',
                textColor: LeaderTheme.textSecondary,
                backgroundColor: LeaderTheme.surfaceElevated,
                onTap: onBroadcastTap,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Interactive compact horizontal action tile with aligned icon columns.
class _LeaderActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final Color textColor;
  final Color backgroundColor;
  final bool isDisabled;
  final VoidCallback onTap;

  const _LeaderActionTile({
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
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDisabled
                  ? LeaderTheme.border.withValues(alpha: 0.55)
                  : LeaderTheme.border,
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
