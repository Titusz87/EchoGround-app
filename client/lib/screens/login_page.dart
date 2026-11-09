import 'package:flutter/material.dart';

import 'household/household_dashboard.dart';
import 'community_leader/leader_dashboard.dart';
import '../widgets/auth_dialog.dart';
import '../services/database_helper.dart';
import 'app_gatekeeper.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account Access'), centerTitle: true),
      body: LayoutBuilder(
        builder: (context, constraints) {
          const padding = EdgeInsets.all(24.0);
          final minHeight = constraints.maxHeight > padding.vertical
              ? constraints.maxHeight - padding.vertical
              : 0.0;
          return SingleChildScrollView(
            padding: padding,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Welcome to EchoGround',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 12),

                  const Text(
                    'Select your role to continue',
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 40),

                  ElevatedButton.icon(
                    icon: const Icon(Icons.home),
                    label: const Text('Continue as Household'),
                    onPressed: () {
                      showLoginDialog(
                        context,
                        isLeader: false,
                        onAuthSuccess: () {
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const HouseholdDashboard(),
                            ),
                            (route) => false,
                          );
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  ElevatedButton.icon(
                    icon: const Icon(Icons.groups),
                    label: const Text('Continue as Community Leader'),
                    onPressed: () {
                      showLoginDialog(
                        context,
                        isLeader: true,
                        onAuthSuccess: () async {
                          // MULTI-KEY SANITIZER GATEWAY:
                          // Read all possible config keys immediately after authentication callback triggers
                          final String storedName =
                              await DatabaseHelper.instance.getConfig(
                                'auth_community_name',
                              ) ??
                              await DatabaseHelper.instance.getConfig(
                                'community_name',
                              ) ??
                              'Bruhejnya';

                          // Explicitly strip away hidden carriage returns, \n, or trailing whitespace parameters
                          final String cleanCommunityName = storedName.trim();

                          if (context.mounted) {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                // DIRECT DATA HANDSHAKE: Passes the sanitized string value explicitly to the constructor,
                                // completely bypassing async race conditions on disk!
                                builder: (context) => LeaderDashboard(
                                  communityFallback: cleanCommunityName,
                                ),
                              ),
                              (route) => false,
                            );
                          }
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 40),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 24),

                  // ADDED COMPONENT: INTEGRATED ACTIVE LOG OUT BUTTON MODULE
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent, width: 1),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text(
                      'Log Out / Exit Account Session',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed: () async {
                      await DatabaseHelper.instance.saveConfig(
                        'auth_household_id',
                        '',
                      );
                      await DatabaseHelper.instance.saveConfig(
                        'auth_leader_id',
                        '',
                      );
                      await DatabaseHelper.instance.saveConfig(
                        'household_last_name',
                        '',
                      );
                      await DatabaseHelper.instance.saveConfig(
                        'household_count',
                        '',
                      );
                      await DatabaseHelper.instance.saveConfig(
                        'auth_community_name',
                        '',
                      );
                      await DatabaseHelper.instance.saveConfig(
                        'community_name',
                        '',
                      );

                      DatabaseHelper.instance.syncNotifier.value++;

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              'Session cleared successfully. Reverted to Guest Mode.',
                              style: TextStyle(
                                color: Color.fromARGB(255, 30, 30, 30),
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                            backgroundColor: Colors.tealAccent.shade400,
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      }

                      // FIXED ROUTING: Instead of just popping the overlay, it forces the entire application
                      // to re-evaluate through the AppGatekeeper. This drops the UI back into your real Guest Mode dashboard
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const AppGatekeeper(),
                        ),
                        (route) => false,
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
