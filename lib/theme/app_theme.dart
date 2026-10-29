import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Primary Teal Palette (#0D9488)
  static const Color primary = Color(0xFF0D9488);
  static const Color primaryHover = Color(0xFF0F766E);
  static const Color primaryDeep = Color(0xFF115E59);
  static const Color primaryLight = Color(0xFF14B8A6);
  static const Color primarySurface = Color(0xFFF0FDFA);
  static const Color primaryBorder = Color(0xFF99F6E4);
  static const Color primaryBorderLight = Color(0xFFCCFBF1);

  // Background and neutral tones
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Colors.white;
  static const Color surfaceSubtle = Color(0xFFF1F5F9);

  // Text Colors
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF94A3B8);

  // Borders & Dividers
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderDarker = Color(0xFFCBD5E1);

  // Status traffic light colors
  // Normal / Emerald
  static const Color statusOkBg = Color(0xFFECFDF5);
  static const Color statusOkText = Color(0xFF047857);
  static const Color statusOkDot = Color(0xFF10B981);

  // Info / Sky
  static const Color statusInfoBg = Color(0xFFE0F2FE);

  // Expiring / Amber
  static const Color statusExpiringBg = Color(0xFFFFFBEB);
  static const Color statusExpiringBorder = Color(0xFFFDE68A);
  static const Color statusExpiringText = Color(0xFF92400E);
  static const Color statusExpiringButtonBg = Color(0xFFFEF3C7);

  // Expired / Rose & Danger
  static const Color statusExpiredBg = Color(0xFFFFF1F2);
  static const Color statusExpiredBorder = Color(0xFFFECDD3);
  static const Color statusExpiredText = Color(0xFF9F1239);
  static const Color statusExpiredButtonBg = Color(0xFFFFE4E6);
  static const Color danger = Color(0xFFDC2626);
  static const Color accentCoral = Color(0xFFF43F5E);
}

const double kCardRadius = 18.0;

class AppTheme {
  static const double cardRadius = 18.0;

  static ThemeData get lightTheme {
    final interFont = GoogleFonts.inter().fontFamily;

    return ThemeData(
      useMaterial3: true,
      fontFamily: interFont,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        surface: AppColors.surface,
        brightness: Brightness.light,
      ),
      textTheme: TextTheme(
        headlineMedium: TextStyle(
          fontFamily: interFont,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        titleLarge: TextStyle(
          fontFamily: interFont,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        titleMedium: TextStyle(
          fontFamily: interFont,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        bodyMedium: TextStyle(
          fontFamily: interFont,
          fontSize: 13,
          color: AppColors.textSecondary,
        ),
        bodySmall: TextStyle(
          fontFamily: interFont,
          fontSize: 11,
          color: AppColors.textMuted,
        ),
        labelSmall: TextStyle(
          fontFamily: interFont,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
    );
  }
}

