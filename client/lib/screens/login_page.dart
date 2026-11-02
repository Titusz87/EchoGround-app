import 'package:flutter/material.dart';

import '../widgets/echoground_banner.dart';
import 'household/household_dashboard.dart';
import 'community_leader/leader_dashboard.dart';
import '../widgets/auth_dialog.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('EchoGround'), centerTitle: true),
      body: EchoGroundPageBody(
        maxWidth: 560,
        padding: const EdgeInsets.all(24),
        children: [
          const EchoGroundBanner(),
          const SizedBox(height: 28),
          Column(
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
                  // Triggers the authentication modal popup explicitly configured for Households
                  showLoginDialog(
                    context,
                    isLeader: false,
                    onAuthSuccess: () {
                      // This success callback block fires automatically ONLY upon a valid API response code
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
                  // Triggers the authentication modal popup explicitly configured for Community Leaders
                  showLoginDialog(
                    context,
                    isLeader: true,
                    onAuthSuccess: () {
                      // This success callback block fires automatically ONLY upon a valid API response code
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LeaderDashboard(),
                        ),
                        (route) => false,
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
