import 'package:flutter/material.dart';

class AppColors {
  // Primary Teal Palette (#0F766E meets WCAG AA 5.47:1 with white text)
  static const Color primary = Color(0xFF0F766E);
  static const Color primaryHover = Color(0xFF115E59);
  static const Color primaryDeep = Color(0xFF134E4A);
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
  static const Color textMuted = Color(0xFF64748B);

  // Borders & Dividers
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderDarker = Color(0xFFCBD5E1);

  // Status traffic light colors
  static const Color statusOkBg = Color(0xFFECFDF5);
  static const Color statusOkText = Color(0xFF047857);
  static const Color statusOkDot = Color(0xFF10B981);

  static const Color statusInfoBg = Color(0xFFE0F2FE);

  static const Color statusExpiringBg = Color(0xFFFFFBEB);
  static const Color statusExpiringBorder = Color(0xFFFDE68A);
  static const Color statusExpiringText = Color(0xFF92400E);
  static const Color statusExpiringButtonBg = Color(0xFFFEF3C7);

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
  static const Color statusOkBg = Color(0xFF064E3B);
  static const Color statusOkText = Color(0xFF6EE7B7);
  static const Color statusOkDot = Color(0xFF34D399);

  static const Color statusInfoBg = Color(0xFF0C4A6E);

  static const Color statusExpiringBg = Color(0xFF451A03);
  static const Color statusExpiringBorder = Color(0xFF92400E);
  static const Color statusExpiringText = Color(0xFFFDE68A);
  static const Color statusExpiringButtonBg = Color(0xFF78350F);

  static const Color statusExpiredBg = Color(0xFF4C0519);
  static const Color statusExpiredBorder = Color(0xFF9F1239);
  static const Color statusExpiredText = Color(0xFFFECDD3);
  static const Color statusExpiredButtonBg = Color(0xFF881337);
  static const Color danger = Color(0xFFEF4444);
  static const Color accentCoral = Color(0xFFFB7185);
}

const double kCardRadius = 18.0;

@immutable
class SemanticColors extends ThemeExtension<SemanticColors> {
  final Color success;
  final Color successBg;
  final Color successBorder;
  final Color successText;

  final Color warning;
  final Color warningBg;
  final Color warningBorder;
  final Color warningText;

  final Color danger;
  final Color dangerBg;
  final Color dangerBorder;
  final Color dangerText;

  final Color info;
  final Color infoBg;
  final Color infoBorder;
  final Color infoText;

  const SemanticColors({
    required this.success,
    required this.successBg,
    required this.successBorder,
    required this.successText,
    required this.warning,
    required this.warningBg,
    required this.warningBorder,
    required this.warningText,
    required this.danger,
    required this.dangerBg,
    required this.dangerBorder,
    required this.dangerText,
    required this.info,
    required this.infoBg,
    required this.infoBorder,
    required this.infoText,
  });

  static const SemanticColors light = SemanticColors(
    success: Color(0xFF0D9488),
    successBg: Color(0xFFECFDF5),
    successBorder: Color(0xFFA7F3D0),
    successText: Color(0xFF065F46), // WCAG contrast ratio with ECFDF5 > 6.0:1

    warning: Color(0xFFD97706),
    warningBg: Color(0xFFFFFBEB),
    warningBorder: Color(0xFFFDE68A),
    warningText: Color(0xFF92400E), // WCAG contrast ratio with FFFBEB > 6.5:1

    danger: Color(0xFFDC2626),
    dangerBg: Color(0xFFFEF2F2),
    dangerBorder: Color(0xFFFECACA),
    dangerText: Color(0xFF991B1B), // WCAG contrast ratio with FEF2F2 > 7.0:1

    info: Color(0xFF0284C7),
    infoBg: Color(0xFFF0F9FF),
    infoBorder: Color(0xFFBAE6FD),
    infoText: Color(0xFF075985), // WCAG contrast ratio with F0F9FF > 6.5:1
  );

  static const SemanticColors dark = SemanticColors(
    success: Color(0xFF2DD4BF),
    successBg: Color(0xFF064E3B),
    successBorder: Color(0xFF047857),
    successText: Color(0xFFA7F3D0), // WCAG contrast ratio with 064E3B > 5.5:1

    warning: Color(0xFFFBBF24),
    warningBg: Color(0xFF451A03),
    warningBorder: Color(0xFF78350F),
    warningText: Color(0xFFFDE68A), // WCAG contrast ratio with 451A03 > 6.0:1

    danger: Color(0xFFF87171),
    dangerBg: Color(0xFF450A0A),
    dangerBorder: Color(0xFF7F1D1D),
    dangerText: Color(0xFFFECACA), // WCAG contrast ratio with 450A0A > 6.5:1

    info: Color(0xFF38BDF8),
    infoBg: Color(0xFF082F49),
    infoBorder: Color(0xFF0369A1),
    infoText: Color(0xFFBAE6FD), // WCAG contrast ratio with 082F49 > 6.0:1
  );

  @override
  SemanticColors copyWith({
    Color? success,
    Color? successBg,
    Color? successBorder,
    Color? successText,
    Color? warning,
    Color? warningBg,
    Color? warningBorder,
    Color? warningText,
    Color? danger,
    Color? dangerBg,
    Color? dangerBorder,
    Color? dangerText,
    Color? info,
    Color? infoBg,
    Color? infoBorder,
    Color? infoText,
  }) {
    return SemanticColors(
      success: success ?? this.success,
      successBg: successBg ?? this.successBg,
      successBorder: successBorder ?? this.successBorder,
      successText: successText ?? this.successText,
      warning: warning ?? this.warning,
      warningBg: warningBg ?? this.warningBg,
      warningBorder: warningBorder ?? this.warningBorder,
      warningText: warningText ?? this.warningText,
      danger: danger ?? this.danger,
      dangerBg: dangerBg ?? this.dangerBg,
      dangerBorder: dangerBorder ?? this.dangerBorder,
      dangerText: dangerText ?? this.dangerText,
      info: info ?? this.info,
      infoBg: infoBg ?? this.infoBg,
      infoBorder: infoBorder ?? this.infoBorder,
      infoText: infoText ?? this.infoText,
    );
  }

  @override
  SemanticColors lerp(ThemeExtension<SemanticColors>? other, double t) {
    if (other is! SemanticColors) return this;
    return SemanticColors(
      success: Color.lerp(success, other.success, t)!,
      successBg: Color.lerp(successBg, other.successBg, t)!,
      successBorder: Color.lerp(successBorder, other.successBorder, t)!,
      successText: Color.lerp(successText, other.successText, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningBg: Color.lerp(warningBg, other.warningBg, t)!,
      warningBorder: Color.lerp(warningBorder, other.warningBorder, t)!,
      warningText: Color.lerp(warningText, other.warningText, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerBg: Color.lerp(dangerBg, other.dangerBg, t)!,
      dangerBorder: Color.lerp(dangerBorder, other.dangerBorder, t)!,
      dangerText: Color.lerp(dangerText, other.dangerText, t)!,
      info: Color.lerp(info, other.info, t)!,
      infoBg: Color.lerp(infoBg, other.infoBg, t)!,
      infoBorder: Color.lerp(infoBorder, other.infoBorder, t)!,
      infoText: Color.lerp(infoText, other.infoText, t)!,
    );
  }
}

class AppTheme {
  static const double cardRadius = 18.0;

  static final ThemeData _lightTheme = _buildLightTheme();
  static ThemeData get lightTheme => _lightTheme;

  static final ThemeData _darkTheme = _buildDarkTheme();
  static ThemeData get darkTheme => _darkTheme;

  static ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        primaryContainer: AppColors.primarySurface,
        onPrimaryContainer: AppColors.primaryDeep,
        secondary: AppColors.primaryHover,
        onSecondary: Colors.white,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        error: AppColors.danger,
        onError: Colors.white,
        outline: AppColors.borderDarker,
        outlineVariant: AppColors.border,
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
          side: const BorderSide(color: AppColors.border),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        contentTextStyle: const TextStyle(
          fontSize: 13,
          color: AppColors.textSecondary,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceSubtle,
        disabledColor: AppColors.border,
        selectedColor: AppColors.primarySurface,
        secondarySelectedColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        labelStyle: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
        secondaryLabelStyle: const TextStyle(fontSize: 12, color: AppColors.primaryDeep, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 13,
          color: AppColors.textSecondary,
        ),
        bodySmall: TextStyle(
          fontSize: 11,
          color: AppColors.textMuted,
        ),
        labelSmall: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: AppColors.textSecondary,
        ),
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
        hintStyle: const TextStyle(color: AppColors.textMuted),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
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
      extensions: const [
        SemanticColors.light,
      ],
    );
  }

  static ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: AppDarkColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppDarkColors.primary,
        onPrimary: AppDarkColors.background,
        primaryContainer: AppDarkColors.primarySurface,
        onPrimaryContainer: AppDarkColors.primaryLight,
        secondary: AppDarkColors.primaryHover,
        onSecondary: AppDarkColors.background,
        surface: AppDarkColors.surface,
        onSurface: AppDarkColors.textPrimary,
        error: AppDarkColors.danger,
        onError: AppDarkColors.background,
        outline: AppDarkColors.borderDarker,
        outlineVariant: AppDarkColors.border,
      ),
      cardTheme: CardThemeData(
        color: AppDarkColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: const BorderSide(color: AppDarkColors.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppDarkColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppDarkColors.border),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppDarkColors.textPrimary,
        ),
        contentTextStyle: const TextStyle(
          fontSize: 13,
          color: AppDarkColors.textSecondary,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppDarkColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppDarkColors.surfaceSubtle,
        disabledColor: AppDarkColors.border,
        selectedColor: AppDarkColors.primarySurface,
        secondarySelectedColor: AppDarkColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        labelStyle: const TextStyle(fontSize: 12, color: AppDarkColors.textSecondary, fontWeight: FontWeight.w600),
        secondaryLabelStyle: const TextStyle(fontSize: 12, color: AppDarkColors.primaryLight, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppDarkColors.border),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppDarkColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppDarkColors.textPrimary),
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppDarkColors.textPrimary,
        ),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppDarkColors.textPrimary,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppDarkColors.textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: AppDarkColors.textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 13,
          color: AppDarkColors.textSecondary,
        ),
        bodySmall: TextStyle(
          fontSize: 11,
          color: AppDarkColors.textMuted,
        ),
        labelSmall: TextStyle(
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
        hintStyle: const TextStyle(color: AppDarkColors.textMuted),
        labelStyle: const TextStyle(color: AppDarkColors.textSecondary),
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
      dividerTheme: const DividerThemeData(
        color: AppDarkColors.border,
        thickness: 1,
      ),
      extensions: const [
        SemanticColors.dark,
      ],
    );
  }
}

extension AppThemeContext on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  TextTheme get textTheme => Theme.of(this).textTheme;
  SemanticColors get semantics => Theme.of(this).extension<SemanticColors>() ?? SemanticColors.light;
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
  Color get scaffoldBackgroundColor => Theme.of(this).scaffoldBackgroundColor;
  Color get surfaceColor => Theme.of(this).colorScheme.surface;
  Color get cardBackgroundColor => Theme.of(this).cardTheme.color ?? Theme.of(this).colorScheme.surface;
  Color get borderColor => Theme.of(this).colorScheme.outlineVariant;
}
