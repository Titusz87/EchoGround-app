import 'package:flutter/material.dart';

class HouseholdHeader extends StatelessWidget {
  const HouseholdHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Hello, Thomas!',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            SizedBox(height: 4),

            Text(
              '📍 Broome, WA · Yawuru',
              style: TextStyle(
                fontSize: 14,
              ),
            ),
          ],
        ),
      ],
    );
  }
}