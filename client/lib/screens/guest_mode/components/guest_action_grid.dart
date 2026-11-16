import 'package:flutter/material.dart';

import 'guest_theme.dart';

/// Quick Actions section providing two primary navigation cards for Guest Mode:
/// an active map launcher and an emergency information notice trigger.
class GuestActionGrid extends StatelessWidget {
  final VoidCallback onMapTap;

  const GuestActionGrid({super.key, required this.onMapTap});

  /// Displays a notice dialog when an unavailable action is selected.
  void _showUnavailableDialog(BuildContext context) {
    if (!context.mounted) return;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: GuestTheme.surfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: GuestTheme.border),
        ),
        title: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: GuestTheme.textSecondary),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Emergency Information',
                style: TextStyle(color: GuestTheme.textPrimary, fontSize: 17),
              ),
            ),
          ],
        ),
        content: const Text(
          'This feature is not available at the moment',
          style: TextStyle(color: GuestTheme.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text(
              'OK',
              style: TextStyle(
                color: GuestTheme.accentCyan,
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
          padding: EdgeInsets.only(left: 2, bottom: 10),
          child: Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: GuestTheme.textSecondary,
              letterSpacing: -0.1,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: _ActionTile(
                icon: Icons.location_on_rounded,
                iconColor: GuestTheme.accentCyan,
                label: 'View Map',
                textColor: GuestTheme.textSecondary,
                backgroundColor: GuestTheme.surfaceElevated,
                onTap: onMapTap,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _ActionTile(
                icon: Icons.info_rounded,
                iconColor: GuestTheme.iconDisabled,
                label: 'Emergency\nInformation',
                textColor: GuestTheme.textDisabled,
                backgroundColor: GuestTheme.surfaceDisabled,
                isDisabled: true,
                onTap: () => _showUnavailableDialog(context),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Interactive action card used inside [GuestActionGrid].
class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final Color textColor;
  final Color backgroundColor;
  final bool isDisabled;
  final VoidCallback onTap;

  const _ActionTile({
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
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          height: 112,
          padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDisabled
                  ? GuestTheme.border.withValues(alpha: 0.55)
                  : GuestTheme.border,
              width: 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Icon(icon, color: iconColor, size: 30),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
