/// Core Constants for SMS Gateway Application
library;

class AppConstants {
  // ===== SUPABASE CONFIGURATION =====
  static const String supabaseUrl = 'https://kzjgdeqfmxkmpmadtbpb.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt6amdkZXFmbXhrbXBtYWR0YnBiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDkyOTk3NjQsImV4cCI6MjA2NDg3NTc2NH0.NTEzbvVCQ_vNTJPS5bFPSOm5XNRjUrFpSUPEWQDm434';

  // ===== APP CONFIGURATION =====
  static const String appName = 'SMS Gateway Pro';
  static const String appVersion = '1.0.0';
  static const String appCompanyName = 'LWENATECH';
  static const String appDescription =
      'Professional Bulk SMS Management System';

  // ===== QUICKSMS API CONFIGURATION =====
  static const String quickSmsBaseUrl = 'https://api.quicksms.com.ng/v1';
  // TODO: Add your QuickSMS API key here
  static const String quickSmsApiKey = 'YOUR_QUICKSMS_API_KEY_HERE';
  static const String quickSmsSenderId = 'SMS_GATEWAY';

  // ===== RATE LIMITING =====
  static const int maxSmsPerMinute = 30;
  static const int maxSmsPerDay = 500;
  static const int maxMessageLength = 160;

  // ===== DATABASE TABLE NAMES =====
  static const String usersTable = 'users';
  static const String contactsTable = 'contacts';
  static const String groupsTable = 'groups';
  static const String groupMembersTable = 'group_members';
  static const String smsLogsTable = 'sms_logs';
  static const String apiKeysTable = 'api_keys';

  // ===== SMS STATUS CONSTANTS =====
  static const String smsSent = 'sent';
  static const String smsFailed = 'failed';
  static const String smsDelivered = 'delivered';
  static const String smsPending = 'pending';

  // ===== ERROR MESSAGES =====
  static const String errorUserNotFound = 'User not found';
  static const String errorContactNotFound = 'Contact not found';
  static const String errorGroupNotFound = 'Group not found';
  static const String errorInvalidPhoneNumber = 'Invalid phone number format';
  static const String errorEmptyMessage = 'Message cannot be empty';
  static const String errorRateLimitExceeded =
      'Rate limit exceeded. Please try again later.';
  static const String errorNetworkError =
      'Network error. Please check your connection.';

  // ===== SUCCESS MESSAGES =====
  static const String successSmsSent = 'SMS sent successfully';
  static const String successContactAdded = 'Contact added successfully';
  static const String successGroupCreated = 'Group created successfully';
  static const String successLoginSuccess = 'Login successful';

  // ===== REGEX PATTERNS =====
  static const String phonePattern = r'^\+?[0-9]{10,15}$';
  static const String emailPattern =
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';

  // ===== TIMEOUTS =====
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration smsTimeout = Duration(seconds: 60);

  // ===== LEGAL & COMPLIANCE =====
  static const String optOutKeyword = 'STOP';
  static const String optOutMessage =
      'Reply STOP to unsubscribe from this service';
}

class DeviceConstants {
  // ===== ANDROID CONSTANTS =====
  static const String sendSmsBroadcast = 'SMS_SENT';
  static const String deliverSmsBroadcast = 'SMS_DELIVERED';

  // ===== PERMISSIONS =====
  static const List<String> requiredPermissions = [
    'android.permission.SEND_SMS',
    'android.permission.READ_SMS',
    'android.permission.RECEIVE_SMS',
    'android.permission.READ_PHONE_STATE',
    'android.permission.INTERNET',
  ];
}
