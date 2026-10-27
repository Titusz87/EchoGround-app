import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import 'incident_tile.dart'; // 1. Added modern modular UI import links

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
