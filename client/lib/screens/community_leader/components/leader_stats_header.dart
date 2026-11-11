import 'package:flutter/material.dart';
import '../../../services/database_helper.dart';

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
        FutureBuilder<String?>(
          future: DatabaseHelper.instance.getConfig('auth_leader_name'),
          builder: (context, snapshot) {
            final name = (snapshot.data ?? '').trim();
            final hasName = name.isNotEmpty && name.toLowerCase() != 'unknown';
            return Text(
              hasName ? 'Welcome back, $name' : 'Welcome back',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
            );
          },
        ),
        const SizedBox(height: 6),
        Text(
          'Your community: $communityName',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: Colors.white60),
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
