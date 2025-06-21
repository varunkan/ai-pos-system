enum UserRole {
  admin,
  server,
  manager,
  cashier,
}

/// Represents a user in the POS system.
class User {
  final String id;
  final String name;
  final UserRole role;
  final String pin;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastLogin;

  /// Creates a [User].
  User({
    required this.id,
    required this.name,
    required this.role,
    required this.pin,
    this.isActive = true,
    DateTime? createdAt,
    this.lastLogin,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Returns true if the user is an admin.
  bool get isAdmin => role == UserRole.admin;

  /// Creates a [User] from JSON, with null safety and defaults.
  factory User.fromJson(Map<String, dynamic> json) {
    try {
      return User(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        role: UserRole.values.firstWhere(
          (e) => e.toString().split('.').last == (json['role'] ?? '').toString(),
          orElse: () => UserRole.server,
        ),
        pin: json['pin'] as String? ?? '0000',
        isActive: json['isActive'] as bool? ?? true,
        createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) ?? DateTime.now() : DateTime.now(),
        lastLogin: json['lastLogin'] != null ? DateTime.tryParse(json['lastLogin']) : null,
      );
    } catch (e) {
      return User(id: '', name: '', role: UserRole.server, pin: '0000');
    }
  }

  /// Converts this [User] to JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'role': role.toString().split('.').last,
      'pin': pin,
      'isActive': isActive,
      'createdAt': createdAt.toIso8601String(),
      'lastLogin': lastLogin?.toIso8601String(),
    };
  }

  /// Returns a copy of this [User] with updated fields.
  User copyWith({
    String? id,
    String? name,
    UserRole? role,
    String? pin,
    bool? isActive,
    DateTime? createdAt,
    DateTime? lastLogin,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      pin: pin ?? this.pin,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }
} 