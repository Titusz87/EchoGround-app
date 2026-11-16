import 'package:flutter/material.dart';

import '../services/database_helper.dart';
import '../widgets/auth_dialog.dart';
import 'app_gatekeeper.dart';
import 'community_leader/leader_dashboard.dart';
import 'guest_mode/components/guest_theme.dart';
import 'household/household_dashboard.dart';

/// Account access screen allowing users to authenticate as a Household member
/// or Community Leader, or clear the active session back to Guest Mode.
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final ButtonStyle roleButtonStyle = ElevatedButton.styleFrom(
      backgroundColor: GuestTheme.surfaceElevated,
      foregroundColor: GuestTheme.textPrimary,
      iconColor: GuestTheme.accentCyan,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      shape: const StadiumBorder(
        side: BorderSide(color: GuestTheme.border, width: 1),
      ),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    );

    return Scaffold(
      backgroundColor: GuestTheme.background,
      appBar: AppBar(
        backgroundColor: GuestTheme.background,
        foregroundColor: GuestTheme.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Account Access',
          style: TextStyle(
            color: GuestTheme.textPrimary,
            fontSize: 19,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          const padding = EdgeInsets.all(24.0);
          final minHeight = constraints.maxHeight > padding.vertical
              ? constraints.maxHeight - padding.vertical
              : 0.0;

          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: SingleChildScrollView(
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
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: GuestTheme.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Select your role to continue',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14.5,
                          color: GuestTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 40),
                      ElevatedButton.icon(
                        style: roleButtonStyle,
                        icon: const Icon(Icons.home_rounded, size: 20),
                        label: const Text('Continue as Household'),
                        onPressed: () {
                          showLoginDialog(
                            context,
                            isLeader: false,
                            onAuthSuccess: () {
                              Navigator.pushAndRemoveUntil(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const HouseholdDashboard(),
                                ),
                                (route) => false,
                              );
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: roleButtonStyle,
                        icon: const Icon(Icons.groups_rounded, size: 20),
                        label: const Text('Continue as Community Leader'),
                        onPressed: () {
                          showLoginDialog(
                            context,
                            isLeader: true,
                            onAuthSuccess: () async {
                              final String storedName =
                                  await DatabaseHelper.instance.getConfig(
                                    'auth_community_name',
                                  ) ??
                                  await DatabaseHelper.instance.getConfig(
                                    'community_name',
                                  ) ??
                                  'Bruhejnya';

                              final String cleanCommunityName = storedName
                                  .trim();

                              if (context.mounted) {
                                Navigator.pushAndRemoveUntil(
                                  context,
                                  MaterialPageRoute(
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
                      const Divider(color: GuestTheme.border, thickness: 1),
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(
                            color: Colors.redAccent,
                            width: 1,
                          ),
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(vertical: 14),
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

                          if (!context.mounted) return;

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Session cleared successfully. Reverted to Guest Mode.',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              backgroundColor: GuestTheme.accentCyan,
                              duration: Duration(seconds: 3),
                            ),
                          );

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
              ),
            ),
          );
        },
      ),
    );
  }
}
