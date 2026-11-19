import 'package:flutter/material.dart';

import 'household_theme.dart';
import 'marquee_banner.dart';

/// Compact interactive announcement banner with megaphone icon, vertical
/// divider, scrolling marquee text, and chevron indicator.
class HouseholdAnnouncementBar extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const HouseholdAnnouncementBar({
    super.key,
    required this.text,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: HouseholdTheme.surfaceCard,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: HouseholdTheme.border, width: 1),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.campaign_outlined,
                color: HouseholdTheme.brandTeal,
                size: 20,
              ),
              Container(
                width: 1,
                height: 18,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                color: HouseholdTheme.border,
              ),
              Expanded(child: MarqueeBanner(text: text)),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: HouseholdTheme.brandTeal,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
