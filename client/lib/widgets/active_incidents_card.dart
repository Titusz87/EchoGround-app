import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import 'incident_tile.dart'; 

class ActiveIncidentsCard extends StatelessWidget {
  const ActiveIncidentsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
<<<<<<< HEAD
        padding: const EdgeInsets.all(16),
        child: ValueListenableBuilder<int>(
          // 1. Monitor real-time SQLite data insertion broadcast events
          valueListenable: DatabaseHelper.instance.syncNotifier,
          builder: (context, syncCount, _) {
            return FutureBuilder<List<Map<String, dynamic>>>(
              // 2. Automatically triggers a fresh local query whenever syncCount ticks up
              future: DatabaseHelper.instance.fetchAllNotifications(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
=======
        padding: const EdgeInsets.all(20),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _incidentsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator()));
            }
>>>>>>> origin/feature/stephen

                final incidents = snapshot.data ?? [];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
<<<<<<< HEAD
                    // Cleaned up: Removed the manual refresh icon layout since it updates seamlessly now!
                    const Text(
                      '⚠ ACTIVE INCIDENTS',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
=======
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
>>>>>>> origin/feature/stephen
            );
          },
        ),
      ),
    );
  }
}
