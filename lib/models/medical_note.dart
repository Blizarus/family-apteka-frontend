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
  final int remainingCount;
  final int neededCount;

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
      remainingCount: (json['remainingCount'] as num?)?.toInt() ?? 0,
      neededCount: (json['neededCount'] as num?)?.toInt() ?? 0,
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
      id: (json['id'] as num?)?.toInt() ?? 0,
      profileId: (json['profileId'] as num?)?.toInt() ?? 1,
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

  /// Умный парсер назначений: анализирует текст рецепта/заметки
  /// и сопоставляет упомянутые препараты с реальным инвентарем аптечки пользователя.
  static List<PrescribedMedicineItem> parseAndMatch(
    String text,
    List<Medicine> inventory,
  ) {
    if (text.trim().isEmpty) return [];

    final lowerText = text.toLowerCase();
    final items = <PrescribedMedicineItem>[];

    // База известных медикаментов для интеллектуального парсинга
    final knownKeywords = <Map<String, dynamic>>[
      {
        'keyword': 'нурофен',
        'substance': 'ибупрофен',
        'display': 'Нурофен / Ибупрофен',
        'defaultDosage': '400 мг при t > 38.5°',
        'needed': 10,
      },
      {
        'keyword': 'ибупрофен',
        'substance': 'ибупрофен',
        'display': 'Ибупрофен',
        'defaultDosage': '400 мг 2-3 раза в день',
        'needed': 10,
      },
      {
        'keyword': 'амоксиклав',
        'substance': 'амоксициллин',
        'display': 'Амоксиклав',
        'defaultDosage': '500 мг 2 раза в день 7 дней',
        'needed': 14,
      },
      {
        'keyword': 'амоксициллин',
        'substance': 'амоксициллин',
        'display': 'Амоксициллин',
        'defaultDosage': '500 мг 3 раза в день',
        'needed': 14,
      },
      {
        'keyword': 'омепразол',
        'substance': 'омепразол',
        'display': 'Омепразол',
        'defaultDosage': '20 мг утром до еды',
        'needed': 14,
      },
      {
        'keyword': 'гексорал',
        'substance': 'гексэтидин',
        'display': 'Гексорал спрей',
        'defaultDosage': 'Спрей 2 раза в день',
        'needed': 1,
      },
      {
        'keyword': 'називин',
        'substance': 'оксиметазолин',
        'display': 'Називин 0.05%',
        'defaultDosage': '1 впрыск 2-3 р/день (до 5 дней)',
        'needed': 1,
      },
      {
        'keyword': 'супрастин',
        'substance': 'хлоропирамин',
        'display': 'Супрастин',
        'defaultDosage': '25 мг на ночь',
        'needed': 5,
      },
      {
        'keyword': 'кардиомагнил',
        'substance': 'ацетилсалициловая кислота',
        'display': 'Кардиомагнил',
        'defaultDosage': '75 мг вечером',
        'needed': 30,
      },
      {
        'keyword': 'лоперамид',
        'substance': 'лоперамид',
        'display': 'Лоперамид',
        'defaultDosage': '2 мг после жидкого стула',
        'needed': 6,
      },
      {
        'keyword': 'мирамистин',
        'substance': 'бензилдиметил',
        'display': 'Мирамистин',
        'defaultDosage': 'Полоскание 3 р/день',
        'needed': 1,
      },
    ];

    final matchedKeys = <String>{};

    for (final kw in knownKeywords) {
      final key = kw['keyword'] as String;
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
          final boxName = inventoryMatch.boxId == 1 ? 'Домашняя аптечка' : 'Автомобильная';

          if (remaining >= needed) {
            items.add(
              PrescribedMedicineItem(
                name: display,
                dosage: defaultDosage,
                status: MedicineStockStatus.inStock,
                locationInfo: '$boxName, $remaining шт.',
                remainingCount: remaining,
                neededCount: needed,
              ),
            );
          } else {
            final deficit = needed - remaining;
            items.add(
              PrescribedMedicineItem(
                name: display,
                dosage: defaultDosage,
                status: MedicineStockStatus.lowStock,
                locationInfo: '$boxName, $remaining шт. (нужно еще $deficit)',
                remainingCount: remaining,
                neededCount: needed,
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
              neededCount: needed,
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
        final boxName = med.boxId == 1 ? 'Домашняя аптечка' : 'Автомобильная';

        if (remaining > 0) {
          items.add(
            PrescribedMedicineItem(
              name: med.name,
              dosage: 'По назначению врача',
              status: MedicineStockStatus.inStock,
              locationInfo: '$boxName, $remaining шт.',
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
