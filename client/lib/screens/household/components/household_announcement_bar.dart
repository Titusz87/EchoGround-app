import 'package:flutter/material.dart';

import 'household_theme.dart';
import 'marquee_banner.dart';

/// Compact single-line announcement banner with megaphone icon, vertical
/// divider, formatted marquee text, and chevron indicator.
class HouseholdAnnouncementBar extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const HouseholdAnnouncementBar({
    super.key,
    required this.text,
    required this.onTap,
  });

  /// Formats `[Linked Context: TAG]` + body into `[TAG] Body` on a single line.
  String _formatInlineBannerText(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return 'No active announcements';

    final contextPattern = RegExp(
      r'\[Linked Context:\s*([^\]]+)\]',
      caseSensitive: false,
    );
    final match = contextPattern.firstMatch(trimmed);

    if (match != null) {
      final tag = match.group(1)?.trim() ?? '';
      final body = trimmed
          .replaceAll(contextPattern, '')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();

      if (tag.isNotEmpty && body.isNotEmpty) {
        return '[$tag] $body';
      }
      if (tag.isNotEmpty) {
        return '[$tag]';
      }
    }

    return trimmed.replaceAll(RegExp(r'\s+'), ' ');
  }

  @override
  Widget build(BuildContext context) {
    final String displayLine = _formatInlineBannerText(text);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 14),
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
                size: 19,
              ),
              Container(
                width: 1,
                height: 16,
                margin: const EdgeInsets.symmetric(horizontal: 11),
                color: HouseholdTheme.border,
              ),
              Expanded(
                child: SizedBox(
                  height: 20,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: MarqueeBanner(text: displayLine),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: HouseholdTheme.brandTeal,
                size: 19,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
