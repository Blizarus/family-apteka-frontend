import '../utils/parse_helper.dart';

class MedicineBox {
  final int id;
  final String name;
  final String location;
  final int count;
  final String icon;
  final String boxType;

  const MedicineBox({
    required this.id,
    required this.name,
    required this.location,
    required this.count,
    required this.icon,
    this.boxType = 'home',
  });

  static String getIconForBoxType(String boxType) {
    switch (boxType.toLowerCase()) {
      case 'home':
        return '🏠';
      case 'car':
        return '🚗';
      case 'child':
        return '👶';
      case 'travel':
        return '✈️';
      case 'custom':
      default:
        return '📦';
    }
  }

  factory MedicineBox.fromJson(Map<String, dynamic> json) {
    final boxType = json['box_type']?.toString().toLowerCase() ?? 'home';
    String icon = json['icon'] as String? ?? getIconForBoxType(boxType);

    final location = json['location'] as String? ??
        json['description'] as String? ??
        '';

    final defaultFallback = boxType == 'car' ? 6 : (boxType == 'child' ? 4 : (boxType == 'home' ? 14 : 0));
    final count = ParseHelper.parseInt(
      json['count'] ?? json['medicines_count'],
      defaultFallback,
    );

    return MedicineBox(
      id: ParseHelper.parseInt(json['id']),
      name: json['name'] as String? ?? '',
      location: location,
      count: count,
      icon: icon,
      boxType: boxType,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'location': location,
      'count': count,
      'icon': icon,
      'box_type': boxType,
    };
  }

  MedicineBox copyWith({
    int? id,
    String? name,
    String? location,
    int? count,
    String? icon,
    String? boxType,
  }) {
    return MedicineBox(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      count: count ?? this.count,
      icon: icon ?? this.icon,
      boxType: boxType ?? this.boxType,
    );
  }
}
