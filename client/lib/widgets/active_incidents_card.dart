import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import 'incident_tile.dart'; 

class ActiveIncidentsCard extends StatelessWidget {
  const ActiveIncidentsCard({super.key});

  @override
  Widget build(BuildContext context) {
    const Color cardBackground = Color(0xFF14171A); // Matte dark grey background profile
    const Color mintGreenAccent = Color(0xFF4DB6AC); // "See details" vibrant green color

    return Container(
      // Flat dark card profile matching your precise dashboard visual layout
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10, width: 1), // Thin structural framework lines
      ),
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
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(mintGreenAccent),
                    ),
                  ),
                );
              }

              final incidents = snapshot.data ?? [];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // FIXED: Removed the inline statusBlueChip row container item block
                  const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
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
                  const Divider(color: Colors.white10, height: 1), // Unified thin cross-separator line
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
                  else ...[
                    // RESTORED DESIGN EFFECT: Safely renders and labels individual incident elements via your original tiles loop mapping
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: incidents.length,
                      separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 24),
                      itemBuilder: (context, index) =>
                          IncidentTile(incident: incidents[index]),
                    ),
                    
                    const SizedBox(height: 12),
                    const Divider(color: Colors.white10, height: 1),
                    const SizedBox(height: 12),

                    // Bottom action row link using your green arrow setup layout parameters
                    InkWell(
                      onTap: () {
                        print('Active Incidents section action triggered.');
                      },
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.keyboard_arrow_down_rounded, color: mintGreenAccent, size: 18),
                          SizedBox(width: 4),
                          Text(
                            'Configure section',
                            style: TextStyle(
                              color: mintGreenAccent,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}
