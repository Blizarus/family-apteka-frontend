import '../utils/parse_helper.dart';
import 'medicine.dart';

enum MedicineStockStatus {
  inStock, // 🟢 Есть в наличии
  lowStock, // 🟡 Мало (нужно докупить)
  missing, // 🔴 Нет в аптечке
}

class PrescribedMedicineItem {
  final String name;
  final String dosage;
  final MedicineStockStatus status;
  final String locationInfo;
  final double remainingCount;
  final double neededCount;

  const PrescribedMedicineItem({
    required this.name,
    required this.dosage,
    required this.status,
    required this.locationInfo,
    this.remainingCount = 0,
    this.neededCount = 0,
  });

  bool get isInStock => status == MedicineStockStatus.inStock;
  bool get isLowStock => status == MedicineStockStatus.lowStock;
  bool get isMissing => status == MedicineStockStatus.missing;

  String get remainingCountDisplay => ParseHelper.formatQuantity(remainingCount);
  String get neededCountDisplay => ParseHelper.formatQuantity(neededCount);

  Map<String, dynamic> toJson() => {
        'name': name,
        'dosage': dosage,
        'status': status.name,
        'locationInfo': locationInfo,
        'remainingCount': remainingCount,
        'neededCount': neededCount,
      };

  factory PrescribedMedicineItem.fromJson(Map<String, dynamic> json) {
    return PrescribedMedicineItem(
      name: json['name'] as String? ?? '',
      dosage: json['dosage'] as String? ?? '',
      status: MedicineStockStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => MedicineStockStatus.missing,
      ),
      locationInfo: json['locationInfo'] as String? ?? '',
      remainingCount: ParseHelper.parseDouble(json['remainingCount'] ?? json['remaining_count']),
      neededCount: ParseHelper.parseDouble(json['neededCount'] ?? json['needed_count']),
    );
  }
}

class MedicalNote {
  final int id;
  final int profileId;
  final String doctorName;
  final String specialty;
  final String clinic;
  final String diagnosis;
  final DateTime date;
  final String content;
  final List<PrescribedMedicineItem> prescribedMedicines;
  final bool isAudioDictated;
  final bool isArchived;

  const MedicalNote({
    required this.id,
    required this.profileId,
    required this.doctorName,
    required this.specialty,
    this.clinic = 'Городская поликлиника №4',
    required this.diagnosis,
    required this.date,
    required this.content,
    required this.prescribedMedicines,
    this.isAudioDictated = false,
    this.isArchived = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'profileId': profileId,
        'doctorName': doctorName,
        'specialty': specialty,
        'clinic': clinic,
        'diagnosis': diagnosis,
        'date': date.toIso8601String(),
        'content': content,
        'prescribedMedicines': prescribedMedicines.map((m) => m.toJson()).toList(),
        'isAudioDictated': isAudioDictated,
        'isArchived': isArchived,
      };

  factory MedicalNote.fromJson(Map<String, dynamic> json) {
    return MedicalNote(
      id: ParseHelper.parseInt(json['id']),
      profileId: ParseHelper.parseInt(json['profileId'] ?? json['profile_id'], 1),
      doctorName: json['doctorName'] as String? ?? 'Лечащий врач',
      specialty: json['specialty'] as String? ?? 'Терапевт',
      clinic: json['clinic'] as String? ?? 'Городская поликлиника',
      diagnosis: json['diagnosis'] as String? ?? 'Диагноз',
      date: json['date'] != null
          ? DateTime.tryParse(json['date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      content: json['content'] as String? ?? '',
      prescribedMedicines: (json['prescribedMedicines'] as List?)
              ?.map((e) => PrescribedMedicineItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      isAudioDictated: json['isAudioDictated'] as bool? ?? false,
      isArchived: json['isArchived'] as bool? ?? false,
    );
  }

  MedicalNote copyWith({
    int? id,
    int? profileId,
    String? doctorName,
    String? specialty,
    String? clinic,
    String? diagnosis,
    DateTime? date,
    String? content,
    List<PrescribedMedicineItem>? prescribedMedicines,
    bool? isAudioDictated,
    bool? isArchived,
  }) {
    return MedicalNote(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      doctorName: doctorName ?? this.doctorName,
      specialty: specialty ?? this.specialty,
      clinic: clinic ?? this.clinic,
      diagnosis: diagnosis ?? this.diagnosis,
      date: date ?? this.date,
      content: content ?? this.content,
      prescribedMedicines: prescribedMedicines ?? this.prescribedMedicines,
      isAudioDictated: isAudioDictated ?? this.isAudioDictated,
      isArchived: isArchived ?? this.isArchived,
    );
  }

  /// Парсит свободный текст протокола/заметки, выявляет упоминания лекарств
  /// и сопоставляет их с реальным инвентарем домашней аптечки
  static List<PrescribedMedicineItem> parseAndMatch(
    String text,
    List<Medicine> inventory,
  ) {
    final List<PrescribedMedicineItem> items = [];
    final lowerText = text.toLowerCase();

    // Предустановленный словарь частых назначений и действующих веществ
    final knownKeywords = [
      {
        'key': 'амоксиклав',
        'substance': 'амоксициллин',
        'display': 'Амоксиклав 500+125мг',
        'defaultDosage': '1 таб. 2 раза в день (7 дней)',
        'needed': 14,
      },
      {
        'key': 'амоксициллин',
        'substance': 'амоксициллин',
        'display': 'Амоксициллин 500 мг',
        'defaultDosage': '1 таб. 3 раза в день (7 дней)',
        'needed': 21,
      },
      {
        'key': 'ибупрофен',
        'substance': 'ибупрофен',
        'display': 'Ибупрофен 400 мг',
        'defaultDosage': '1 таб. при боли или t > 38.5 (до 3 р/д)',
        'needed': 10,
      },
      {
        'key': 'нурофен',
        'substance': 'ибупрофен',
        'display': 'Нурофен Форте',
        'defaultDosage': '1 таб. при температуре или боли',
        'needed': 12,
      },
      {
        'key': 'парацетамол',
        'substance': 'парацетамол',
        'display': 'Парацетамол 500 мг',
        'defaultDosage': '1 таб. при температуре (до 4 р/д)',
        'needed': 10,
      },
      {
        'key': 'омепразол',
        'substance': 'омепразол',
        'display': 'Омепразол 20 мг',
        'defaultDosage': '1 капс. утром за 30 мин до еды',
        'needed': 14,
      },
      {
        'key': 'називин',
        'substance': 'оксиметазолин',
        'display': 'Спрей Називин',
        'defaultDosage': '1-2 впрыскивания 2-3 раза в день (до 5 дней)',
        'needed': 1,
      },
      {
        'key': 'витамин c',
        'substance': 'аскорбиновая кислота',
        'display': 'Витамин C 1000 мг',
        'defaultDosage': '1 шипучая таб. растворить в воде 1 раз в день',
        'needed': 10,
      },
      {
        'key': 'супрастин',
        'substance': 'хлоропирамин',
        'display': 'Супрастин 25 мг',
        'defaultDosage': '1 таб. на ночь при аллергии',
        'needed': 10,
      },
      {
        'key': 'цетиризин',
        'substance': 'цетиризин',
        'display': 'Цетиризин 10 мг',
        'defaultDosage': '1 таб. 1 раз в день вечером',
        'needed': 10,
      },
      {
        'key': 'азитромицин',
        'substance': 'азитромицин',
        'display': 'Азитромицин 500 мг',
        'defaultDosage': '1 капс. 1 раз в день за 1 час до еды (3 дня)',
        'needed': 3,
      },
      {
        'key': 'панкреатин',
        'substance': 'панкреатин',
        'display': 'Мезим / Панкреатин',
        'defaultDosage': '1-2 таб. во время каждого приёма пищи',
        'needed': 20,
      },
    ];

    final Set<String> matchedKeys = {};

    for (final kw in knownKeywords) {
      final key = kw['key'] as String;
      final substance = kw['substance'] as String;
      final display = kw['display'] as String;
      final defaultDosage = kw['defaultDosage'] as String;
      final needed = kw['needed'] as int;

      if (lowerText.contains(key) || lowerText.contains(substance)) {
        if (matchedKeys.contains(substance)) continue;
        matchedKeys.add(substance);

        // Ищем в инвентаре пользователя совпадение по названию или действующему веществу
        final inventoryMatch = inventory.cast<Medicine?>().firstWhere(
              (m) =>
                  m != null &&
                  (m.name.toLowerCase().contains(key) ||
                      m.name.toLowerCase().contains(substance) ||
                      m.substance.toLowerCase().contains(key) ||
                      m.substance.toLowerCase().contains(substance)),
              orElse: () => null,
            );

        if (inventoryMatch != null) {
          final remaining = inventoryMatch.remaining;
          final remainingDisp = inventoryMatch.remainingDisplay;
          final boxName = inventoryMatch.boxId == 1 ? 'Домашняя аптечка' : 'Автомобильная';

          if (remaining >= needed) {
            items.add(
              PrescribedMedicineItem(
                name: display,
                dosage: defaultDosage,
                status: MedicineStockStatus.inStock,
                locationInfo: '$boxName, $remainingDisp шт.',
                remainingCount: remaining,
                neededCount: needed.toDouble(),
              ),
            );
          } else {
            final deficit = ParseHelper.formatQuantity(needed - remaining);
            items.add(
              PrescribedMedicineItem(
                name: display,
                dosage: defaultDosage,
                status: MedicineStockStatus.lowStock,
                locationInfo: '$boxName, $remainingDisp шт. (нужно еще $deficit)',
                remainingCount: remaining,
                neededCount: needed.toDouble(),
              ),
            );
          }
        } else {
          // Препарат отсутствует в аптечке
          items.add(
            PrescribedMedicineItem(
              name: display,
              dosage: defaultDosage,
              status: MedicineStockStatus.missing,
              locationInfo: 'Отсутствует в аптечке',
              remainingCount: 0,
              neededCount: needed.toDouble(),
            ),
          );
        }
      }
    }

    // Дополнительно проверяем прямое наличие препаратов из аптечки пользователя
    for (final med in inventory) {
      final medNameLower = med.name.toLowerCase();
      if (medNameLower.length >= 4 && lowerText.contains(medNameLower)) {
        if (matchedKeys.contains(medNameLower) || matchedKeys.contains(med.substance.toLowerCase())) continue;
        matchedKeys.add(medNameLower);

        final remaining = med.remaining;
        final remainingDisp = med.remainingDisplay;
        final boxName = med.boxId == 1 ? 'Домашняя аптечка' : 'Автомобильная';

        if (remaining > 0) {
          items.add(
            PrescribedMedicineItem(
              name: med.name,
              dosage: 'По назначению врача',
              status: MedicineStockStatus.inStock,
              locationInfo: '$boxName, $remainingDisp шт.',
              remainingCount: remaining,
              neededCount: 1,
            ),
          );
        }
      }
    }

    return items;
  }
}
