import 'package:flutter/material.dart';

import '../services/database_helper.dart';
import 'incident_tile.dart';

class ActiveIncidentsCard extends StatelessWidget {
  const ActiveIncidentsCard({super.key});

  @override
  Widget build(BuildContext context) {
    const Color cardBackground = Color(
      0xFF14171A,
    ); // Matte dark grey background profile
    const Color mintGreenAccent = Color(
      0xFF4DB6AC,
    ); // Vibrant theme accent highlight color

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white10,
          width: 1,
        ), // Thin structural layout boundaries
      ),
      child: ValueListenableBuilder<int>(
        // 1. Monitors real-time SQLite insertions and background sync updates
        valueListenable: DatabaseHelper.instance.syncNotifier,
        builder: (context, syncCount, _) {
          return FutureBuilder<List<Map<String, dynamic>>>(
            // 2. Automatically triggers a fresh query whenever syncCount ticks up
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
                  // Header Row Configuration
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
                  const Divider(
                    color: Colors.white10,
                    height: 1,
                  ), // Cross-separator line
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
                        final item = incidents[index];

                        // 🎯 DIAGNOSTIC LOGGER: Prints values directly to ensure mapping variables read successfully
                        debugPrint(
                          '⚙️ CARD RENDER CHECK: Processing index row ID: ${item['id']} | Status: ${item['status']} | Event Type: ${item['event_type']}',
                        );

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            IncidentTile(incident: item),

                            // 🛠️ FALLBACK UI INTERCEPTOR: Displays text metrics directly if IncidentTile is hiding "safe" values
                            if (item['status']?.toString().toLowerCase() ==
                                    'safe' ||
                                item['status']?.toString().toLowerCase() ==
                                    'validated')
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 8.0,
                                  left: 4.0,
                                ),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.03),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.05,
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.check_circle_outline,
                                            color: mintGreenAccent,
                                            size: 14,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            item['event_type']
                                                    ?.toString()
                                                    .replaceAll('_', ' ')
                                                    .toUpperCase() ??
                                                'INCIDENT',
                                            style: const TextStyle(
                                              color: mintGreenAccent,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        item['description'] ?? 'No further details available at this time.',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 13,
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        );
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
