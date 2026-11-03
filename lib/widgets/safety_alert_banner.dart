import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SafetyAlertBanner extends StatelessWidget {
  final Map<String, dynamic>? safetyData;
  final bool isLoading;

  const SafetyAlertBanner({
    super.key,
    this.safetyData,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final semantics = Theme.of(context).extension<SemanticColors>() ?? SemanticColors.light;
    final colorScheme = Theme.of(context).colorScheme;

    if (isLoading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Клинический аудит совместимости и аллергий (CDS)...',
                style: TextStyle(fontSize: 11, color: Theme.of(context).textTheme.bodyMedium?.color),
              ),
            ),
          ],
        ),
      );
    }

    if (safetyData == null) {
      return const SizedBox.shrink();
    }

    // Fail-closed архитектура: если поле отсутствует, дефолт false!
    final isSafe = safetyData!['is_safe'] == true;
    final hasCritical = safetyData!['has_critical'] == true;
    final warnings = (safetyData!['warnings'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final unverifiedChecks = (safetyData!['unverified_checks'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final disclaimer = safetyData!['disclaimer'] as String? ??
        'Автоматическая проверка взаимодействия лекарств носит информационный характер и не заменяет консультацию врача или провизора. При наличии сомнений обратитесь к врачу.';

    // Явный статус: 'safe', 'conflict', 'unverifiable'
    final rawStatus = safetyData!['status'] as String?;
    final status = rawStatus ??
        (warnings.isNotEmpty
            ? 'conflict'
            : (isSafe && unverifiedChecks.isEmpty && safetyData!.containsKey('is_safe')
                ? 'safe'
                : 'unverifiable'));

    // 1. ИСХОД SAFE
    if (status == 'safe' && isSafe && warnings.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: semantics.successBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: semantics.successBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.verified_rounded, color: semantics.success, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Безопасно по данным системы поддержки решений (CDS)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: semantics.successText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Аллергий на активные и вспомогательные вещества, а также дублирования не обнаружено.',
                        style: TextStyle(fontSize: 10, color: semantics.successText),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              disclaimer,
              style: TextStyle(
                fontSize: 9.5,
                color: semantics.successText,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    // 2. ИСХОД UNVERIFIABLE
    if (status == 'unverifiable') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: semantics.warningBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: semantics.warningBorder, width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.help_outline_rounded,
                  color: semantics.warning,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Данные неполные: проверить не удалось, обратитесь к врачу или провизору',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: semantics.warningText,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
            if (unverifiedChecks.isNotEmpty) ...[
              const SizedBox(height: 6),
              ...unverifiedChecks.map(
                (reason) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('? ', style: TextStyle(color: semantics.warningText, fontWeight: FontWeight.w700)),
                      Expanded(
                        child: Text(
                          reason,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: semantics.warningText,
                            height: 1.3,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              disclaimer,
              style: TextStyle(
                fontSize: 9.5,
                color: semantics.warningText,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    // 3. ИСХОД CONFLICT
    final bgColor = hasCritical ? semantics.dangerBg : semantics.warningBg;
    final borderColor = hasCritical ? semantics.dangerBorder : semantics.warningBorder;
    final iconColor = hasCritical ? semantics.danger : semantics.warning;
    final textColor = hasCritical ? semantics.dangerText : semantics.warningText;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasCritical ? Icons.dangerous_rounded : Icons.warning_amber_rounded,
                color: iconColor,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hasCritical
                      ? 'КРИТИЧЕСКОЕ ПРЕДОСТЕРЕЖЕНИЕ (CDS)'
                      : 'Внимание: Клиническое предупреждение (CDS)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...warnings.map(
            (warning) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('• ', style: TextStyle(color: textColor, fontWeight: FontWeight.w700)),
                  Expanded(
                    child: Text(
                      warning,
                      style: TextStyle(
                        fontSize: 11,
                        color: textColor,
                        height: 1.3,
                        fontWeight: hasCritical ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            disclaimer,
            style: TextStyle(
              fontSize: 9.5,
              color: textColor,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
