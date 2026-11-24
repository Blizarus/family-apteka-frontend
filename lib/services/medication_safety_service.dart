import '../models/medicine.dart';
import '../models/profile.dart';

/// Локальная служба клинической безопасности (Clinical Decision Support / On-Device CDS).
/// Обеспечивает мгновенный offline-first контроль лекарственной безопасности и аллергий.
class MedicationSafetyService {
  /// Выполняет локальный анализ риска аллергических реакций и непереносимости
  /// на основе профиля пациента и фармакологических свойств медикамента.
  static Map<String, dynamic>? checkLocalAllergy({
    required Profile profile,
    required Medicine medicine,
  }) {
    final patientAllergies = profile.allergies.map((a) => a.trim().toLowerCase()).toList();
    if (patientAllergies.isEmpty) {
      return null;
    }

    final medName = medicine.name.toLowerCase();
    final medSubstance = medicine.substance.toLowerCase();
    final medComposition = medicine.composition.toLowerCase();
    final allergenTags = medicine.allergenTags.map((t) => t.toLowerCase()).toList();
    final refInn = medicine.referenceMedicine?.inn.toLowerCase() ?? '';
    final refTrade = medicine.referenceMedicine?.tradeName.toLowerCase() ?? '';

    bool containsAny(List<String> keywords) {
      for (final kw in keywords) {
        if (medName.contains(kw) ||
            medSubstance.contains(kw) ||
            medComposition.contains(kw) ||
            allergenTags.contains(kw) ||
            refInn.contains(kw) ||
            refTrade.contains(kw)) {
          return true;
        }
      }
      return false;
    }

    final warnings = <String>[];
    bool hasCritical = false;

    // 1. Пенициллиновый ряд
    final hasPenicillinAllergy = patientAllergies.any(
      (a) =>
          a.contains('пенициллин') ||
          a.contains('penicillin') ||
          a.contains('амоксициллин') ||
          a.contains('ампициллин'),
    );
    if (hasPenicillinAllergy) {
      final penicillinKeywords = [
        'пенициллин',
        'penicillin',
        'амоксициллин',
        'amoxicillin',
        'ампициллин',
        'ampicillin',
        'аугментин',
        'augmentin',
        'бензилпенициллин',
        'benzylpenicillin',
        'оксациллин',
        'oxacillin',
        'флемоксин',
        'flemoxin',
        'амоксиклав',
        'amoksiklav',
        'бициллин',
        'bicillin',
      ];
      if (containsAny(penicillinKeywords)) {
        hasCritical = true;
        warnings.add(
          'КРИТИЧЕСКИЙ РИСК: У пациента аллергия на пенициллины. Препарат содержит пенициллиновый ряд!',
        );
      }
    }

    // 2. Аспирин и НПВП
    final hasNsaidAllergy = patientAllergies.any(
      (a) =>
          a.contains('аспирин') ||
          a.contains('нпвп') ||
          a.contains('nsaid') ||
          a.contains('ацетилсалицил') ||
          a.contains('ибупрофен'),
    );
    if (hasNsaidAllergy) {
      final nsaidKeywords = [
        'аспирин',
        'aspirin',
        'ацетилсалицилов',
        'acetylsalicylic',
        'ибупрофен',
        'ibuprofen',
        'диклофенак',
        'diclofenac',
        'кетопрофен',
        'ketoprofen',
        'кеторолак',
        'ketorolac',
        'кардиомагнил',
        'cardiomagnyl',
        'тромбо асс',
      ];
      if (containsAny(nsaidKeywords)) {
        hasCritical = true;
        warnings.add(
          'КРИТИЧЕСКИЙ РИСК: У пациента непереносимость НПВП/аспирина. Препарат содержит ацетилсалициловую кислоту или НПВП!',
        );
      }
    }

    // 3. Лактоза
    final hasLactoseAllergy = patientAllergies.any(
      (a) => a.contains('лактоз') || a.contains('lactose') || a.contains('молочн'),
    );
    if (hasLactoseAllergy) {
      final lactoseKeywords = ['лактоз', 'lactose'];
      if (containsAny(lactoseKeywords)) {
        warnings.add(
          'ВНИМАНИЕ: Препарат содержит лактозу, на которую у пациента зафиксирована непереносимость!',
        );
      }
    }

    if (warnings.isEmpty) {
      return null;
    }

    return {
      'status': 'conflict',
      'is_safe': false,
      'has_critical': hasCritical,
      'warnings': warnings,
      'local_check': true,
      'disclaimer':
          'Автоматическая локальная проверка CDS по профилю пациента. При наличии аллергии приём препарата противопоказан.',
    };
  }
}
