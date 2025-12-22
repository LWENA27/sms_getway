/// Group and GroupMember Data Models
class Group {
  final String id;
  final String userId;
  final String groupName;
  final DateTime createdAt;
  final List<String> memberIds; // Contact IDs in this group

  Group({
    required this.id,
    required this.userId,
    required this.groupName,
    required this.createdAt,
    this.memberIds = const [],
  });

  /// Create Group from JSON (Supabase response)
  factory Group.fromJson(Map<String, dynamic> json) {
    return Group(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      groupName: json['group_name'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Convert Group to JSON (for sending to API)
  Map<String, dynamic> toJson() => {'user_id': userId, 'group_name': groupName};

  /// Create a copy of Group with modified fields
  Group copyWith({
    String? id,
    String? userId,
    String? groupName,
    DateTime? createdAt,
    List<String>? memberIds,
  }) {
    return Group(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      groupName: groupName ?? this.groupName,
      createdAt: createdAt ?? this.createdAt,
      memberIds: memberIds ?? this.memberIds,
    );
  }

  @override
  String toString() =>
      'Group(id: $id, name: $groupName, members: ${memberIds.length})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Group &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          groupName == other.groupName;

  @override
  int get hashCode => id.hashCode ^ groupName.hashCode;
}

/// GroupMember Model (joining table)
class GroupMember {
  final String id;
  final String groupId;
  final String contactId;
  final DateTime addedAt;

  GroupMember({
    required this.id,
    required this.groupId,
    required this.contactId,
    required this.addedAt,
  });

  /// Create GroupMember from JSON (Supabase response)
  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      contactId: json['contact_id'] as String,
      addedAt: DateTime.parse(
        json['added_at'] as String? ?? json['created_at'] as String,
      ),
    );
  }

  /// Convert GroupMember to JSON (for sending to API)
  Map<String, dynamic> toJson() => {
    'group_id': groupId,
    'contact_id': contactId,
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
