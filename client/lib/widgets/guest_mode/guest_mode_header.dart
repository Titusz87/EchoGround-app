import 'package:flutter/material.dart';
import '../echoground_banner.dart';

class GuestModeHeader extends StatelessWidget {
  const GuestModeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const EchoGroundBanner(),
        const SizedBox(height: 20),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'Hello, you are in Guest mode.',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),

            SizedBox(height: 4),
            // get location from gps
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
