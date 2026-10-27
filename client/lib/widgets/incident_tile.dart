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

  // ---- helpers -------------------------------------------------------------

  IncidentSource get _source {
    final id = widget.incident['id']?.toString().toLowerCase().trim() ?? '';
    if (id.contains('test_incident')) return IncidentSource.test;
    if (id.contains('official_incident')) return IncidentSource.official;
    if (id.contains('community_report')) return IncidentSource.community;
    return IncidentSource.unknown;
  }

  String _levelIcon(String? level) {
    if (level == null) return '⚪';
    final n = level.toLowerCase().trim();
    if (n.isEmpty || n == 'none') return '⚪';
    if (n.contains('high') || n.contains('critical') || n.contains('red')) return '🔴';
    if (n.contains('medium') || n.contains('orange') || n.contains('advice')) return '🟠';
    return '🟡';
  }

  String _capitalize(String? text) {
    if (text == null) return 'Unknown';
    final trimmed = text.toString().trim();
    if (trimmed.isEmpty) return 'Unknown';
    if (trimmed.length == 1) return trimmed.toUpperCase();
    return trimmed.toUpperCase() + trimmed.substring(1).toLowerCase();
  }

  String _prettyKey(String key) {
    if (key.trim().isEmpty) return '';
    return key
        .split('_')
        .where((w) => w.isNotEmpty)
        .map((w) => w.toUpperCase() + w.substring(1).toLowerCase())
        .join(' ');
  }

  String get _summaryLine {
    final i = widget.incident;
    for (final key in ['description', 'address']) {
      final v = i[key]?.toString().trim() ?? '';
      if (v.isNotEmpty) return v;
    }
    final statusVal = i['status']?.toString().trim() ?? '';
    return statusVal.isNotEmpty ? '${_capitalize(statusVal)} · Active' : 'Active Incident';
  }

  // ---- UI ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final item = widget.incident;
    final theme = Theme.of(context);
    final source = _source;

    final details = item.entries
        .where((e) => e.value != null && e.value.toString().trim().isNotEmpty)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${_levelIcon(item['warning_level']?.toString())} '
                '${_capitalize(item['event_type']?.toString())}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            _SourceBadge(source: source),
          ],
        ),
        const SizedBox(height: 4),
        Text(_summaryLine, maxLines: 1, overflow: TextOverflow.ellipsis),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 32),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () => setState(() => _expanded = !_expanded),
            icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 18),
            label: Text(_expanded ? 'Hide details' : 'See details'),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: _expanded
              ? Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(8),
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
                                width: 130,
                                child: Text(
                                  _prettyKey(e.key),
                                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                                ),
                              ),
                              Expanded(
                                child: SelectableText(
                                  e.value.toString(),
                                  style: const TextStyle(fontSize: 13),
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
    );
  }
}

class _SourceBadge extends StatelessWidget {
  final IncidentSource source;
  const _SourceBadge({required this.source});

  @override
  Widget build(BuildContext context) {
    Color badgeColor;
    String label;

    switch (source) {
      case IncidentSource.test:
        badgeColor = Colors.blue;
        label = 'TEST';
        break;
      case IncidentSource.official:
        badgeColor = Colors.redAccent;
        label = 'OFFICIAL';
        break;
      case IncidentSource.community:
        badgeColor = Colors.amber;
        label = 'COMMUNITY';
        break;
      case IncidentSource.unknown:
      default:
        badgeColor = Colors.grey;
        label = 'REPORT';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.2),
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
