import 'package:flutter/material.dart';

import '../services/database_helper.dart';
import 'incident_tile.dart';

class ActiveIncidentsCard extends StatelessWidget {
  final bool showCardChrome;

  const ActiveIncidentsCard({super.key, this.showCardChrome = true});

  @override
  Widget build(BuildContext context) {
    const Color cardBackground = Color(0xFF14171A);
    const Color mintGreenAccent = Color(0xFF01AC97);

    return Container(
      padding: showCardChrome
          ? const EdgeInsets.all(16)
          : const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: showCardChrome
          ? BoxDecoration(
              color: cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white10, width: 1),
            )
          : null,
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

              //FILTER LAYER: Extract ONLY official/test incidents. Exclude community reports.
              final allNotifications = snapshot.data ?? [];
              final incidents = allNotifications.where((item) {
                final id = item['id']?.toString() ?? '';
                return !id.startsWith('unknown_incident') &&
                    !id.contains('community_report');
              }).toList();

              final Color headerWarningColor = incidents.isNotEmpty
                  ? const Color(0xFFF5C518)
                  : const Color(0xFF4F5D66);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: headerWarningColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
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
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: incidents.length > 2
                            ? 280.0
                            : double.infinity,
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        physics: incidents.length > 2
                            ? const ClampingScrollPhysics()
                            : const NeverScrollableScrollPhysics(),
                        itemCount: incidents.length,
                        separatorBuilder: (_, __) =>
                            const Divider(color: Colors.white10, height: 24),
                        itemBuilder: (context, index) {
                          return IncidentTile(incident: incidents[index]);
                        },
                      ),
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
