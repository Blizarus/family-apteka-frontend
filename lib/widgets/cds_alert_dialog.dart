import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/medication_safety_helper.dart';

/// Модальное окно деталей клинического предупреждения CDS с обязательным
/// дисклеймером Минздрава РФ (Микро-спринт 11).
class CdsAlertDialog extends StatelessWidget {
  final CdsAlert alert;

  const CdsAlertDialog({
    super.key,
    required this.alert,
  });

  static Future<void> show(BuildContext context, CdsAlert alert) {
    return showDialog(
      context: context,
      builder: (_) => CdsAlertDialog(alert: alert),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final semantics = theme.extension<SemanticColors>() ?? SemanticColors.light;

    Color headerBg;
    Color headerBorder;
    Color headerText;
    IconData headerIcon;

    switch (alert.level) {
      case CdsAlertLevel.critical:
        headerBg = semantics.dangerBg;
        headerBorder = semantics.dangerBorder;
        headerText = semantics.dangerText;
        headerIcon = Icons.dangerous_rounded;
        break;
      case CdsAlertLevel.warning:
        headerBg = semantics.warningBg;
        headerBorder = semantics.warningBorder;
        headerText = semantics.warningText;
        headerIcon = Icons.warning_amber_rounded;
        break;
      case CdsAlertLevel.unverified:
      case CdsAlertLevel.safe:
        headerBg = cs.surfaceContainerHighest;
        headerBorder = cs.outlineVariant;
        headerText = cs.onSurface;
        headerIcon = Icons.help_outline_rounded;
        break;
    }

    return AlertDialog(
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: headerBorder),
      ),
      titlePadding: EdgeInsets.zero,
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      title: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: headerBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Row(
          children: [
            Icon(headerIcon, color: headerText, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                alert.title,
                style: TextStyle(
                  color: headerText,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Message
            Text(
              alert.message,
              style: TextStyle(
                color: cs.onSurface,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),

            // Recommendation
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline_rounded, color: cs.primary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      alert.recommendation,
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (alert.details.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...alert.details.map((d) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('• ', style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.bold)),
                        Expanded(
                          child: Text(
                            d,
                            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],

            const SizedBox(height: 16),
            Divider(height: 1, color: cs.outlineVariant),
            const SizedBox(height: 12),

            // Минздрав РФ дисклеймер
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: cs.outlineVariant),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.gavel_rounded, color: cs.onSurfaceVariant, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      MedicationSafetyHelper.minzdravDisclaimer,
                      style: TextStyle(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.85),
                        fontSize: 10,
                        height: 1.3,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Понятно'),
        ),
      ],
    );
  }
}
