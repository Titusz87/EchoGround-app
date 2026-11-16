import 'package:flutter/material.dart';

/// Shared colour palette and styling constants for the Guest Mode experience.
abstract final class GuestTheme {
  // Core surfaces
  static const Color background = Color(0xFF1B2126);
  static const Color surfaceCard = Color(0xFF212930);
  static const Color surfaceElevated = Color(0xFF273139);
  static const Color surfaceDisabled = Color(0xFF1E252B);
  static const Color navBackground = Color(0xFF1E252B);
  static const Color navIndicator = Color(0xFF11443E);
  static const Color border = Color(0xFF33414A);

  // EchoGround brand teal (#01AC97)
  static const Color accentCyan = Color(0xFF01AC97);
  static const Color accentTeal = Color(0xFF019482);
  static const Color ringOuter = Color(0xFF0E3B36);
  static const Color ringMiddle = Color(0xFF0C2A27);
  static const Color ringInner = Color(0xFF0B1C1B);

  // Semantic & blue-grey text hierarchy
  static const Color warningAmber = Color(0xFFF5C518);
  static const Color textPrimary = Color(0xFFD5E0E6);
  static const Color textSecondary = Color(0xFF9AAAB5);
  static const Color textMuted = Color(0xFF7B8E9A);
  static const Color textDisabled = Color(0xFF6A7D88);
  static const Color iconDisabled = Color(0xFF556772);
}
