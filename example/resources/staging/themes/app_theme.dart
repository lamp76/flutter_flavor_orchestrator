import 'package:flutter/material.dart';

/// Staging environment theme configuration
class AppTheme {
  static const Color primaryColor = Color(0xFFFF9800); // Orange
  static const Color accentColor = Color(0xFF2196F3); // Blue
  static const Color backgroundColor = Color(0xFFFAFAFA);
  static const Color textColor = Color(0xFF212121);
  static const Color errorColor = Color(0xFFE64A19);

  static const String environmentLabel = 'STAGING';
  static const bool showDebugBanner = false;

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
