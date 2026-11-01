import '../utils/parse_helper.dart';

class Profile {
  final int id;
  final String name;
  final String role;
  final String avatar;
  final String subtitle;
  final bool isOwner;
  final String notes;
  final List<String> allergies;
  final String? birthDate;

  const Profile({
    required this.id,
    required this.name,
    required this.role,
    required this.avatar,
    required this.subtitle,
    this.isOwner = false,
    this.notes = '',
    this.allergies = const [],
    this.birthDate,
  });

  factory Profile.fromJson(Map<String, dynamic> json) {
    final rawNotes = json['notes']?.toString() ?? '';
    final id = ParseHelper.parseInt(json['id']);
    final isOwner = json['isOwner'] as bool? ??
        (rawNotes.toLowerCase().contains('владелец') || (id == 1));

    final activeCount = ParseHelper.parseInt(json['active_courses_count'], 1);
    String countText = '$activeCount курс сегодня';
    if (activeCount == 2 || activeCount == 3 || activeCount == 4) {
      countText = '$activeCount курса сегодня';
    } else if (activeCount > 4 || activeCount == 0) {
      countText = '$activeCount курсов сегодня';
    }

    final subtitle = json['subtitle'] as String? ?? countText;
    final name = json['name'] as String? ?? 'Профиль';

    String defaultRole = isOwner ? 'Вы / Владелец' : 'Член семьи';
    final lowerName = name.toLowerCase();
    if (lowerName.contains('сын') || lowerName.contains('миша') || lowerName.contains('ребёнок')) {
      defaultRole = 'Ребёнок';
    } else if (rawNotes.isNotEmpty &&
        (rawNotes == 'Ребёнок' || rawNotes == 'Родитель' || rawNotes == 'Родственник')) {
      defaultRole = rawNotes;
    }

    final role = json['role'] as String? ?? defaultRole;
    final avatar = json['avatar'] as String? ?? json['avatar_url'] as String? ?? '👤';

    List<String> allergiesList = [];
    if (json['allergies'] is List) {
      allergiesList = (json['allergies'] as List).map((e) => e.toString()).toList();
    }
    final birthDate = json['birth_date']?.toString();

    return Profile(
      id: id,
      name: name,
      role: role,
      avatar: avatar,
      subtitle: subtitle,
      isOwner: isOwner,
      notes: rawNotes,
      allergies: allergiesList,
      birthDate: birthDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'role': role,
      'avatar': avatar,
      'subtitle': subtitle,
      'isOwner': isOwner,
      'notes': notes,
      'allergies': allergies,
      'birth_date': birthDate,
    };
  }

  Profile copyWith({
    int? id,
    String? name,
    String? role,
    String? avatar,
    String? subtitle,
    bool? isOwner,
    String? notes,
    List<String>? allergies,
    String? birthDate,
  }) {
    return Profile(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      avatar: avatar ?? this.avatar,
      subtitle: subtitle ?? this.subtitle,
      isOwner: isOwner ?? this.isOwner,
      notes: notes ?? this.notes,
      allergies: allergies ?? this.allergies,
      birthDate: birthDate ?? this.birthDate,
    );
  }
}
