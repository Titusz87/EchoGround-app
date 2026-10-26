import 'package:flutter/material.dart';
import '../services/database_helper.dart';

class ActiveIncidentsCard extends StatelessWidget {
  const ActiveIncidentsCard({super.key});

  // Maps the incoming warning level string to custom visual emojis
  String _getIconForLevel(String? level) {
    if (level == null) return '⚪';
    final normalized = level.toLowerCase();
    if (normalized.contains('high') || normalized.contains('critical') || normalized.contains('red')) {
      return '🔴';
    }
    if (normalized.contains('medium') || normalized.contains('orange') || normalized.contains('warning')) {
      return '🟠';
    }
    return '🟡';
  }

  // Capitalizes the text for the title look
  String _capitalize(String? text) {
    if (text == null || text.isEmpty) return 'Unknown Incident';
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          // Pulls the cached incident rows from SQLite instantly
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
                const Text(
                  '⚠ ACTIVE INCIDENTS',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),

                // Dynamic header showing exact count from the SQLite local cache
                Text('${incidents.length} active incidents'),
                const SizedBox(height: 20),

                if (incidents.isEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        "No current incidents reported in your area.",
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ),
                  ),
                ] else ...[
                  // Loops through each row stored in your SQLite database
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: incidents.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 20),
                    itemBuilder: (context, index) {
                      final item = incidents[index];
                      
                      return _IncidentItem(
                        icon: _getIconForLevel(item['warning_level']?.toString()),
                        title: _capitalize(item['event_type']?.toString()),
                        community: item['description']?.toString() ?? 'Checking status...',
                        location: item['address']?.toString() ?? 'Unknown Location',
                        status: '${_capitalize(item['status']?.toString())} · ${item['last_modified'] != null ? item['last_modified'].toString().substring(0, 10) : "Active"}',
                      );
                    },
                  ),
                ],

                const SizedBox(height: 20),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      // TODO: Open incidents view list
                    },
                    child: const Text('View incidents'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _IncidentItem extends StatelessWidget {
  final String icon;
  final String title;
  final String community;
  final String location;
  final String status;

  const _IncidentItem({
    required this.icon,
    required this.title,
    required this.community,
    required this.location,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$icon $title',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(community),
        Text(location),
        const SizedBox(height: 4),
        Text(
          status,
          style: const TextStyle(fontSize: 13),
        ),
      ],
    );
  }
}
