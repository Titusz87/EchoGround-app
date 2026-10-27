import 'package:flutter/material.dart';
import '../services/database_helper.dart'; // Adjust path based on your folder tree

class ActiveIncidentsCard extends StatefulWidget {
  const ActiveIncidentsCard({super.key});

  @override
  State<ActiveIncidentsCard> createState() => _ActiveIncidentsCardState();
}

class _ActiveIncidentsCardState extends State<ActiveIncidentsCard> {
  late Future<List<Map<String, dynamic>>> _incidentsFuture;

  @override
  void initState() {
    super.initState();
    _incidentsFuture = DatabaseHelper.instance.fetchAllNotifications();
  }

  void _refreshIncidents() {
    setState(() {
      _incidentsFuture = DatabaseHelper.instance.fetchAllNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _incidentsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            final incidents = snapshot.data ?? [];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '⚠ ACTIVE INCIDENTS',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20),
                      onPressed: _refreshIncidents,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text('${incidents.length} active incidents'),
                const SizedBox(height: 12),
                if (incidents.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'No current incidents reported.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: incidents.length,
                    separatorBuilder: (_, __) => const Divider(height: 24),
                    itemBuilder: (context, index) =>
                        IncidentTile(incident: incidents[index]),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// One incident: two summary lines + expandable "See details" section.
class IncidentTile extends StatefulWidget {
  final Map<String, dynamic> incident;
  const IncidentTile({super.key, required this.incident});

  @override
  State<IncidentTile> createState() => _IncidentTileState();
}

class _IncidentTileState extends State<IncidentTile> {
  bool _expanded = false;

  // ---- helpers -------------------------------------------------------------

  /// Classifies the incident by its id, e.g. "test_incident0",
  /// "official_incident12", "community_report3".
  IncidentSource get _source {
    final id = widget.incident['id']?.toString().toLowerCase() ?? '';
    if (id.contains('test_incident')) return IncidentSource.test;
    if (id.contains('official_incident')) return IncidentSource.official;
    if (id.contains('community_report')) return IncidentSource.community;
    return IncidentSource.unknown;
  }

  String _levelIcon(String? level) {
    if (level == null) return '⚪';
    final n = level.toLowerCase();
    if (n.contains('high') || n.contains('critical') || n.contains('red')) return '🔴';
    if (n.contains('medium') || n.contains('orange')) return '🟠';
    return '🟡';
  }

  String _capitalize(String? text) {
    if (text == null || text.isEmpty) return 'Unknown Incident';
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  String _prettyKey(String key) => key
      .split('_')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');

  /// Second summary line: description, else address, else status.
  String get _summaryLine {
    final i = widget.incident;
    for (final key in ['description', 'address']) {
      final v = i[key]?.toString().trim() ?? '';
      if (v.isNotEmpty) return v;
    }
    return '${_capitalize(i['status']?.toString())} · Active';
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
        // Line 1: severity + type + TEST / OFFICIAL badge
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

        // Line 2: short summary
        Text(_summaryLine, maxLines: 1, overflow: TextOverflow.ellipsis),

        // Toggle
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

        // Expandable details: every field that came with the object
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.topCenter,
          child: _expanded
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
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
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

enum IncidentSource { test, official, community, unknown }

class _SourceBadge extends StatelessWidget {
  final IncidentSource source;
  const _SourceBadge({required this.source});

  @override
  Widget build(BuildContext context) {
    final (IconData icon, String label, Color color) = switch (source) {
      IncidentSource.test => (Icons.bug_report, 'TEST', Colors.amber),
      IncidentSource.official => (Icons.verified, 'OFFICIAL', Colors.green),
      IncidentSource.community => (Icons.groups, 'COMMUNITY', Colors.lightBlue),
      IncidentSource.unknown => (Icons.help_outline, 'UNKNOWN', Colors.grey),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}
