import 'package:flutter/material.dart';

import 'guest_theme.dart';

/// Displays the resolved locality and First Nations traditional country,
/// allowing users to tap to retry geolocation lookup.
class GuestLocationFooter extends StatelessWidget {
  final String localityText;
  final String territoryText;
  final bool isLoading;
  final VoidCallback onTap;

  const GuestLocationFooter({
    super.key,
    required this.localityText,
    required this.territoryText,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final String displayLocality = localityText.trim().isNotEmpty
        ? localityText
        : 'Location unavailable';

    return Column(
      children: [
        const Divider(color: GuestTheme.border, thickness: 1, height: 14),
        InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 28),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Icon(
                      Icons.location_on_rounded,
                      color: GuestTheme.textPrimary,
                      size: 13.5,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayLocality,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: GuestTheme.textPrimary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          territoryText.trim().isNotEmpty ? territoryText : ' ',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: GuestTheme.textMuted,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
