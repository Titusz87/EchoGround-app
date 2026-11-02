import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import 'models/community_notice.dart';
import 'services/noticeboard_source.dart';
import 'screens/community_noticeboard_page.dart';

/// Separate entry point: never initialises Firebase, device registration, account
/// storage or any backend connection. Normal main.dart remains unchanged.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _Preview());
}

class _Preview extends StatelessWidget {
  const _Preview();
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'EchoGround noticeboard preview',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(0xFFF7F4ED),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF8E321F),
        brightness: Brightness.light,
        primary: const Color(0xFF8E321F),
        surface: const Color(0xFFFFFDF8),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(minimumSize: const Size(48, 54)),
      ),
    ),
    home: const _Menu(),
  );
}

class _Menu extends StatefulWidget {
  const _Menu();
  @override
  State<_Menu> createState() => _MenuState();
}

class _MenuState extends State<_Menu> {
  final store = NoticeboardPreviewStore();
  late final publisher = PreviewNoticeboardSource(
    store,
    context: const NoticeboardContext(
      communityId: 'example-a',
      communityName: 'Example community',
      canPublish: true,
    ),
  );
  late final household = PreviewNoticeboardSource(
    store,
    context: const NoticeboardContext(
      communityId: 'example-a',
      communityName: 'Example community',
      canPublish: false,
    ),
  );
  late final unlinked = PreviewNoticeboardSource(
    store,
    context: const NoticeboardContext(
      communityId: null,
      communityName: '',
      canPublish: false,
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('EchoGround noticeboard preview')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 650),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            if (!kDebugMode)
              const Text(
                'This design preview is available in debug builds only.',
              )
            else ...[
              const Text(
                'Community updates, together',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Community preparedness and roll-call work is on hold. This preview focuses on publishing notices and reading them in the household version.',
              ),
              const SizedBox(height: 12),
              const Text(
                'Use fictional content. No accounts, device IDs or Firebase setup are needed. Posts stay in this preview’s memory and reset on reload. No push notifications are sent.',
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                icon: const Icon(Icons.edit_square),
                label: const Text('Community publisher view'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CommunityNoticeboardPage(source: publisher),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.home_outlined),
                label: const Text('Linked household view'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CommunityNoticeboardPage(source: household),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CommunityNoticeboardPage(source: unlinked),
                  ),
                ),
                child: const Text('Household with no linked community'),
              ),
              const SizedBox(height: 24),
              const Text(
                'Try it: publish an example notice in the publisher view, return here, then open the linked household view to read it. Backend posts and push notifications need the noticeboard API integration.',
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
