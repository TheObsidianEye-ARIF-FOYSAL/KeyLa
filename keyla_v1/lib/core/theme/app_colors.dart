import 'package:flutter/material.dart';

/// Palette from the design spec (§8.2). Kept as raw constants so both the
/// light/dark [ThemeData] and one-off widgets (strength meter segments,
/// health score ring) can reference the same values.
class AppColors {
  const AppColors._();

  static const primary = Color(0xFF4F46E5);
  static const primaryDark = Color(0xFF3730A3);
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFF43F5E);

  static const surfaceLight = Color(0xFFFFFFFF);
  static const backgroundLight = Color(0xFFF5F6FA);
  static const surfaceDark = Color(0xFF1A1D27);
  static const backgroundDark = Color(0xFF0F1117);

  static const textPrimaryLight = Color(0xFF14151A);
  static const textSecondaryLight = Color(0xFF6B6F80);
  static const textPrimaryDark = Color(0xFFF2F3F7);
  static const textSecondaryDark = Color(0xFF9AA0B4);

  static Color strengthColor(int strengthIndex) {
    switch (strengthIndex) {
      case 0:
        return danger;
      case 1:
        return warning;
      default:
        return success;
    }
  }
}
