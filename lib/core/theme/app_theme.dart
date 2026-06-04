import 'package:flutter/material.dart';

class AppTheme {
  // Premium Harmonious Dark Palette
  static const Color background = Color(0xFF0F0F13); // Deep space black
  static const Color surface = Color(0xFF181820);    // Premium card surface
  static const Color primary = Color(0xFFFF5353);    // Vibrant coral/claw red (swipe delete)
  static const Color secondary = Color(0xFF2ECA87);  // Bright emerald green (swipe keep)
  static const Color accent = Color(0xFF8B5CF6);     // Royal purple for smart category actions
  
  static const Color textPrimary = Color(0xFFF3F4F6);
  static const Color textSecondary = Color(0xFF9CA3AF);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: surface,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 12,
        shadowColor: Colors.black.withOpacity(0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          color: textPrimary,
          fontSize: 32,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
        bodyMedium: TextStyle(
          color: textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        labelLarge: TextStyle(
          color: textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
