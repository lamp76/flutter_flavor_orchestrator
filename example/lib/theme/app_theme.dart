// This file will be replaced by the flavor orchestrator when applying a flavor.
// This is a fallback theme for when no flavor has been applied yet.

import 'package:flutter/material.dart';

/// Theme configuration - will be replaced by flavor orchestrator
class AppTheme {
  static const Color primaryColor = Color(0xFF9E9E9E);
  static const Color accentColor = Color(0xFF757575);
  static const Color backgroundColor = Color(0xFFF5F5F5);
  static const Color textColor = Color(0xFF212121);
  static const Color errorColor = Color(0xFFF44336);

  static const String environmentLabel = 'NO FLAVOR';
  static const bool showDebugBanner = true;

  static ThemeData get lightTheme {
    return ThemeData(
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        secondary: accentColor,
        error: errorColor,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: textColor),
        bodyMedium: TextStyle(color: textColor),
      ),
    );
  }
}
