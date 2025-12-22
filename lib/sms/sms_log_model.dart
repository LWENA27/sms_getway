/// SMS Log Data Model
class SmsLog {
  final String id;
  final String userId;
  final String sender; // Phone number or sender ID
  final String recipient; // Phone number
  final String message;
  final String status; // sent, failed, delivered, pending
  final String? errorMessage;
  final DateTime createdAt;

  SmsLog({
    required this.id,
    required this.userId,
    required this.sender,
    required this.recipient,
    required this.message,
    required this.status,
    this.errorMessage,
    required this.createdAt,
  });

  /// Create SmsLog from JSON (Supabase response)
  factory SmsLog.fromJson(Map<String, dynamic> json) {
    return SmsLog(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      sender: json['sender'] as String,
      recipient: json['recipient'] as String,
      message: json['message'] as String,
      status: json['status'] as String,
      errorMessage: json['error_message'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Convert SmsLog to JSON (for sending to API)
  Map<String, dynamic> toJson() => {
    'user_id': userId,
    'sender': sender,
    'recipient': recipient,
    'message': message,
    'status': status,
    'error_message': errorMessage,
  };

  /// Create a copy of SmsLog with modified fields
  SmsLog copyWith({
    String? id,
    String? userId,
    String? sender,
    String? recipient,
    String? message,
    String? status,
    String? errorMessage,
    DateTime? createdAt,
  }) {
    return SmsLog(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      sender: sender ?? this.sender,
      recipient: recipient ?? this.recipient,
      message: message ?? this.message,
      status: status ?? this.status,
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
      'SmsLog(id: $id, recipient: $recipient, status: $status, sent: ${createdAt.toLocal()})';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SmsLog && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
