/// Contact Data Model
class Contact {
  final String id;
  final String userId;
  final String? tenantId;
  final String name; // Keep for backward compatibility
  final String? firstName; // New field for marketing personalization
  final String? lastName; // New field for marketing personalization
  final String phoneNumber;
  final DateTime createdAt;

  Contact({
    required this.id,
    required this.userId,
    this.tenantId,
    required this.name,
    this.firstName,
    this.lastName,
    required this.phoneNumber,
    required this.createdAt,
  });

  /// Create Contact from JSON (Supabase response)
  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      tenantId: json['tenant_id'] as String?,
      name: json['name'] as String,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      phoneNumber: json['phone_number'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Convert Contact to JSON (for sending to API)
  Map<String, dynamic> toJson() => {
        'user_id': userId,
        if (tenantId != null) 'tenant_id': tenantId,
        'name': name,
        if (firstName != null) 'first_name': firstName,
        if (lastName != null) 'last_name': lastName,
        'phone_number': phoneNumber,
      };

  /// Get full name (firstName + lastName) or fallback to name
  String get fullName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    } else if (firstName != null) {
      return firstName!;
    } else if (lastName != null) {
      return lastName!;
    }
    return name;
  }

  /// Create a copy of Contact with modified fields
  Contact copyWith({
    String? id,
    String? userId,
    String? tenantId,
    String? name,
    String? firstName,
    String? lastName,
    String? phoneNumber,
    DateTime? createdAt,
  }) {
    return Contact(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      tenantId: tenantId ?? this.tenantId,
      name: name ?? this.name,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() =>
      'Contact(id: $id, name: $name, phoneNumber: $phoneNumber)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Contact &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          phoneNumber == other.phoneNumber;

  @override
  int get hashCode => id.hashCode ^ phoneNumber.hashCode;
}
