class User {
  final int id;
  final String name;
  final String email;
  final String? avatar;
  final bool isAdmin;

  const User({
    required this.id,
    required this.name,
    required this.email,
    this.avatar,
    this.isAdmin = false,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? json['email'] as String? ?? '',
      email: json['email'] as String? ?? '',
      avatar: json['avatar'] as String?,
      isAdmin: json['is_admin'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'avatar': avatar,
      'is_admin': isAdmin,
    };
  }
}
