import 'package:flutter/material.dart';

import '../../../../widgets/incident_tile.dart';

class ActiveIncidentsSection extends StatelessWidget {
  final List<Map<String, dynamic>> liveIncidents;

  const ActiveIncidentsSection({super.key, required this.liveIncidents});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2225), // Clean background panel color match
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.orangeAccent,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'ACTIVE INCIDENTS',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (liveIncidents.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 16.0),
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
              itemCount: liveIncidents.length,
              separatorBuilder: (context, index) =>
                  const Divider(color: Colors.white10, height: 16),
              itemBuilder: (context, index) {
                return IncidentTile(incident: liveIncidents[index]);
              },
            ),
        ],
      ),
    );
  }
}
