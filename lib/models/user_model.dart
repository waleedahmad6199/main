// models/user_model.dart

enum UserRole { admin, member, viewer }

class UserModel {
  final String id;
  final String email;
  final String name;
  final String? photoUrl;
  final UserRole role;
  final List<String> projectIds;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.photoUrl,
    required this.role,
    required this.projectIds,
    required this.createdAt,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      email: map['email'] as String? ?? '',
      name: map['name'] as String? ?? '',
      photoUrl: map['photoUrl'] as String?,
      role: _roleFromString(map['role'] as String? ?? 'member'),
      projectIds: List<String>.from(map['projectIds'] as List? ?? []),
      createdAt: (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'photoUrl': photoUrl,
      'role': role.name,
      'projectIds': projectIds,
      'createdAt': createdAt,
    };
  }

  static UserRole _roleFromString(String s) {
    switch (s) {
      case 'admin':
        return UserRole.admin;
      case 'viewer':
        return UserRole.viewer;
      default:
        return UserRole.member;
    }
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? photoUrl,
    UserRole? role,
    List<String>? projectIds,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
      role: role ?? this.role,
      projectIds: projectIds ?? this.projectIds,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}