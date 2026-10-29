import 'package:flutter/material.dart';

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

    final bgColor = isError ? const Color(0xFF991B1B) : const Color(0xFF0F172A);
    final borderColor = isError ? const Color(0xFFDC2626) : const Color(0xFF334155);
    final iconColor = isError ? const Color(0xFFFCA5A5) : const Color(0xFF2DD4BF);

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
                color: Colors.black.withValues(alpha: 0.3),
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
                  style: const TextStyle(
                    color: Colors.white,
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
