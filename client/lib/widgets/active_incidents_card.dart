import 'package:flutter/material.dart';

import '../services/database_helper.dart';
import 'incident_tile.dart';

class ActiveIncidentsCard extends StatelessWidget {
  const ActiveIncidentsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
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

                final incidents = snapshot.data ?? [];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cleaned up: Removed the manual refresh icon layout since it updates seamlessly now!
                    const Text(
                      '⚠ ACTIVE INCIDENTS',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('${incidents.length} active incidents'),
                    const SizedBox(height: 12),
                    if (incidents.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Text(
                            'No current incidents reported.',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
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
            );
          },
        ),
      ),
    );
  }
}
