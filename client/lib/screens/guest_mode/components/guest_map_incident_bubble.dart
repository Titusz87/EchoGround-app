import 'package:flutter/material.dart';

import 'guest_theme.dart';

/// Floating preview card displayed over the map when an incident marker is
/// selected, opening a modal sheet with full details when tapped.
class GuestMapIncidentBubble extends StatelessWidget {
  final Map<String, dynamic> incident;
  final VoidCallback onClose;

  const GuestMapIncidentBubble({
    super.key,
    required this.incident,
    required this.onClose,
  });

  String _resolveTitle() {
    final rawTitle =
        incident['event_type'] ??
        incident['title'] ??
        incident['type'] ??
        'Community Incident';
    final cleaned = rawTitle.toString().trim();
    return cleaned.isNotEmpty ? cleaned : 'Community Incident';
  }

  String _resolveStatus() {
    final rawStatus =
        incident['status'] ?? incident['severity'] ?? 'Active Alert';
    final cleaned = rawStatus.toString().trim();
    return cleaned.isNotEmpty ? cleaned : 'Active Alert';
  }

  String _resolveTimestamp() {
    final rawTime =
        incident['created'] ??
        incident['created_at'] ??
        incident['timestamp'] ??
        '';
    final cleaned = rawTime.toString().trim();
    if (cleaned.isEmpty) return 'Recently reported';
    return cleaned.length > 16 ? cleaned.substring(0, 16) : cleaned;
  }

  /// Opens a bottom sheet showing the full incident description and coordinates.
  void _showIncidentDetails(BuildContext context) {
    if (!context.mounted) return;

    final String title = _resolveTitle();
    final String status = _resolveStatus();
    final String timestamp = _resolveTimestamp();
    final String description =
        (incident['description'] ??
                incident['body'] ??
                incident['message'] ??
                'No additional details provided for this incident.')
            .toString()
            .trim();
    final String lat = incident['latitude']?.toString() ?? 'N/A';
    final String lng = incident['longitude']?.toString() ?? 'N/A';

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: GuestTheme.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: GuestTheme.warningAmber,
                  size: 26,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: GuestTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: GuestTheme.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _InfoChip(
                  icon: Icons.sensors_rounded,
                  label: status,
                  color: GuestTheme.warningAmber,
                ),
                _InfoChip(
                  icon: Icons.access_time_rounded,
                  label: timestamp,
                  color: GuestTheme.accentCyan,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: GuestTheme.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Text(
                description,
                style: const TextStyle(
                  color: GuestTheme.textSecondary,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(
                  Icons.my_location_rounded,
                  size: 14,
                  color: GuestTheme.textMuted,
                ),
                const SizedBox(width: 6),
                Text(
                  'Coordinates: $lat, $lng',
                  style: const TextStyle(
                    color: GuestTheme.textMuted,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showIncidentDetails(context),
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
          decoration: BoxDecoration(
            color: GuestTheme.surfaceCard.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: GuestTheme.warningAmber.withValues(alpha: 0.45),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: GuestTheme.warningAmber,
                size: 30,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _resolveTitle(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: GuestTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_resolveStatus()} · ${_resolveTimestamp()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: GuestTheme.textMuted,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Tap for full details',
                      style: TextStyle(
                        color: GuestTheme.accentCyan,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onClose,
                tooltip: 'Dismiss',
                icon: const Icon(
                  Icons.close_rounded,
                  color: GuestTheme.textMuted,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
