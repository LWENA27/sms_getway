/// Supabase Service - Backend API integration
library;
// Note: This is a template. Implement this with actual supabase_flutter package

class SupabaseService {
  // static final SupabaseClient _supabaseClient = Supabase.instance.client;

  // ===== AUTHENTICATION =====

  /// Sign up new user
  // Future<AuthResponse> signUp({
  //   required String email,
  //   required String password,
  //   required String name,
  // }) async {
  //   return await _supabaseClient.auth.signUp(
  //     email: email,
  //     password: password,
  //     data: {'name': name},
  //   );
  // }

  /// Login user
  // Future<AuthResponse> login({
  //   required String email,
  //   required String password,
  // }) async {
  //   return await _supabaseClient.auth.signInWithPassword(
  //     email: email,
  //     password: password,
  //   );
  // }

  /// Logout user
  // Future<void> logout() async {
  //   return await _supabaseClient.auth.signOut();
  // }

  /// Get current user
  // User? get currentUser => _supabaseClient.auth.currentUser;

  // ===== CONTACTS =====

  /// Get all contacts for user
  // Future<List<Contact>> getContacts(String userId) async {
  //   final response = await _supabaseClient
  //       .from('contacts')
  //       .select()
  //       .eq('user_id', userId);
  //
  //   return (response as List)
  //       .map((json) => Contact.fromJson(json))
  //       .toList();
  // }

  /// Add new contact
  // Future<Contact> addContact(Contact contact) async {
  //   final response = await _supabaseClient
  //       .from('contacts')
  //       .insert(contact.toJson())
  //       .select()
  //       .single();
  //
  //   return Contact.fromJson(response);
  // }

  /// Delete contact
  // Future<void> deleteContact(String contactId) async {
  //   await _supabaseClient
  //       .from('contacts')
  //       .delete()
  //       .eq('id', contactId);
  // }

  // ===== GROUPS =====

  /// Get all groups for user
  // Future<List<Group>> getGroups(String userId) async {
  //   final response = await _supabaseClient
  //       .from('groups')
  //       .select()
  //       .eq('user_id', userId);
  //
  //   return (response as List)
  //       .map((json) => Group.fromJson(json))
  //       .toList();
  // }

  /// Create new group
  // Future<Group> createGroup(Group group) async {
  //   final response = await _supabaseClient
  //       .from('groups')
  //       .insert(group.toJson())
  //       .select()
  //       .single();
  //
  //   return Group.fromJson(response);
  // }

  /// Add member to group
  // Future<void> addGroupMember(String groupId, String contactId) async {
  //   await _supabaseClient
  //       .from('group_members')
  //       .insert({'group_id': groupId, 'contact_id': contactId});
  // }

  /// Remove member from group
  // Future<void> removeGroupMember(String groupId, String contactId) async {
  //   await _supabaseClient
  //       .from('group_members')
  //       .delete()
  //       .eq('group_id', groupId)
  //       .eq('contact_id', contactId);
  // }

  // ===== SMS LOGS =====

  /// Get SMS logs for user
  // Future<List<SmsLog>> getSmsLogs(String userId, {int limit = 100}) async {
  //   final response = await _supabaseClient
  //       .from('sms_logs')
  //       .select()
  //       .eq('user_id', userId)
  //       .order('created_at', ascending: false)
  //       .limit(limit);
  //
  //   return (response as List)
  //       .map((json) => SmsLog.fromJson(json))
  //       .toList();
  // }

  /// Log SMS
  // Future<SmsLog> logSms(SmsLog log) async {
  //   final response = await _supabaseClient
  //       .from('sms_logs')
  //       .insert(log.toJson())
  //       .select()
  //       .single();
  //
  //   return SmsLog.fromJson(response);
  // }

  /// Update SMS status
  // Future<void> updateSmsStatus(String logId, String status, {String? errorMessage}) async {
  //   await _supabaseClient
  //       .from('sms_logs')
  //       .update({
  //         'status': status,
  //         'error_message': errorMessage,
  //       })
  //       .eq('id', logId);
  // }
}

// ===== USAGE EXAMPLE =====
/*
// Initialize Supabase
await Supabase.initialize(
  url: 'YOUR_SUPABASE_URL',
  anonKey: 'YOUR_SUPABASE_ANON_KEY',
);

// Login
await SupabaseService.login(
  email: 'user@example.com',
  password: 'password',
);

// Add contact
await SupabaseService.addContact(Contact(
  id: 'unique-id',
  userId: userId,
  name: 'John Doe',
  phoneNumber: '+255712345678',
  createdAt: DateTime.now(),
));

// Send SMS (see sms_sender.dart for implementation)
*/
