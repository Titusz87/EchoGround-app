import 'package:flutter/material.dart';

import 'services/planning_service.dart';
import 'screens/household/household_plan_page.dart';
import 'screens/community_leader/community_plan_page.dart';
import 'widgets/planning_widgets.dart';

/// Deliberately separate from main.dart: no Firebase setup or real login calls.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _PlanningPreview());
}

class _PlanningPreview extends StatelessWidget {
  const _PlanningPreview();
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'EchoGround design preview',
    home: const _PreviewMenu(),
  );
}

class _PreviewMenu extends StatelessWidget {
  const _PreviewMenu();
  @override
  Widget build(BuildContext context) => PlanningShell(
    title: 'EchoGround design preview',
    child: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        if (!PlanningService.previewMode)
          const Text(
            'Preview is disabled. Run in debug mode with --dart-define=ECHOGROUND_PLANNING_PREVIEW=true.',
          )
        else ...[
          const Text(
            'Review the screens without a device ID or account.',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text(
            'Use fictional names and phone numbers. Data stays in this preview’s memory and resets when reloaded. Your normal app and saved accounts are not used.',
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.home_outlined),
            label: const Text('Household setup & checklists'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HouseholdPlanPage()),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            icon: const Icon(Icons.groups_outlined),
            label: const Text('Community setup & checklists'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CommunityPlanPage()),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'To preview sharing: set up the community first, then set up a household and choose that community under Security & privacy. Return to the community and refresh to see the opted-in summary and names.',
          ),
        ],
      ],
    ),
  );
}
