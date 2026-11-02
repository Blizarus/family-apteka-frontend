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
    if (isLoading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceSubtle,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Клинический аудит совместимости и аллергий (CDS)...',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
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
          color: const Color(0xFFF0FDF4),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFBBF7D0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.verified_rounded, color: Color(0xFF16A34A), size: 18),
                SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Безопасно по данным системы поддержки решений (CDS)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF15803D),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Аллергий на активные и вспомогательные вещества, а также дублирования не обнаружено.',
                        style: TextStyle(fontSize: 10, color: Color(0xFF166534)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              disclaimer,
              style: const TextStyle(
                fontSize: 9.5,
                color: Color(0xFF15803D),
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
          color: const Color(0xFFFFFBEB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(
                  Icons.help_outline_rounded,
                  color: Color(0xFFD97706),
                  size: 18,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Данные неполные: проверить не удалось, обратитесь к врачу или провизору',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFB45309),
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
                      const Text('? ', style: TextStyle(color: Color(0xFFB45309), fontWeight: FontWeight.w700)),
                      Expanded(
                        child: Text(
                          reason,
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: Color(0xFF92400E),
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
              style: const TextStyle(
                fontSize: 9.5,
                color: Color(0xFF92400E),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    // 3. ИСХОД CONFLICT
    final bgColor = hasCritical ? const Color(0xFFFEF2F2) : const Color(0xFFFFF7ED);
    final borderColor = hasCritical ? const Color(0xFFFECACA) : const Color(0xFFFFEDD5);
    final iconColor = hasCritical ? const Color(0xFFDC2626) : const Color(0xFFEA580C);
    final titleColor = hasCritical ? const Color(0xFFB91C1C) : const Color(0xFFC2410C);
    final textColor = hasCritical ? const Color(0xFF991B1B) : const Color(0xFF9A3412);

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
                    color: titleColor,
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
