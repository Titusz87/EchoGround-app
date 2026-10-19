import 'package:flutter/material.dart';
import 'household/household_dashboard.dart';
import 'community_leader/leader_dashboard.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('CountryReady.ai'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Welcome to CountryReady.ai',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
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
                // pushRenoveUntil is used to clear stack tracking
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HouseholdDashboard(),
                  ),
                  (route) => false,
                );
              },
            ),

            const SizedBox(height: 16),

            ElevatedButton.icon(
              icon: const Icon(Icons.groups),
              label: const Text('Continue as Community Leader'),
              onPressed: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LeaderDashboard(),
                  ),
                  (route) => false,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
