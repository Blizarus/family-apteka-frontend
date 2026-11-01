import 'reference_medicine.dart';

class Medicine {
  final int id;
  final int boxId;
  final String name;
  final String substance;
  final String form;
  final int remaining;
  final int total;
  final String expiry;
  final String status; // 'ok' | 'expiring' | 'expired'
  final int? referenceMedicineId;
  final ReferenceMedicine? referenceMedicine;
  final String composition;
  final List<String> allergenTags;
  final Map<String, dynamic> instructions;
  final String manufacturer;
  final String country;
  final String atcCode;
  final String barcode;
  final bool isPrescription;
  final String quantityUnit;
  final DateTime? openedAt;
  final int? daysAfterOpening;
  final DateTime? effectiveExpirationDate;

  const Medicine({
    required this.id,
    required this.boxId,
    required this.name,
    required this.substance,
    required this.form,
    required this.remaining,
    required this.total,
    required this.expiry,
    required this.status,
    this.referenceMedicineId,
    this.referenceMedicine,
    this.composition = '',
    this.allergenTags = const [],
    this.instructions = const {},
    this.manufacturer = '',
    this.country = '',
    this.atcCode = '',
    this.barcode = '',
    this.isPrescription = false,
    this.quantityUnit = 'pill',
    this.openedAt,
    this.daysAfterOpening,
    this.effectiveExpirationDate,
  });

  bool get isOk => status == 'ok';
  bool get isExpiring => status == 'expiring';
  bool get isExpired => status == 'expired';
  bool get isOpened => openedAt != null;
  int? get daysUntilExpiration => effectiveExpirationDate?.difference(DateTime.now()).inDays;

  factory Medicine.fromJson(Map<String, dynamic> json) {
    ReferenceMedicine? refMed;
    if (json['reference_medicine'] is Map<String, dynamic>) {
      refMed = ReferenceMedicine.fromJson(json['reference_medicine'] as Map<String, dynamic>);
    } else if (json['referenceMedicine'] is Map<String, dynamic>) {
      refMed = ReferenceMedicine.fromJson(json['referenceMedicine'] as Map<String, dynamic>);
    }

    final name = json['name'] as String? ??
        json['custom_trade_name'] as String? ??
        refMed?.tradeName ??
        'Лекарство';

    final substance = json['substance'] as String? ??
        refMed?.inn ??
        '';

    final form = json['form'] as String? ??
        refMed?.dosageForm ??
        'Таблетки';

    final rawRemaining = json['remaining'] ?? json['quantity'];
    final remaining = rawRemaining is num
        ? rawRemaining.toInt()
        : (double.tryParse(rawRemaining?.toString() ?? '') ?? 0).toInt();

    final rawTotal = json['total'] ?? refMed?.packSize ?? remaining;
    final total = rawTotal is num
        ? rawTotal.toInt()
        : (double.tryParse(rawTotal?.toString() ?? '') ?? remaining).toInt();

    // Dates parsing
    String expiry = json['expiry'] as String? ?? '';
    final rawExpDate = json['expiration_date']?.toString();
    DateTime? baseExpDate;
    if (rawExpDate != null && rawExpDate.isNotEmpty) {
      baseExpDate = DateTime.tryParse(rawExpDate);
    }

    DateTime? openedAt;
    if (json['opened_at'] != null) {
      if (json['opened_at'] is DateTime) {
        openedAt = json['opened_at'] as DateTime;
      } else {
        openedAt = DateTime.tryParse(json['opened_at'].toString());
      }
    } else if (json['openedAt'] != null) {
      if (json['openedAt'] is DateTime) {
        openedAt = json['openedAt'] as DateTime;
      } else {
        openedAt = DateTime.tryParse(json['openedAt'].toString());
      }
    }

    final daysAfterOpening = (json['days_after_opening'] as num?)?.toInt() ??
        (json['daysAfterOpening'] as num?)?.toInt();

    DateTime? effectiveExpirationDate;
    if (json['effective_expiration_date'] != null) {
      if (json['effective_expiration_date'] is DateTime) {
        effectiveExpirationDate = json['effective_expiration_date'] as DateTime;
      } else {
        effectiveExpirationDate = DateTime.tryParse(json['effective_expiration_date'].toString());
      }
    } else if (json['effectiveExpirationDate'] != null) {
      if (json['effectiveExpirationDate'] is DateTime) {
        effectiveExpirationDate = json['effectiveExpirationDate'] as DateTime;
      } else {
        effectiveExpirationDate = DateTime.tryParse(json['effectiveExpirationDate'].toString());
      }
    }

    if (effectiveExpirationDate == null) {
      if (openedAt != null && daysAfterOpening != null && daysAfterOpening > 0) {
        final openedExp = openedAt.add(Duration(days: daysAfterOpening));
        if (baseExpDate != null) {
          effectiveExpirationDate = openedExp.isBefore(baseExpDate) ? openedExp : baseExpDate;
        } else {
          effectiveExpirationDate = openedExp;
        }
      } else if (baseExpDate != null) {
        effectiveExpirationDate = baseExpDate;
      }
    }

    if (expiry.isEmpty && effectiveExpirationDate != null) {
      final month = effectiveExpirationDate.month.toString().padLeft(2, '0');
      final year = effectiveExpirationDate.year.toString();
      expiry = '$month.$year';
    } else if (expiry.isEmpty && baseExpDate != null) {
      final month = baseExpDate.month.toString().padLeft(2, '0');
      final year = baseExpDate.year.toString();
      expiry = '$month.$year';
    }

    if (openedAt != null && !expiry.startsWith('Вскрыт')) {
      expiry = 'Вскрыт ($expiry)';
    }

    // Determine status
    String status = json['status'] as String? ?? 'ok';
    if (status == 'active' || status == 'ok') {
      final evalDate = effectiveExpirationDate ?? baseExpDate;
      if (evalDate != null) {
        final diff = evalDate.difference(DateTime.now()).inDays;
        if (diff < 0) {
          status = 'expired';
        } else if (diff <= 30) {
          status = 'expiring';
        } else {
          status = 'ok';
        }
      } else if (openedAt != null) {
        status = 'expiring';
      }
    } else if (status != 'expired' && status != 'expiring') {
      status = 'ok';
    }

    final allergenTags = refMed?.allergenTags ??
        (json['allergen_tags'] is List
            ? (json['allergen_tags'] as List).map((e) => e.toString()).toList()
            : <String>[]);

    final instructions = refMed?.instructions ??
        (json['instructions'] is Map
            ? Map<String, dynamic>.from(json['instructions'] as Map)
            : <String, dynamic>{});

    return Medicine(
      id: (json['id'] as num?)?.toInt() ?? 0,
      boxId: (json['boxId'] ?? json['medicine_box_id'] as num?)?.toInt() ?? 1,
      name: name,
      substance: substance,
      form: form,
      remaining: remaining,
      total: total > 0 ? total : remaining,
      expiry: expiry,
      status: status,
      referenceMedicineId: (json['reference_medicine_id'] as num?)?.toInt() ?? refMed?.id,
      referenceMedicine: refMed,
      composition: refMed?.composition ?? (json['composition'] as String? ?? ''),
      allergenTags: allergenTags,
      instructions: instructions,
      manufacturer: refMed?.manufacturer ?? (json['manufacturer'] as String? ?? ''),
      country: refMed?.country ?? (json['country'] as String? ?? ''),
      atcCode: refMed?.atcCode ?? (json['atc_code'] as String? ?? ''),
      barcode: json['barcode'] as String? ?? refMed?.barcode ?? '',
      isPrescription: refMed?.isPrescription ?? (json['is_prescription'] as bool? ?? false),
      quantityUnit: json['quantity_unit'] as String? ?? 'pill',
      openedAt: openedAt,
      daysAfterOpening: daysAfterOpening,
      effectiveExpirationDate: effectiveExpirationDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'boxId': boxId,
      'name': name,
      'substance': substance,
      'form': form,
      'remaining': remaining,
      'total': total,
      'expiry': expiry,
      'status': status,
      'reference_medicine_id': referenceMedicineId,
      'composition': composition,
      'allergen_tags': allergenTags,
      'instructions': instructions,
      'manufacturer': manufacturer,
      'country': country,
      'atc_code': atcCode,
      'barcode': barcode,
      'is_prescription': isPrescription,
      'quantity_unit': quantityUnit,
      'opened_at': openedAt?.toIso8601String(),
      'days_after_opening': daysAfterOpening,
      'effective_expiration_date': effectiveExpirationDate?.toIso8601String(),
    };
  }

  Medicine copyWith({
    int? id,
    int? boxId,
    String? name,
    String? substance,
    String? form,
    int? remaining,
    int? total,
    String? expiry,
    String? status,
    int? referenceMedicineId,
    ReferenceMedicine? referenceMedicine,
    String? composition,
    List<String>? allergenTags,
    Map<String, dynamic>? instructions,
    String? manufacturer,
    String? country,
    String? atcCode,
    String? barcode,
    bool? isPrescription,
    String? quantityUnit,
    DateTime? openedAt,
    int? daysAfterOpening,
    DateTime? effectiveExpirationDate,
  }) {
    return Medicine(
      id: id ?? this.id,
      boxId: boxId ?? this.boxId,
      name: name ?? this.name,
      substance: substance ?? this.substance,
      form: form ?? this.form,
      remaining: remaining ?? this.remaining,
      total: total ?? this.total,
      expiry: expiry ?? this.expiry,
      status: status ?? this.status,
      referenceMedicineId: referenceMedicineId ?? this.referenceMedicineId,
      referenceMedicine: referenceMedicine ?? this.referenceMedicine,
      composition: composition ?? this.composition,
      allergenTags: allergenTags ?? this.allergenTags,
      instructions: instructions ?? this.instructions,
      manufacturer: manufacturer ?? this.manufacturer,
      country: country ?? this.country,
      atcCode: atcCode ?? this.atcCode,
      barcode: barcode ?? this.barcode,
      isPrescription: isPrescription ?? this.isPrescription,
      quantityUnit: quantityUnit ?? this.quantityUnit,
      openedAt: openedAt ?? this.openedAt,
      daysAfterOpening: daysAfterOpening ?? this.daysAfterOpening,
      effectiveExpirationDate: effectiveExpirationDate ?? this.effectiveExpirationDate,
    );
  }
}
