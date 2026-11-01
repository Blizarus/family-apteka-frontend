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

class AppDarkColors {
  // Primary Teal Palette (Enhanced contrast on dark, #14B8A6)
  static const Color primary = Color(0xFF14B8A6);
  static const Color primaryHover = Color(0xFF2DD4BF);
  static const Color primaryDeep = Color(0xFF0F766E);
  static const Color primaryLight = Color(0xFF5EEAD4);
  static const Color primarySurface = Color(0xFF134E4A);
  static const Color primaryBorder = Color(0xFF2DD4BF);
  static const Color primaryBorderLight = Color(0xFF115E59);

  // Background and neutral slate tones
  static const Color background = Color(0xFF0F172A);
  static const Color surface = Color(0xFF1E293B);
  static const Color surfaceSubtle = Color(0xFF334155);

  // Text Colors
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  // Borders & Dividers
  static const Color border = Color(0xFF334155);
  static const Color borderDarker = Color(0xFF475569);

  // Status traffic light colors (Dark mode adapted)
  // Normal / Emerald
  static const Color statusOkBg = Color(0xFF064E3B);
  static const Color statusOkText = Color(0xFF6EE7B7);
  static const Color statusOkDot = Color(0xFF34D399);

  // Info / Sky
  static const Color statusInfoBg = Color(0xFF0C4A6E);

  // Expiring / Amber
  static const Color statusExpiringBg = Color(0xFF451A03);
  static const Color statusExpiringBorder = Color(0xFF92400E);
  static const Color statusExpiringText = Color(0xFFFDE68A);
  static const Color statusExpiringButtonBg = Color(0xFF78350F);

  // Expired / Rose & Danger
  static const Color statusExpiredBg = Color(0xFF4C0519);
  static const Color statusExpiredBorder = Color(0xFF9F1239);
  static const Color statusExpiredText = Color(0xFFFECDD3);
  static const Color statusExpiredButtonBg = Color(0xFF881337);
  static const Color danger = Color(0xFFEF4444);
  static const Color accentCoral = Color(0xFFFB7185);
}

const double kCardRadius = 18.0;

class AppTheme {
  static const double cardRadius = 18.0;

  static final ThemeData _lightTheme = _buildLightTheme();
  static ThemeData get lightTheme => _lightTheme;

  static final ThemeData _darkTheme = _buildDarkTheme();
  static ThemeData get darkTheme => _darkTheme;

  static ThemeData _buildLightTheme() {
    final interFont = GoogleFonts.inter().fontFamily;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: interFont,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        surface: AppColors.surface,
        brightness: Brightness.light,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.primarySurface;
            }
            return Colors.transparent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.primaryHover;
            }
            return AppColors.textSecondary;
          }),
          side: WidgetStateProperty.all(
            const BorderSide(color: AppColors.border),
          ),
        ),
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
          color: AppColors.textSecondary,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        hintStyle: TextStyle(
          fontFamily: interFont,
          color: AppColors.textMuted,
        ),
        labelStyle: TextStyle(
          fontFamily: interFont,
          color: AppColors.textSecondary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  static ThemeData _buildDarkTheme() {
    final interFont = GoogleFonts.inter().fontFamily;

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: interFont,
      scaffoldBackgroundColor: AppDarkColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppDarkColors.primary,
        primary: AppDarkColors.primary,
        surface: AppDarkColors.surface,
        brightness: Brightness.dark,
      ),
      cardTheme: CardThemeData(
        color: AppDarkColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: const BorderSide(color: AppDarkColors.border),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppDarkColors.surface,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppDarkColors.textPrimary),
        titleTextStyle: TextStyle(
          fontFamily: interFont,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppDarkColors.textPrimary,
        ),
      ),
      textTheme: TextTheme(
        headlineMedium: TextStyle(
          fontFamily: interFont,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppDarkColors.textPrimary,
        ),
        titleLarge: TextStyle(
          fontFamily: interFont,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppDarkColors.textPrimary,
        ),
        titleMedium: TextStyle(
          fontFamily: interFont,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppDarkColors.textPrimary,
        ),
        bodyMedium: TextStyle(
          fontFamily: interFont,
          fontSize: 13,
          color: AppDarkColors.textSecondary,
        ),
        bodySmall: TextStyle(
          fontFamily: interFont,
          fontSize: 11,
          color: AppDarkColors.textMuted,
        ),
        labelSmall: TextStyle(
          fontFamily: interFont,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: AppDarkColors.textSecondary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppDarkColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppDarkColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppDarkColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppDarkColors.primary, width: 1.5),
        ),
        hintStyle: TextStyle(
          fontFamily: interFont,
          color: AppDarkColors.textMuted,
        ),
        labelStyle: TextStyle(
          fontFamily: interFont,
          color: AppDarkColors.textSecondary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppDarkColors.primary,
          foregroundColor: AppDarkColors.background,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppDarkColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppDarkColors.border),
        ),
        titleTextStyle: TextStyle(
          fontFamily: interFont,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppDarkColors.textPrimary,
        ),
        contentTextStyle: TextStyle(
          fontFamily: interFont,
          fontSize: 13,
          color: AppDarkColors.textSecondary,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppDarkColors.border,
        thickness: 1,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppDarkColors.primarySurface;
            }
            return Colors.transparent;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppDarkColors.primaryHover;
            }
            return AppDarkColors.textSecondary;
          }),
          side: WidgetStateProperty.all(
            const BorderSide(color: AppDarkColors.border),
          ),
        ),
      ),
    );
  }
}
