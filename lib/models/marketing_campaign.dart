/// Marketing Campaign Model
/// Represents a marketing SMS campaign with contacts and message template
class MarketingCampaign {
  final String id;
  final String tenantId;
  final String name;
  final String messageTemplate;
  final String status; // draft, active, paused, completed, cancelled
  final int dailySentCount;
  final int totalSentCount;
  final int totalContactCount;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime? activatedAt;
  final DateTime? completedAt;

  MarketingCampaign({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.messageTemplate,
    required this.status,
    this.dailySentCount = 0,
    this.totalSentCount = 0,
    this.totalContactCount = 0,
    this.createdBy,
    required this.createdAt,
    this.activatedAt,
    this.completedAt,
  });

  factory MarketingCampaign.fromJson(Map<String, dynamic> json) {
    return MarketingCampaign(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      name: json['name'] as String,
      messageTemplate: json['message_template'] as String,
      status: json['status'] as String,
      dailySentCount: json['daily_sent_count'] as int? ?? 0,
      totalSentCount: json['total_sent_count'] as int? ?? 0,
      totalContactCount: json['total_contact_count'] as int? ?? 0,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      activatedAt: json['activated_at'] != null
          ? DateTime.parse(json['activated_at'] as String)
          : null,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'name': name,
      'message_template': messageTemplate,
      'status': status,
      'daily_sent_count': dailySentCount,
      'total_sent_count': totalSentCount,
      'total_contact_count': totalContactCount,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'activated_at': activatedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
    };
  }

  MarketingCampaign copyWith({
    String? id,
    String? tenantId,
    String? name,
    String? messageTemplate,
    String? status,
    int? dailySentCount,
    int? totalSentCount,
    int? totalContactCount,
    String? createdBy,
    DateTime? createdAt,
    DateTime? activatedAt,
    DateTime? completedAt,
  }) {
    return MarketingCampaign(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      name: name ?? this.name,
      messageTemplate: messageTemplate ?? this.messageTemplate,
      status: status ?? this.status,
      dailySentCount: dailySentCount ?? this.dailySentCount,
      totalSentCount: totalSentCount ?? this.totalSentCount,
      totalContactCount: totalContactCount ?? this.totalContactCount,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      activatedAt: activatedAt ?? this.activatedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  /// Get progress percentage (0-100)
  double get progressPercentage {
    if (totalContactCount == 0) return 0.0;
    return (totalSentCount / totalContactCount * 100).clamp(0.0, 100.0);
  }

  /// Get pending contacts count
  int get pendingCount {
    return totalContactCount - totalSentCount;
  }

  /// Check if campaign is active
  bool get isActive => status == 'active';

  /// Check if campaign is draft
  bool get isDraft => status == 'draft';

  /// Check if campaign is paused
  bool get isPaused => status == 'paused';

  /// Check if campaign is completed
  bool get isCompleted => status == 'completed';

  /// Get status color
  String get statusColor {
    switch (status) {
      case 'active':
        return '#4CAF50'; // Green
      case 'paused':
        return '#FF9800'; // Orange
      case 'completed':
        return '#2196F3'; // Blue
      case 'cancelled':
        return '#F44336'; // Red
      case 'draft':
      default:
        return '#9E9E9E'; // Grey
    }
  }

  /// Get status display text
  String get statusDisplay {
    return status[0].toUpperCase() + status.substring(1);
  }
}

/// Campaign Contact Model
/// Represents a contact assigned to a marketing campaign
class CampaignContact {
  final String id;
  final String campaignId;
  final String? contactId; // Reference to existing contact (optional)
  final String phoneNumber;
  final String? firstName;
  final String? lastName;
  final String status; // pending, sent, failed, skipped
  final DateTime? sentAt;
  final String? failureReason;

  CampaignContact({
    required this.id,
    required this.campaignId,
    this.contactId,
    required this.phoneNumber,
    this.firstName,
    this.lastName,
    this.status = 'pending',
    this.sentAt,
    this.failureReason,
  });

  factory CampaignContact.fromJson(Map<String, dynamic> json) {
    return CampaignContact(
      id: json['id'] as String,
      campaignId: json['campaign_id'] as String,
      contactId: json['contact_id'] as String?,
      phoneNumber: json['phone_number'] as String,
      firstName: json['first_name'] as String?,
      lastName: json['last_name'] as String?,
      status: json['status'] as String? ?? 'pending',
      sentAt: json['sent_at'] != null
          ? DateTime.parse(json['sent_at'] as String)
          : null,
      failureReason: json['failure_reason'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'campaign_id': campaignId,
      'contact_id': contactId,
      'phone_number': phoneNumber,
      'first_name': firstName,
      'last_name': lastName,
      'status': status,
      'sent_at': sentAt?.toIso8601String(),
      'failure_reason': failureReason,
    };
  }

  /// Get full name
  String get fullName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    } else if (firstName != null) {
      return firstName!;
    } else if (lastName != null) {
      return lastName!;
    }
    return phoneNumber;
  }

  /// Get status color
  String get statusColor {
    switch (status) {
      case 'sent':
        return '#4CAF50'; // Green
      case 'failed':
        return '#F44336'; // Red
      case 'skipped':
        return '#FF9800'; // Orange
      case 'pending':
      default:
        return '#2196F3'; // Blue
    }
  }
}
