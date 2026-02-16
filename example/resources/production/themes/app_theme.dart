import 'package:flutter/material.dart';

/// Production environment theme configuration
class AppTheme {
  static const Color primaryColor = Color(0xFF2196F3); // Blue
  static const Color accentColor = Color(0xFF4CAF50); // Green
  static const Color backgroundColor = Color(0xFFFFFFFF);
  static const Color textColor = Color(0xFF212121);
  static const Color errorColor = Color(0xFFF44336);

  static const String environmentLabel = 'PROD';
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
        elevation: 1,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: textColor),
        bodyMedium: TextStyle(color: textColor),
      ),
    );
  }
}
