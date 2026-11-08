import 'package:flutter/material.dart';

import '../services/database_helper.dart';
import 'incident_tile.dart';

class ActiveIncidentsCard extends StatelessWidget {
  const ActiveIncidentsCard({super.key});

  @override
  Widget build(BuildContext context) {
    const Color cardBackground = Color(0xFF14171A);
    const Color mintGreenAccent = Color(0xFF4DB6AC);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10, width: 1),
      ),
      child: ValueListenableBuilder<int>(
        // ⚡ Listens directly to real-time database broadcast writes
        valueListenable: DatabaseHelper.instance.syncNotifier,
        builder: (context, syncCount, _) {
          return FutureBuilder<List<Map<String, dynamic>>>(
            future: DatabaseHelper.instance.fetchAllNotifications(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        mintGreenAccent,
                      ),
                    ),
                  ),
                );
              }

              final incidents = snapshot.data ?? [];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange,
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'ACTIVE INCIDENTS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${incidents.length} active incidents',
                    style: const TextStyle(
                      color: Colors.white38,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),

                  const SizedBox(height: 12),
                  const Divider(color: Colors.white10, height: 1),
                  const SizedBox(height: 12),

                  if (incidents.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(
                        child: Text(
                          'No current incidents reported.',
                          style: TextStyle(color: Colors.white38, fontSize: 13),
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: incidents.length,
                      separatorBuilder: (_, __) =>
                          const Divider(color: Colors.white10, height: 24),
                      itemBuilder: (context, index) {
                        return IncidentTile(incident: incidents[index]);
                      },
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
