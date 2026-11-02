import 'package:flutter/material.dart';

import '../services/noticeboard_source.dart';
import '../screens/community_noticeboard_page.dart';

/// Add to either dashboard and supply its authenticated backend adapter.
/// Membership and publishing permissions are loaded from the adapter, not from
/// an isLeader switch or a freely chosen community dropdown.
class CommunityNoticeboardEntry extends StatelessWidget {
  const CommunityNoticeboardEntry({super.key, required this.source});
  final NoticeboardSource source;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.campaign_outlined),
      title: const Text('Community noticeboard'),
      subtitle: const Text('View updates from your linked community'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CommunityNoticeboardPage(source: source),
        ),
      ),
    ),
  );
}
