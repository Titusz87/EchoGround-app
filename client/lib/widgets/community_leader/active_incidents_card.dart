import 'package:flutter/material.dart';

class ActiveIncidentsCard extends StatelessWidget {
  const ActiveIncidentsCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
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

            const Text('2 active incidents'),

            const SizedBox(height: 20),
// Make a /incidents endpoint call here and list them
            _IncidentItem(
              icon: '🔴',
              title: 'Bushfire',
              community: 'Wiradjuri Community',
              location: 'Bathurst, NSW',
              status: 'High risk · Updated 12:35 PM',
            ),

            const SizedBox(height: 20),

            _IncidentItem(
              icon: '🟠',
              title: 'Road Blockage',
              community: 'Yawuru Community',
              location: 'Broome, WA',
              status: 'Reported by household · 12:28 PM',
            ),

            const SizedBox(height: 20),

            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  // TODO: Open incidents
                },
                child: const Text('View incidents'),
              ),
            ),
          ],
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
