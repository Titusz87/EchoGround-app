import 'package:flutter/material.dart';

import 'incident_source.dart';

/// Displays a single incident record with a category icon, verification badge,
/// summary line, and an expandable section for full metadata.
class IncidentTile extends StatefulWidget {
  final Map<String, dynamic> incident;
  const IncidentTile({super.key, required this.incident});

  @override
  State<IncidentTile> createState() => _IncidentTileState();
}

class _IncidentTileState extends State<IncidentTile> {
  static const Color _brandTeal = Color(0xFF01AC97);
  bool _expanded = false;

  IncidentSource get _source {
    final id = widget.incident['id']?.toString().toLowerCase().trim() ?? '';
    if (id.contains('test_incident')) return IncidentSource.test;
    if (id.contains('official_incident')) return IncidentSource.official;
    if (id.contains('community_report') || id.startsWith('unknown_incident')) {
      return IncidentSource.community;
    }
    return IncidentSource.unknown;
  }

  /// Maps an incident category or event type to a corresponding vector icon.
  IconData _categoryIcon(String? eventType) {
    final normalized = (eventType ?? '').toLowerCase().trim();
    if (normalized.contains('fire') || normalized.contains('bushfire')) {
      return Icons.local_fire_department_rounded;
    }
    if (normalized.contains('flood') || normalized.contains('water')) {
      return Icons.flood_rounded;
    }
    if (normalized.contains('cyclone') || normalized.contains('storm')) {
      return Icons.cyclone_rounded;
    }
    if (normalized.contains('heat')) {
      return Icons.thermostat_rounded;
    }
    if (normalized.contains('road') ||
        normalized.contains('vehicle') ||
        normalized.contains('accident')) {
      return Icons.directions_car_rounded;
    }
    if (normalized.contains('medical') || normalized.contains('emergency')) {
      return Icons.medical_services_rounded;
    }
    if (normalized.contains('info') || normalized.contains('notice')) {
      return Icons.info_outline_rounded;
    }
    if (normalized.contains('hazard')) {
      return Icons.fmd_bad_rounded;
    }
    return Icons.notifications_none_rounded;
  }

  String _capitalize(String? text) {
    if (text == null) return 'Incident';
    final trimmed = text.toString().trim().replaceAll('_', ' ');
    if (trimmed.isEmpty) return 'Incident';
    if (trimmed.length == 1) return trimmed.toUpperCase();
    return trimmed[0].toUpperCase() + trimmed.substring(1).toLowerCase();
  }

  String _prettyKey(String key) {
    if (key.trim().isEmpty) return '';
    return key
        .split('_')
        .where((w) => w.isNotEmpty)
        .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }

  String get _summaryLine {
    final i = widget.incident;
    final desc = i['description']?.toString().trim() ?? '';
    if (desc.isNotEmpty) return desc;
    final addr = i['address']?.toString().trim() ?? '';
    if (addr.isNotEmpty) return addr;
    return 'Active incident monitoring context tracking parameters.';
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.incident;
    final source = _source;

    final List<MapEntry<String, dynamic>> details = [];
    const List<String> hiddenKeys = ['id', 'latitude', 'longitude', 'state'];

    for (final entry in item.entries) {
      final valStr = entry.value?.toString().trim() ?? '';
      if (valStr.isNotEmpty && !hiddenKeys.contains(entry.key)) {
        details.add(entry);
      }
    }

    final String rawStatus =
        item['status']?.toString().toLowerCase().trim() ?? 'active';

    Color cardOverlayFill;
    Color statusAccentColor;
    String statusLabel;
    IconData statusIcon;

    if (rawStatus == 'validated' ||
        rawStatus == 'safe' ||
        rawStatus == 'controlled' ||
        rawStatus == 'completed') {
      cardOverlayFill = const Color(0xFF4DB6AC).withValues(alpha: 0.04);
      statusAccentColor = const Color(0xFF4DB6AC);
      statusLabel = 'VALIDATED';
      statusIcon = Icons.gpp_good_rounded;
    } else if (rawStatus == 'active' ||
        rawStatus == 'pending' ||
        rawStatus.isEmpty) {
      cardOverlayFill = const Color(0xFFFFB74D).withValues(alpha: 0.04);
      statusAccentColor = const Color(0xFFFFB74D);
      statusLabel = 'PENDING';
      statusIcon = Icons.gpp_maybe_rounded;
    } else {
      cardOverlayFill = const Color(0xFFEF5350).withValues(alpha: 0.03);
      statusAccentColor = const Color(0xFFEF5350);
      statusLabel = 'UNVALIDATED';
      statusIcon = Icons.gpp_bad_rounded;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: source == IncidentSource.community
            ? cardOverlayFill
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: source == IncidentSource.community
            ? Border.all(
                color: statusAccentColor.withValues(alpha: 0.18),
                width: 1,
              )
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _categoryIcon(item['event_type']?.toString()),
                color: _brandTeal,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _capitalize(item['event_type']?.toString()),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (source == IncidentSource.community)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusAccentColor.withValues(alpha: 0.12),
                    border: Border.all(
                      color: statusAccentColor.withValues(alpha: 0.35),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, color: statusAccentColor, size: 13),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          color: statusAccentColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                )
              else
                _SourceBadge(source: source),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 2.0),
            child: Text(
              _summaryLine,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: TextButton.styleFrom(
                padding: const EdgeInsets.only(left: 2.0),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: _brandTeal,
              ),
              onPressed: () => setState(() => _expanded = !_expanded),
              icon: Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                size: 18,
              ),
              label: Text(_expanded ? 'Hide details' : 'See details'),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: _expanded && details.isNotEmpty
                ? Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.015),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: details.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 115,
                                child: Text(
                                  '${_prettyKey(entry.key)}:',
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  entry.value.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  final IncidentSource source;
  const _SourceBadge({required this.source});

  @override
  Widget build(BuildContext context) {
    final String label;
    final Color color;
    switch (source) {
      case IncidentSource.test:
        label = 'TEST';
        color = Colors.lightBlueAccent;
      case IncidentSource.official:
        label = 'OFFICIAL';
        color = const Color(0xFF01AC97);
      case IncidentSource.community:
        label = 'COMMUNITY';
        color = Colors.amberAccent;
      case IncidentSource.unknown:
        label = 'ALERT';
        color = Colors.white54;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
