import 'package:flutter/material.dart';

class AppColors {
  // Primary
  static const Color primary = Color(0xFF6C63FF);       // Purple/Indigo
  static const Color primaryLight = Color(0xFFEEECFF);
  static const Color accent = Color(0xFFFFC107);         // Yellow
  static const Color accentDark = Color(0xFFE6A800);

  // Backgrounds
  static const Color background = Color(0xFFF9F9FF);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color chipBg = Color(0xFFF0EFFF);

  // Text
  static const Color textDark = Color(0xFF1A1A2E);
  static const Color textMedium = Color(0xFF6B6B8A);
  static const Color textLight = Color(0xFF9B9BB8);

  // Misc
  static const Color green = Color(0xFF4CAF50);
  static const Color selectedChip = Color(0xFF6C63FF);
  static const Color chipBorder = Color(0xFFDDDDEE);
  static const Color divider = Color(0xFFEEEEF5);

  // Skill level colors
  static const Color beginnerColor = Color(0xFFFF9800);
  static const Color homeCookColor = Color(0xFF6C63FF);
  static const Color confidentColor = Color(0xFF9C27B0);
  static const Color proChefColor = Color(0xFF2196F3);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        surface: AppColors.background,
      ),
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Nunito',
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: AppColors.textDark,
          height: 1.2,
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: AppColors.textDark,
          height: 1.2,
        ),
        headlineMedium: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.textDark,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textDark,
        ),
        bodyLarge: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: AppColors.textMedium,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: AppColors.textMedium,
          height: 1.5,
        ),
      ),
    );
  }
}
