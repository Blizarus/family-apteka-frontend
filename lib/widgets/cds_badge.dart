import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/medication_safety_helper.dart';
import 'cds_alert_dialog.dart';

/// Интерактивная плашка клинической безопасности CDS на карточке приёма лекарства.
/// Цветовая дифференциация (Микро-спринт 11):
/// - Красная: критический конфликт (DDI, тяжелая аллергия, противопоказание).
/// - Желтая: предупреждение (умеренное взаимодействие).
/// - Серая: "Безопасность не проверена" (препарат ручного ввода без МНН/АТХ).
class CdsBadge extends StatelessWidget {
  final CdsAlert alert;

  const CdsBadge({super.key, required this.alert});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final semantics = theme.extension<SemanticColors>() ?? SemanticColors.light;

    Color bg;
    Color border;
    Color text;
    IconData icon;
    String label;

    switch (alert.level) {
      case CdsAlertLevel.critical:
        bg = semantics.dangerBg;
        border = semantics.dangerBorder;
        text = semantics.dangerText;
        icon = Icons.error_rounded;
        label = 'Конфликт / Риск';
        break;
      case CdsAlertLevel.warning:
        bg = semantics.warningBg;
        border = semantics.warningBorder;
        text = semantics.warningText;
        icon = Icons.warning_amber_rounded;
        label = 'Взаимодействие';
        break;
      case CdsAlertLevel.unverified:
      case CdsAlertLevel.safe:
        bg = cs.surfaceContainerHighest;
        border = cs.outlineVariant;
        text = cs.onSurfaceVariant;
        icon = Icons.help_outline_rounded;
        label = 'Безопасность не проверена';
        break;
    }

    return InkWell(
      onTap: () => CdsAlertDialog.show(context, alert),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: text),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: text,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.info_outline_rounded, size: 11, color: text),
          ],
        ),
      ),
    );
  }
}
