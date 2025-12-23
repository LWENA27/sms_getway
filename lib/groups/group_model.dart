/// Group and GroupMember Data Models
class Group {
  final String id;
  final String userId;
  final String? tenantId;
  final String name;
  final DateTime createdAt;
  final int? memberCount;

  Group({
    required this.id,
    required this.userId,
    this.tenantId,
    required this.name,
    required this.createdAt,
    this.memberCount,
  });

  /// Create Group from JSON (Supabase response)
  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      tenantId: json['tenant_id'] as String?,
      name: json['name'] ?? json['group_name'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Convert Group to JSON (for sending to API)
  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        if (tenantId != null) 'tenant_id': tenantId,
        'name': name,
        'created_at': createdAt.toIso8601String(),
      };

  /// Create a copy of Group with modified fields
  Group copyWith({
    String? id,
    String? userId,
    String? tenantId,
    String? name,
    DateTime? createdAt,
    int? memberCount,
  }) {
    return Group(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      tenantId: tenantId ?? this.tenantId,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      memberCount: memberCount ?? this.memberCount,
    );
  }

  @override
  String toString() => 'Group(id: $id, name: $name, members: $memberCount)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Group &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          name == other.name;

  @override
  int get hashCode => id.hashCode ^ name.hashCode;
}

/// GroupMember Model (joining table)
class GroupMember {
  final String id;
  final String groupId;
  final String contactId;
  final String? tenantId;
  final DateTime addedAt;

  GroupMember({
    required this.id,
    required this.groupId,
    required this.contactId,
    this.tenantId,
    required this.addedAt,
  });

  /// Create GroupMember from JSON (Supabase response)
  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      contactId: json['contact_id'] as String,
      tenantId: json['tenant_id'] as String?,
      addedAt: DateTime.parse(
        json['added_at'] as String? ?? json['created_at'] as String,
      ),
    );
  }

  /// Convert GroupMember to JSON (for sending to API)
  Map<String, dynamic> toJson() => {
        'group_id': groupId,
        'contact_id': contactId,
        if (tenantId != null) 'tenant_id': tenantId,
      };

  @override
  String toString() => 'GroupMember(groupId: $groupId, contactId: $contactId)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroupMember &&
          runtimeType == other.runtimeType &&
          groupId == other.groupId &&
          contactId == other.contactId;

  @override
  int get hashCode => groupId.hashCode ^ contactId.hashCode;
}
