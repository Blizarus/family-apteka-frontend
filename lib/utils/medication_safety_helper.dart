import '../models/intake_log.dart';
import '../models/medicine.dart';
import '../models/profile.dart';

enum CdsAlertLevel {
  critical,   // Красная плашка: DDI, аллергия, противопоказание
  warning,    // Желтая плашка: умеренное взаимодействие
  unverified, // Серая плашка: препарат ручного ввода без МНН/АТХ
  safe,       // Без плашки
}

class CdsAlert {
  final CdsAlertLevel level;
  final String title;
  final String message;
  final String recommendation;
  final List<String> details;

  const CdsAlert({
    required this.level,
    required this.title,
    required this.message,
    required this.recommendation,
    this.details = const [],
  });

  bool get isCritical => level == CdsAlertLevel.critical;
  bool get isWarning => level == CdsAlertLevel.warning;
  bool get isUnverified => level == CdsAlertLevel.unverified;
}

/// Клиническая справочная система (CDS) для расписания приёма медикаментов
class MedicationSafetyHelper {
  // Дисклеймер Минздрава РФ (обязательный согласно стандартам медицинских ИС)
  static const String minzdravDisclaimer =
      'Официальный дисклеймер Минздрава РФ: Информация сформирована автоматизированной системой поддержки клинических решений (CDS) и носит исключительно информационный характер. Она не заменяет консультацию медицинского специалиста и не является основанием для самостоятельного изменения схемы лечения. При возникновении вопросов обязательно обратитесь к лечащему врачу.';

  static CdsAlert? evaluateSafety({
    required IntakeLog log,
    required List<IntakeLog> allLogs,
    required List<Medicine> medicines,
    Profile? profile,
  }) {
    final medNameLower = log.medicineName.toLowerCase();

    // 1. Проверка на препарат ручного ввода (без привязки к справочнику ГРЛС / МНН)
    final matchedMed = medicines.where((m) => m.id == log.medicineId).firstOrNull;
    final isManualEntry = (matchedMed != null && matchedMed.referenceMedicineId == null) ||
        (log.medicineId == null);

    // 2. Проверка аллергий из профиля пациента
    if (profile != null && profile.allergies.isNotEmpty) {
      for (final allergy in profile.allergies) {
        final aLower = allergy.toLowerCase().trim();
        if (aLower.isNotEmpty && (medNameLower.contains(aLower) || aLower.contains(medNameLower))) {
          return CdsAlert(
            level: CdsAlertLevel.critical,
            title: 'Критический конфликт: Аллергия',
            message: 'У пациента ${profile.name} зафиксирована индивидуальная непереносимость: «$allergy».',
            recommendation: 'Немедленно прекратите приём и проконсультируйтесь с лечащим врачом для подбора гипоаллергенного аналога.',
            details: ['Препарат: ${log.medicineName}', 'Указанная аллергия: $allergy'],
          );
        }
      }
    }

    // 3. Анализ межлекарственных взаимодействий (DDI) со всеми активными препаратами дня
    final otherLogs = allLogs.where((l) => l.id != log.id && !l.isSkipped).toList();
    final allNames = otherLogs.map((l) => l.medicineName.toLowerCase()).toList();

    // DDI 1: НПВП + Антикоагулянты (Критический)
    final isNsaid = _isNsaid(medNameLower);
    final isAnticoag = _isAnticoagulant(medNameLower);

    if (isNsaid && allNames.any(_isAnticoagulant)) {
      final conflictMed = otherLogs.firstWhere((l) => _isAnticoagulant(l.medicineName.toLowerCase())).medicineName;
      return CdsAlert(
        level: CdsAlertLevel.critical,
        title: 'Критическое взаимодействие (DDI)',
        message: 'Одновременный приём НПВП (${log.medicineName}) и антикоагулянта ($conflictMed).',
        recommendation: 'Высокий риск желудочно-кишечных кровотечений. Требуется совместное назначение гастропротекторов (ИПП) строго по указанию врача.',
        details: ['Препарат 1: ${log.medicineName}', 'Препарат 2: $conflictMed', 'Риск: Кровотечение'],
      );
    }
    if (isAnticoag && allNames.any(_isNsaid)) {
      final conflictMed = otherLogs.firstWhere((l) => _isNsaid(l.medicineName.toLowerCase())).medicineName;
      return CdsAlert(
        level: CdsAlertLevel.critical,
        title: 'Критическое взаимодействие (DDI)',
        message: 'Одновременный приём антикоагулянта (${log.medicineName}) и НПВП ($conflictMed).',
        recommendation: 'Повышенный риск скрытых и явных кровотечений. Не принимайте препараты без контроля коагулограммы.',
        details: ['Препарат 1: ${log.medicineName}', 'Препарат 2: $conflictMed'],
      );
    }

    // DDI 2: Нитраты + Ингибиторы ФДЭ-5 (Критический)
    final isNitrate = _isNitrate(medNameLower);
    final isPde5 = _isPde5(medNameLower);
    if ((isNitrate && allNames.any(_isPde5)) || (isPde5 && allNames.any(_isNitrate))) {
      return const CdsAlert(
        level: CdsAlertLevel.critical,
        title: 'Опасное взаимодействие: Нитраты + ФДЭ-5',
        message: 'Комбинация нитратов и ингибиторов ФДЭ-5 вызывает опасный для жизни коллапс артериального давления.',
        recommendation: 'Категорически противопоказано одновременное применение. Немедленно обратитесь к кардиологу.',
      );
    }

    // DDI 3: Калийсберегающие диуретики + иАПФ / добавки калия (Критический/Высокий)
    final isPotassiumSparing = _isPotassiumSparing(medNameLower);
    final isAce = _isAceOrArb(medNameLower);
    if (isPotassiumSparing && (isAce || allNames.any(_isAceOrArb))) {
      return const CdsAlert(
        level: CdsAlertLevel.critical,
        title: 'Высокий риск: Гиперкалиемия',
        message: 'Калийсберегающие диуретики в сочетании с иАПФ/БРА могут вызывать опасное повышение уровня калия в крови.',
        recommendation: 'Необходим регулярный мониторинг уровня электролитов и ЭКГ.',
      );
    }

    // DDI 4: Макролиды + Статины (Критический/Высокий)
    final isMacrolide = _isMacrolide(medNameLower);
    final isStatin = _isStatin(medNameLower);
    if ((isMacrolide && allNames.any(_isStatin)) || (isStatin && allNames.any(_isMacrolide))) {
      return const CdsAlert(
        level: CdsAlertLevel.critical,
        title: 'Высокий риск: Рабдомиолиз',
        message: 'Макролидные антибиотики многократно повышают концентрацию статинов в крови.',
        recommendation: 'Рекомендуется временная приостановка приёма статина на время антибиотикотерапии.',
      );
    }

    // DDI 5: НПВП + иАПФ / БРА (Умеренный - Желтый)
    if ((isNsaid && allNames.any(_isAceOrArb)) || (isAce && allNames.any(_isNsaid))) {
      return const CdsAlert(
        level: CdsAlertLevel.warning,
        title: 'Умеренное взаимодействие',
        message: 'НПВП могут ослаблять гипотензивный эффект ингибиторов АПФ и увеличивать нагрузку на почки.',
        recommendation: 'Контролируйте артериальное давление и соблюдайте интервал между приёмами не менее 2 часов.',
      );
    }

    // 4. Если препарат добавлен вручную без ГРЛС и нет критических DDI -> Серая плашка
    if (isManualEntry) {
      return const CdsAlert(
        level: CdsAlertLevel.unverified,
        title: 'Безопасность не проверена',
        message: 'Препарат добавлен вручную без привязки к официальному реестру лекарственных средств (ГРЛС/МНН).',
        recommendation: 'Рекомендуется привязать препарат к эталонному справочнику в карточке аптечки для автоматического контроля совместимости.',
      );
    }

    return null;
  }

  static bool _isNsaid(String name) =>
      name.contains('ибупрофен') ||
      name.contains('диклофенак') ||
      name.contains('кеторол') ||
      name.contains('кетопрофен') ||
      name.contains('аспирин') ||
      name.contains('нурофен') ||
      name.contains('найз') ||
      name.contains('нимесулид');

  static bool _isAnticoagulant(String name) =>
      name.contains('варфарин') ||
      name.contains('ксарелто') ||
      name.contains('ривароксабан') ||
      name.contains('эликвис') ||
      name.contains('апиксабан') ||
      name.contains('гепарин');

  static bool _isNitrate(String name) =>
      name.contains('нитроглицерин') ||
      name.contains('изосорбид') ||
      name.contains('кардикет');

  static bool _isPde5(String name) =>
      name.contains('силденафил') ||
      name.contains('тадалафил') ||
      name.contains('виагра') ||
      name.contains('сиалис');

  static bool _isPotassiumSparing(String name) =>
      name.contains('спиронолактон') ||
      name.contains('верошпирон') ||
      name.contains('эплеренон');

  static bool _isAceOrArb(String name) =>
      name.contains('эналаприл') ||
      name.contains('лизиноприл') ||
      name.contains('лозартан') ||
      name.contains('каптоприл') ||
      name.contains('периндоприл') ||
      name.contains('вальсартан');

  static bool _isMacrolide(String name) =>
      name.contains('кларитромицин') ||
      name.contains('азитромицин') ||
      name.contains('эритромицин') ||
      name.contains('сумамед');

  static bool _isStatin(String name) =>
      name.contains('аторвастатин') ||
      name.contains('розувастатин') ||
      name.contains('симвастатин');
}
