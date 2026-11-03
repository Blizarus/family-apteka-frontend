import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/theme/app_theme.dart';

double _linearizeColorComponent(double c) {
  return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4).toDouble();
}

double _calculateRelativeLuminance(Color color) {
  final r = _linearizeColorComponent(color.r);
  final g = _linearizeColorComponent(color.g);
  final b = _linearizeColorComponent(color.b);
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

double _calculateContrastRatio(Color foreground, Color background) {
  final l1 = _calculateRelativeLuminance(foreground);
  final l2 = _calculateRelativeLuminance(background);
  final lighter = max(l1, l2);
  final darker = min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('WCAG 2.1 AA Palette Contrast Tests (>= 4.5:1)', () {
    test('1. Light Theme text and background pairs meet WCAG AA (>= 4.5:1)', () {
      final light = AppTheme.lightTheme;
      final cs = light.colorScheme;
      final semantics = light.extension<SemanticColors>() ?? SemanticColors.light;

      // 1. Text Primary on Background
      final ratioTextBg = _calculateContrastRatio(AppColors.textPrimary, light.scaffoldBackgroundColor);
      expect(ratioTextBg, greaterThanOrEqualTo(4.5),
          reason: 'Text primary on light scaffold background must be >= 4.5:1 (actual: $ratioTextBg)');

      // 2. Text Primary on Surface (Card)
      final ratioTextSurface = _calculateContrastRatio(AppColors.textPrimary, cs.surface);
      expect(ratioTextSurface, greaterThanOrEqualTo(4.5),
          reason: 'Text primary on surface must be >= 4.5:1 (actual: $ratioTextSurface)');

      // 3. Text Secondary on Background
      final ratioSecondaryBg = _calculateContrastRatio(AppColors.textSecondary, light.scaffoldBackgroundColor);
      expect(ratioSecondaryBg, greaterThanOrEqualTo(4.5),
          reason: 'Text secondary on scaffold background must be >= 4.5:1 (actual: $ratioSecondaryBg)');

      // 4. White on Primary button (Teal #0D9488)
      final ratioBtn = _calculateContrastRatio(Colors.white, cs.primary);
      expect(ratioBtn, greaterThanOrEqualTo(4.5),
          reason: 'White text on primary button must be >= 4.5:1 (actual: $ratioBtn)');

      // 5. Semantic Success Text on Success Background
      final ratioSuccess = _calculateContrastRatio(semantics.successText, semantics.successBg);
      expect(ratioSuccess, greaterThanOrEqualTo(4.5),
          reason: 'Success text on success bg must be >= 4.5:1 (actual: $ratioSuccess)');

      // 6. Semantic Warning Text on Warning Background
      final ratioWarning = _calculateContrastRatio(semantics.warningText, semantics.warningBg);
      expect(ratioWarning, greaterThanOrEqualTo(4.5),
          reason: 'Warning text on warning bg must be >= 4.5:1 (actual: $ratioWarning)');

      // 7. Semantic Danger Text on Danger Background
      final ratioDanger = _calculateContrastRatio(semantics.dangerText, semantics.dangerBg);
      expect(ratioDanger, greaterThanOrEqualTo(4.5),
          reason: 'Danger text on danger bg must be >= 4.5:1 (actual: $ratioDanger)');

      // 8. Semantic Info Text on Info Background
      final ratioInfo = _calculateContrastRatio(semantics.infoText, semantics.infoBg);
      expect(ratioInfo, greaterThanOrEqualTo(4.5),
          reason: 'Info text on info bg must be >= 4.5:1 (actual: $ratioInfo)');
    });

    test('2. Dark Theme text and background pairs meet WCAG AA (>= 4.5:1)', () {
      final dark = AppTheme.darkTheme;
      final cs = dark.colorScheme;
      final semantics = dark.extension<SemanticColors>() ?? SemanticColors.dark;

      // 1. Text Primary on Dark Background
      final ratioTextBg = _calculateContrastRatio(AppDarkColors.textPrimary, dark.scaffoldBackgroundColor);
      expect(ratioTextBg, greaterThanOrEqualTo(4.5),
          reason: 'Dark text primary on dark scaffold background must be >= 4.5:1 (actual: $ratioTextBg)');

      // 2. Text Primary on Dark Surface (Card)
      final ratioTextSurface = _calculateContrastRatio(AppDarkColors.textPrimary, cs.surface);
      expect(ratioTextSurface, greaterThanOrEqualTo(4.5),
          reason: 'Dark text primary on surface must be >= 4.5:1 (actual: $ratioTextSurface)');

      // 3. Text Secondary on Dark Background
      final ratioSecondaryBg = _calculateContrastRatio(AppDarkColors.textSecondary, dark.scaffoldBackgroundColor);
      expect(ratioSecondaryBg, greaterThanOrEqualTo(4.5),
          reason: 'Dark text secondary on scaffold background must be >= 4.5:1 (actual: $ratioSecondaryBg)');

      // 4. Dark text on primary button (Bright Teal #14B8A6 on dark background)
      final ratioBtn = _calculateContrastRatio(cs.onPrimary, cs.primary);
      expect(ratioBtn, greaterThanOrEqualTo(4.5),
          reason: 'OnPrimary on primary button in dark mode must be >= 4.5:1 (actual: $ratioBtn)');

      // 5. Semantic Success Text on Success Background
      final ratioSuccess = _calculateContrastRatio(semantics.successText, semantics.successBg);
      expect(ratioSuccess, greaterThanOrEqualTo(4.5),
          reason: 'Dark success text on success bg must be >= 4.5:1 (actual: $ratioSuccess)');

      // 6. Semantic Warning Text on Warning Background
      final ratioWarning = _calculateContrastRatio(semantics.warningText, semantics.warningBg);
      expect(ratioWarning, greaterThanOrEqualTo(4.5),
          reason: 'Dark warning text on warning bg must be >= 4.5:1 (actual: $ratioWarning)');

      // 7. Semantic Danger Text on Danger Background
      final ratioDanger = _calculateContrastRatio(semantics.dangerText, semantics.dangerBg);
      expect(ratioDanger, greaterThanOrEqualTo(4.5),
          reason: 'Dark danger text on danger bg must be >= 4.5:1 (actual: $ratioDanger)');

      // 8. Semantic Info Text on Info Background
      final ratioInfo = _calculateContrastRatio(semantics.infoText, semantics.infoBg);
      expect(ratioInfo, greaterThanOrEqualTo(4.5),
          reason: 'Dark info text on info bg must be >= 4.5:1 (actual: $ratioInfo)');
    });
  });
}
