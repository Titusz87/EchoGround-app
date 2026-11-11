import 'package:flutter/material.dart';

class LeaderStatsHeader extends StatelessWidget {
  final String communityName;
  final String householdsCount;
  final String membersCount;

  const LeaderStatsHeader({
    super.key,
    required this.communityName,
    required this.householdsCount,
    required this.membersCount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Community $communityName',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Households: $householdsCount\nMembers: $membersCount',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.white60,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}
