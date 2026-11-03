import 'package:flutter/material.dart';

/// UI release switch. Keep false until community planning is ready for release.
/// This is feature availability, not a replacement for backend authorisation.
/// The noticeboard, official incident feed and map are independent of this flag.
const communityPlanningAvailable = false;

class CommunityComingSoon extends StatelessWidget {
  const CommunityComingSoon({super.key});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Community tools',
        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
      const SizedBox(height: 8),
      const Text(
        'Coming soon — planned for the next release. These tools are not enabled yet.',
      ),
      const SizedBox(height: 16),
      for (final feature in const <(IconData, String, String)>[
        (
          Icons.notifications_outlined,
          'Notifications',
          'Community notices and updates for linked households.',
        ),
        (
          Icons.fact_check_outlined,
          'Household preparedness plan',
          'Household preparedness summaries and completion status.',
        ),
        (
          Icons.privacy_tip_outlined,
          'Privacy & security',
          'Privacy and security options will be available in a future release.',
        ),
      ])
        Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(feature.$1),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        feature.$2,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(feature.$3),
                const SizedBox(height: 10),
                const Chip(label: Text('Coming soon')),
              ],
            ),
          ),
        ),
    ],
  );
}
