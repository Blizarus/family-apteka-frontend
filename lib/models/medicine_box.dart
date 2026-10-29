class MedicineBox {
  final int id;
  final String name;
  final String location;
  final int count;
  final String icon;

  const MedicineBox({
    required this.id,
    required this.name,
    required this.location,
    required this.count,
    required this.icon,
  });

  factory MedicineBox.fromJson(Map<String, dynamic> json) {
    String icon = json['icon'] as String? ?? '📦';
    final boxType = json['box_type']?.toString().toLowerCase();
    if (boxType == 'home') {
      icon = '🏠';
    } else if (boxType == 'car') {
      icon = '🚗';
    } else if (boxType == 'child') {
      icon = '🧸';
    }

    final location = json['location'] as String? ??
        json['description'] as String? ??
        '';

    final count = (json['count'] as num?)?.toInt() ??
        (json['medicines_count'] as num?)?.toInt() ??
        (boxType == 'car' ? 6 : (boxType == 'child' ? 4 : 14));

    return MedicineBox(
      id: json['id'] as int,
      name: json['name'] as String,
      location: location,
      count: count,
      icon: icon,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'location': location,
      'count': count,
      'icon': icon,
    };
  }

  MedicineBox copyWith({
    int? id,
    String? name,
    String? location,
    int? count,
    String? icon,
  }) {
    return MedicineBox(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      count: count ?? this.count,
      icon: icon ?? this.icon,
    );
  }
}
