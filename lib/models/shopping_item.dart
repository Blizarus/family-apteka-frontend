class ShoppingItem {
  final String id;
  final String name;
  final int count;
  final String dosage;
  final bool isPurchased;
  final int? profileId;
  final String? patientName;
  final String? category;
  final String? sourceDescription;
  final int? sourceNoteId;

  const ShoppingItem({
    required this.id,
    required this.name,
    this.count = 1,
    this.dosage = '',
    this.isPurchased = false,
    this.profileId,
    this.patientName,
    this.category,
    this.sourceDescription,
    this.sourceNoteId,
  });

  ShoppingItem copyWith({
    String? id,
    String? name,
    int? count,
    String? dosage,
    bool? isPurchased,
    int? profileId,
    String? patientName,
    String? category,
    String? sourceDescription,
    int? sourceNoteId,
  }) {
    return ShoppingItem(
      id: id ?? this.id,
      name: name ?? this.name,
      count: count ?? this.count,
      dosage: dosage ?? this.dosage,
      isPurchased: isPurchased ?? this.isPurchased,
      profileId: profileId ?? this.profileId,
      patientName: patientName ?? this.patientName,
      category: category ?? this.category,
      sourceDescription: sourceDescription ?? this.sourceDescription,
      sourceNoteId: sourceNoteId ?? this.sourceNoteId,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'count': count,
        'dosage': dosage,
        'isPurchased': isPurchased,
        'profile_id': profileId,
        'patient_name': patientName,
        'category': category,
        'source_description': sourceDescription,
        'source_note_id': sourceNoteId,
      };

  factory ShoppingItem.fromJson(Map<String, dynamic> json) {
    return ShoppingItem(
      id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: json['name'] as String? ?? '',
      count: (json['count'] as num?)?.toInt() ?? 1,
      dosage: json['dosage'] as String? ?? '',
      isPurchased: json['isPurchased'] as bool? ?? false,
      profileId: (json['profile_id'] as num?)?.toInt(),
      patientName: json['patient_name'] as String?,
      category: json['category'] as String?,
      sourceDescription: json['source_description'] as String?,
      sourceNoteId: (json['source_note_id'] as num?)?.toInt(),
    );
  }
}
