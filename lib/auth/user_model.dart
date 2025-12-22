/// User Data Model
class AppUser {
  final String id;
  final String email;
  final String? name;
  final String? phoneNumber;
  final String role;
  final DateTime createdAt;

  AppUser({
    required this.id,
    required this.email,
    this.name,
    this.phoneNumber,
    this.role = 'user',
    required this.createdAt,
  });

  /// Create User from JSON (Supabase response)
  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String?,
      phoneNumber: json['phone_number'] as String?,
      role: json['role'] as String? ?? 'user',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Convert User to JSON (for sending to API)
  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'name': name,
        'phone_number': phoneNumber,
        'role': role,
      };

  /// Create a copy of User with modified fields
  AppUser copyWith({
    String? id,
    String? email,
    String? name,
    String? phoneNumber,
    String? role,
    DateTime? createdAt,
  }) {
    return AppUser(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role ?? this.role,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Check if user is admin
  bool get isAdmin => role == 'admin';

  /// Get user's display name
  String get displayName => name ?? email.split('@').first;

  @override
  String toString() =>
      'User(id: $id, email: $email, name: $displayName, role: $role)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppUser &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          email == other.email;

  @override
  int get hashCode => id.hashCode ^ email.hashCode;
}
