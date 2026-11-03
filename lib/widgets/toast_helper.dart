import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ToastHelper {
  static void showSuccess(BuildContext context, String message) {
    show(context, message: message, icon: '✓', isError: false);
  }

  static void showError(BuildContext context, String message) {
    show(context, message: message, icon: '⚠️', isError: true);
  }

  static void show(
    BuildContext context, {
    required String message,
    String icon = '✓',
    bool isError = false,
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).clearSnackBars();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final semantics = theme.extension<SemanticColors>() ?? SemanticColors.light;

    final bgColor = isError ? semantics.dangerBg : colorScheme.surface;
    final borderColor = isError ? semantics.dangerBorder : colorScheme.outlineVariant;
    final iconColor = isError ? semantics.danger : colorScheme.primary;
    final textColor = isError ? semantics.dangerText : colorScheme.onSurface;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: Colors.transparent,
        duration: duration,
        margin: const EdgeInsets.only(top: 16, left: 20, right: 20, bottom: 20),
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Text(
                icon,
                style: TextStyle(
                  color: iconColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
