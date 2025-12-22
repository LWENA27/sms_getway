/// SMS Log Data Model
class SmsLog {
  final String id;
  final String userId;
  final String? contactId;
  final String phoneNumber;
  final String message;
  final String status; // sent, failed, delivered, pending
  final DateTime? sentAt;
  final String? errorMessage;
  final DateTime createdAt;

  SmsLog({
    required this.id,
    required this.userId,
    this.contactId,
    required this.phoneNumber,
    required this.message,
    required this.status,
    this.sentAt,
    this.errorMessage,
    required this.createdAt,
  });

  /// Create SmsLog from JSON (Supabase response)
  factory SmsLog.fromJson(Map<String, dynamic> json) {
    return SmsLog(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      contactId: json['contact_id'] as String?,
      phoneNumber: json['phone_number'] ?? json['recipient'] as String,
      message: json['message'] as String,
      status: json['status'] as String,
      sentAt: json['sent_at'] != null
          ? DateTime.parse(json['sent_at'] as String)
          : null,
      errorMessage: json['error_message'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Convert SmsLog to JSON (for sending to API)
  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'contact_id': contactId,
        'phone_number': phoneNumber,
        'message': message,
        'status': status,
        'sent_at': sentAt?.toIso8601String(),
        'error_message': errorMessage,
        'created_at': createdAt.toIso8601String(),
      };

  /// Create a copy of SmsLog with modified fields
  SmsLog copyWith({
    String? id,
    String? userId,
    String? contactId,
    String? phoneNumber,
    String? message,
    String? status,
    DateTime? sentAt,
    String? errorMessage,
    DateTime? createdAt,
  }) {
    return SmsLog(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      contactId: contactId ?? this.contactId,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      message: message ?? this.message,
      status: status ?? this.status,
      sentAt: sentAt ?? this.sentAt,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Check if SMS was successfully sent
  bool get isSent => status == 'sent' || status == 'delivered';
  bool get isFailed => status == 'failed';
  bool get isPending => status == 'pending';

  @override
  String toString() =>
      'SmsLog(id: $id, phoneNumber: $phoneNumber, status: $status, sent: ${createdAt.toLocal()})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SmsLog && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
