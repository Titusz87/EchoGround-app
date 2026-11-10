import 'package:flutter/material.dart';
import '../services/session_store.dart';
import 'household/household_dashboard.dart';
import 'community_leader/leader_dashboard.dart';
import 'guest_mode/guest_mode_dashboard.dart';
import 'login_page.dart';

/// Restore once per startup. Rebuilds do not start another session lookup.
class AppGatekeeper extends StatefulWidget {
  const AppGatekeeper({super.key});
  @override
  State<AppGatekeeper> createState() => _AppGatekeeperState();
}
class _AppGatekeeperState extends State<AppGatekeeper> {
  late Future<SavedSession?> session;
  @override
  void initState() { super.initState(); session = SessionStore.restore(); }
  @override
  Widget build(BuildContext context) => FutureBuilder<SavedSession?>(
    future: session,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(backgroundColor: Color(0xFF14171A), body: Center(child: CircularProgressIndicator()));
      }
      if (snapshot.hasError) {
        return Scaffold(backgroundColor: const Color(0xFF14171A), body: Center(child: Padding(
          padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Could not restore a single account session. Your saved plans have been kept.', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: () => setState(() => session = SessionStore.restore()), child: const Text('Retry')),
            TextButton(onPressed: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (_) => false), child: const Text('Choose account / Sign in')),
          ]),
        )));
      }
      final saved = snapshot.data;
      if (saved?.role == 'household') return const HouseholdDashboard();
      if (saved?.role == 'leader') return const LeaderDashboard();
      return const GuestModeDashboard();
    },
  );
}
