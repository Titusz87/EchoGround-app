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
    _refreshIncidents();
  }

  void _refreshIncidents() {
    setState(() {
      _incidentsFuture = DatabaseHelper.instance.fetchAllNotifications();
    });
  }

  String _getIconForLevel(String? level) {
    if (level == null) return '⚪';
    final normalized = level.toLowerCase();
    if (normalized.contains('high') || normalized.contains('critical') || normalized.contains('red')) return '🔴';
    if (normalized.contains('medium') || normalized.contains('orange')) return '🟠';
    return '🟡';
  }

  String _capitalize(String? text) {
    if (text == null || text.isEmpty) return 'Unknown Incident';
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _incidentsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator()));
            }

            final incidents = snapshot.data ?? [];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text('⚠ ACTIVE INCIDENTS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20),
                      tooltip: 'Refresh incidents',
                      onPressed: _refreshIncidents, // Manual refresh anchor for testing!
                    )
                  ],
                ),
                const SizedBox(height: 4),
                Text('${incidents.length} active incidents'),
                const SizedBox(height: 20),

                if (incidents.isEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: Text("No current incidents reported.", style: TextStyle(color: Color(0xFF59655E)))),
                  ),
                ] else ...[
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: incidents.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 20),
                    itemBuilder: (context, index) {
                      final item = incidents[index];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${_getIconForLevel(item['warning_level']?.toString())} ${_capitalize(item['event_type']?.toString())}',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(item['description']?.toString() ?? 'No description available'),
                          Text(item['address']?.toString() ?? 'Unknown Location'),
                          const SizedBox(height: 4),
                          Text('${_capitalize(item['status']?.toString())} · Active', style: const TextStyle(fontSize: 13, color: Color(0xFF59655E))),
                        ],
                      );
                    },
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
