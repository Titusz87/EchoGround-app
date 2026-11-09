import 'package:flutter/material.dart';

import 'incident_source.dart';

class IncidentTile extends StatefulWidget {
  final Map<String, dynamic> incident;
  const IncidentTile({super.key, required this.incident});

  @override
  State<IncidentTile> createState() => _IncidentTileState();
}

class _IncidentTileState extends State<IncidentTile> {
  bool _expanded = false;

  IncidentSource get _source {
    final id = widget.incident['id']?.toString().toLowerCase().trim() ?? '';
    if (id.contains('test_incident')) return IncidentSource.test;
    if (id.contains('official_incident')) return IncidentSource.official;
    if (id.contains('community_report') || id.startsWith('unknown_incident'))
      return IncidentSource.community;
    return IncidentSource.unknown;
  }

  String _levelIcon(String? level) {
    if (level == null) return '⚪';
    final n = level.toLowerCase().trim();
    if (n.isEmpty || n == 'none') return '⚪';
    if (n.contains('high') ||
        n.contains('critical') ||
        n.contains('red') ||
        n.contains('watch'))
      return '🔴';
    if (n.contains('medium') || n.contains('orange') || n.contains('advice'))
      return '🟠';
    return '🟡';
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

    // Filter out internal system keys for the expandable dropdown layout view loops
    final List<MapEntry<String, dynamic>> details = [];
    final List<String> hiddenKeys = ['id', 'latitude', 'longitude', 'state'];

    for (final entry in item.entries) {
      final valStr = entry.value?.toString().trim() ?? '';
      if (valStr.isNotEmpty && !hiddenKeys.contains(entry.key)) {
        details.add(entry);
      }
    }

    // THREE-STATE COLOR ACCENT & CHIP ENGINE LAYER DEFINITIONS
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
      cardOverlayFill = const Color(0xFF4DB6AC)
          .withOpacity(0.04); // Subtle premium mint green sheet tint
      statusAccentColor = const Color(0xFF4DB6AC);
      statusLabel = 'VALIDATED';
      statusIcon = Icons.gpp_good_rounded;
    } else if (rawStatus == 'active' ||
        rawStatus == 'pending' ||
        rawStatus == '') {
      cardOverlayFill = const Color(0xFFFFB74D)
          .withOpacity(0.04); // Muted caution warning yellow sheet tint
      statusAccentColor = const Color(0xFFFFB74D);
      statusLabel = 'PENDING';
      statusIcon = Icons.gpp_maybe_rounded;
    } else {
      cardOverlayFill = const Color(0xFFEF5350)
          .withOpacity(0.03); // Critical alert red sheet tint
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
            ? Border.all(color: statusAccentColor.withOpacity(0.18), width: 1)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_levelIcon(item['warning_level']?.toString())} '
                  '${_capitalize(item['event_type']?.toString())}', //  Always renders real emergency type values dynamically
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Dynamic verification state status chips
              if (source == IncidentSource.community)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusAccentColor.withOpacity(0.12),
                    border: Border.all(
                      color: statusAccentColor.withOpacity(0.35),
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
                _SourceBadge(source: source), // Preserves baseline labels safely for official/test channels
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
                foregroundColor: const Color(0xFF4DB6AC),
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
                      color: Colors.white.withOpacity(0.015),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Column(
                      children: [
                        for (final e in details)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  width: 120,
                                  child: Text(
                                    _prettyKey(e.key),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: SelectableText(
                                    e.value.toString(),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
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
    Color badgeColor = Colors.grey;
    String label = 'REPORT';

    if (source == IncidentSource.test) {
      badgeColor = Colors.blue;
      label = 'TEST';
    } else if (source == IncidentSource.official) {
      badgeColor = Colors.redAccent;
      label = 'OFFICIAL';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.15),
        border: Border.all(color: badgeColor, width: 1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: badgeColor,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
