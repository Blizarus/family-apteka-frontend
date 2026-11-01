import '../utils/parse_helper.dart';

class ReferenceMedicine {
  final int id;
  final String tradeName;
  final String inn;
  final String dosageForm;
  final String dosage;
  final int packSize;
  final String manufacturer;
  final String country;
  final String atcCode;
  final String barcode;
  final bool isPrescription;
  final String composition;
  final List<String> allergenTags;
  final Map<String, dynamic> instructions;
  final String? leafletPdfUrl;

  const ReferenceMedicine({
    required this.id,
    required this.tradeName,
    required this.inn,
    required this.dosageForm,
    required this.dosage,
    required this.packSize,
    required this.manufacturer,
    required this.country,
    required this.atcCode,
    required this.barcode,
    required this.isPrescription,
    required this.composition,
    required this.allergenTags,
    required this.instructions,
    this.leafletPdfUrl,
  });

  factory ReferenceMedicine.fromJson(Map<String, dynamic> json) {
    List<String> tags = [];
    if (json['allergen_tags'] is List) {
      tags = (json['allergen_tags'] as List).map((e) => e.toString()).toList();
    }

    Map<String, dynamic> instr = {};
    if (json['instructions'] is Map) {
      instr = Map<String, dynamic>.from(json['instructions'] as Map);
    }

    return ReferenceMedicine(
      id: ParseHelper.parseInt(json['id']),
      tradeName: json['trade_name'] as String? ?? '',
      inn: json['inn'] as String? ?? '',
      dosageForm: json['dosage_form'] as String? ?? 'Таблетки',
      dosage: json['dosage'] as String? ?? '',
      packSize: ParseHelper.parseInt(json['pack_size'], 1),
      manufacturer: json['manufacturer'] as String? ?? 'Фармпроизводитель',
      country: json['country'] as String? ?? 'Россия',
      atcCode: json['atc_code'] as String? ?? '',
      barcode: json['barcode'] as String? ?? '',
      isPrescription: json['is_prescription'] as bool? ?? false,
      composition: json['composition'] as String? ?? '',
      allergenTags: tags,
      instructions: instr,
      leafletPdfUrl: json['leaflet_pdf_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'trade_name': tradeName,
      'inn': inn,
      'dosage_form': dosageForm,
      'dosage': dosage,
      'pack_size': packSize,
      'manufacturer': manufacturer,
      'country': country,
      'atc_code': atcCode,
      'barcode': barcode,
      'is_prescription': isPrescription,
      'composition': composition,
      'allergen_tags': allergenTags,
      'instructions': instructions,
      'leaflet_pdf_url': leafletPdfUrl,
    };
  }
}
