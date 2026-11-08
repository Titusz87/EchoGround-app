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
                        final item = incidents[index];
                        final String currentStatus =
                            item['status']?.toString().toLowerCase() ??
                            'active';

                        // 🛠️ CHOSEN DESIGN PATHWAY: Colored highlight configurations matching the exact warning string
                        final bool isResolved =
                            currentStatus == 'completed' ||
                            currentStatus == 'safe';
                        final Color statusColor = isResolved
                            ? mintGreenAccent
                            : Colors.orangeAccent;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            IncidentTile(incident: item),

                            // 🛠️ FIXED CATCH-ALL INTERCEPTOR: Removed strict filtering rules.
                            // This will ALWAYS display a clean fallback card for any item in the database!
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
                                    color: Colors.white.withValues(alpha: 0.05),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Icon(
                                              isResolved
                                                  ? Icons.check_circle_outline
                                                  : Icons.warning_amber_rounded,
                                              color: statusColor,
                                              size: 14,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              (item['event_type'] ?? 'INCIDENT')
                                                  .toString()
                                                  .replaceAll('_', ' ')
                                                  .toUpperCase(),
                                              style: TextStyle(
                                                color: statusColor,
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                        // Badge layout indicator showing the exact raw status text cleanly
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: statusColor.withValues(
                                              alpha: 0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            currentStatus.toUpperCase(),
                                            style: TextStyle(
                                              color: statusColor,
                                              fontSize: 9,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      (item['description'] == null ||
                                              item['description']
                                                  .toString()
                                                  .trim()
                                                  .isEmpty)
                                          ? 'Incident logged with status: $currentStatus. Monitoring situation parameters.'
                                          : item['description'].toString(),
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
