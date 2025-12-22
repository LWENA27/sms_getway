/// Supabase Service - Backend API integration
/// MULTI-TENANT READY - All queries filter by tenant_id + user_id
library;

// Note: Uncomment when using actual supabase_flutter package
// import 'package:supabase_flutter/supabase_flutter.dart';
// import '../core/tenant_service.dart';

class SupabaseService {
  // static final SupabaseClient _supabaseClient = Supabase.instance.client;
  // static final TenantService _tenantService = TenantService();

  // ===== AUTHENTICATION =====

  /// Login user and load tenants
  /// Pattern:
  /// 1. Authenticate with email/password
  /// 2. Check if user exists in sms_gateway.profiles
  /// 3. Load user's available tenants from public.client_product_access
  /// 4. Store tenants in TenantService
  /// 5. Auto-select if 1 tenant, or return list if 2+
  /*
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      // Step 1: Authenticate
      final authResponse = await _supabaseClient.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      final userId = authResponse.user!.id;
      
      // Step 2: Check if user exists in SMS Gateway
      final profileCheck = await _supabaseClient
          .from('sms_gateway.profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      
      if (profileCheck == null) {
        throw Exception('User not registered for SMS Gateway');
      }
      
      // Step 3: Load available tenants from control plane
      final accessRecords = await _supabaseClient
          .from('public.client_product_access')
          .select()
          .eq('user_id', userId)
          .eq('product_id', (
            await _supabaseClient
              .from('public.products')
              .select('id')
              .eq('schema_name', 'sms_gateway')
              .single()
          )['id']);
      
      // Step 4: Convert to TenantModel list
      final tenants = <TenantModel>[];
      for (final record in accessRecords as List) {
        final tenantId = record['tenant_id'];
        final tenant = await _supabaseClient
            .from('sms_gateway.tenants')
            .select()
            .eq('id', tenantId)
            .single();
        
        tenants.add(TenantModel(
          id: tenant['id'],
          name: tenant['name'],
          slug: tenant['slug'],
          clientId: tenant['client_id'],
        ));
      }
      
      // Step 5: Store and handle tenant selection
      await _tenantService.setTenantsList(tenants);
      
      if (tenants.isEmpty) {
        throw Exception('User has no SMS Gateway workspace access');
      } else if (tenants.length == 1) {
        await _tenantService.selectTenant(tenants[0]);
        return {
          'success': true,
          'user': authResponse.user,
          'tenants': tenants,
          'selectedTenant': tenants[0],
          'showPicker': false,
        };
      } else {
        // User needs to pick tenant
        return {
          'success': true,
          'user': authResponse.user,
          'tenants': tenants,
          'selectedTenant': null,
          'showPicker': true,
        };
      }
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Logout user
  Future<void> logout() async {
    await _tenantService.clearTenant();
    await _supabaseClient.auth.signOut();
  }

  /// Get current user
  User? get currentUser => _supabaseClient.auth.currentUser;

  // ===== CONTACTS - MULTI-TENANT =====

  /// Get all contacts for current user in current tenant
  /// IMPORTANT: Filtered by tenant_id + user_id
  Future<List<Contact>> getContacts() async {
    final tenantId = _tenantService.getTenantId();
    final userId = _supabaseClient.auth.currentUser!.id;
    
    if (tenantId == null) throw Exception('No tenant selected');
    
    final response = await _supabaseClient
        .from('sms_gateway.contacts')
        .select()
        .eq('tenant_id', tenantId)
        .eq('user_id', userId)
        .order('name', ascending: true);

    return (response as List)
        .map((json) => Contact.fromJson(json))
        .toList();
  }

  /// Add new contact to current tenant
  Future<Contact> addContact(Contact contact) async {
    final tenantId = _tenantService.getTenantId();
    final userId = _supabaseClient.auth.currentUser!.id;
    
    if (tenantId == null) throw Exception('No tenant selected');
    
    final contactData = contact.toJson()
      ..['tenant_id'] = tenantId
      ..['user_id'] = userId;
    
    final response = await _supabaseClient
        .from('sms_gateway.contacts')
        .insert(contactData)
        .select()
        .single();

    return Contact.fromJson(response);
  }

  /// Update contact
  Future<void> updateContact(Contact contact) async {
    final tenantId = _tenantService.getTenantId();
    
    if (tenantId == null) throw Exception('No tenant selected');
    
    await _supabaseClient
        .from('sms_gateway.contacts')
        .update(contact.toJson())
        .eq('id', contact.id)
        .eq('tenant_id', tenantId);
  }

  /// Delete contact
  Future<void> deleteContact(String contactId) async {
    final tenantId = _tenantService.getTenantId();
    
    if (tenantId == null) throw Exception('No tenant selected');
    
    await _supabaseClient
        .from('sms_gateway.contacts')
        .delete()
        .eq('id', contactId)
        .eq('tenant_id', tenantId);
  }

  // ===== GROUPS - MULTI-TENANT =====

  /// Get all groups for current user in current tenant
  Future<List<Group>> getGroups() async {
    final tenantId = _tenantService.getTenantId();
    final userId = _supabaseClient.auth.currentUser!.id;
    
    if (tenantId == null) throw Exception('No tenant selected');
    
    final response = await _supabaseClient
        .from('sms_gateway.groups')
        .select()
        .eq('tenant_id', tenantId)
        .eq('user_id', userId)
        .order('name', ascending: true);

    return (response as List)
        .map((json) => Group.fromJson(json))
        .toList();
  }

  /// Create new group in current tenant
  Future<Group> createGroup(Group group) async {
    final tenantId = _tenantService.getTenantId();
    final userId = _supabaseClient.auth.currentUser!.id;
    
    if (tenantId == null) throw Exception('No tenant selected');
    
    final groupData = group.toJson()
      ..['tenant_id'] = tenantId
      ..['user_id'] = userId;
    
    final response = await _supabaseClient
        .from('sms_gateway.groups')
        .insert(groupData)
        .select()
        .single();

    return Group.fromJson(response);
  }

  /// Delete group
  Future<void> deleteGroup(String groupId) async {
    final tenantId = _tenantService.getTenantId();
    
    if (tenantId == null) throw Exception('No tenant selected');
    
    await _supabaseClient
        .from('sms_gateway.groups')
        .delete()
        .eq('id', groupId)
        .eq('tenant_id', tenantId);
  }

  /// Add member to group
  Future<void> addGroupMember(String groupId, String contactId) async {
    final tenantId = _tenantService.getTenantId();
    
    if (tenantId == null) throw Exception('No tenant selected');
    
    // Verify contact belongs to this tenant
    final contact = await _supabaseClient
        .from('sms_gateway.contacts')
        .select()
        .eq('id', contactId)
        .eq('tenant_id', tenantId)
        .single();
    
    if (contact == null) {
      throw Exception('Contact not found in current tenant');
    }
    
    await _supabaseClient
        .from('sms_gateway.group_members')
        .insert({'group_id': groupId, 'contact_id': contactId});
  }

  /// Remove member from group
  Future<void> removeGroupMember(String groupId, String contactId) async {
    await _supabaseClient
        .from('sms_gateway.group_members')
        .delete()
        .eq('group_id', groupId)
        .eq('contact_id', contactId);
  }

  // ===== SMS LOGS - MULTI-TENANT =====

  /// Get SMS logs for current tenant
  /// Filtered by tenant_id + user_id
  Future<List<SmsLog>> getSmsLogs({int limit = 100}) async {
    final tenantId = _tenantService.getTenantId();
    final userId = _supabaseClient.auth.currentUser!.id;
    
    if (tenantId == null) throw Exception('No tenant selected');
    
    final response = await _supabaseClient
        .from('sms_gateway.sms_logs')
        .select()
        .eq('tenant_id', tenantId)
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List)
        .map((json) => SmsLog.fromJson(json))
        .toList();
  }

  /// Get SMS logs by status
  Future<List<SmsLog>> getSmsLogsByStatus(String status) async {
    final tenantId = _tenantService.getTenantId();
    final userId = _supabaseClient.auth.currentUser!.id;
    
    if (tenantId == null) throw Exception('No tenant selected');
    
    final response = await _supabaseClient
        .from('sms_gateway.sms_logs')
        .select()
        .eq('tenant_id', tenantId)
        .eq('user_id', userId)
        .eq('status', status)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => SmsLog.fromJson(json))
        .toList();
  }

  /// Log SMS (when sending)
  Future<SmsLog> logSms(SmsLog log) async {
    final tenantId = _tenantService.getTenantId();
    final userId = _supabaseClient.auth.currentUser!.id;
    
    if (tenantId == null) throw Exception('No tenant selected');
    
    final logData = log.toJson()
      ..['tenant_id'] = tenantId
      ..['user_id'] = userId;
    
    final response = await _supabaseClient
        .from('sms_gateway.sms_logs')
        .insert(logData)
        .select()
        .single();

    return SmsLog.fromJson(response);
  }

  /// Update SMS status
  Future<void> updateSmsStatus(String logId, String status, {String? errorMessage}) async {
    final tenantId = _tenantService.getTenantId();
    
    if (tenantId == null) throw Exception('No tenant selected');
    
    await _supabaseClient
        .from('sms_gateway.sms_logs')
        .update({
          'status': status,
          'error_message': errorMessage,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', logId)
        .eq('tenant_id', tenantId);
  }

  // ===== MULTI-TENANT UTILITIES =====

  /// Check if user has valid tenant selected
  bool hasValidTenant() {
    return _tenantService.getTenantId() != null;
  }

  /// Get current tenant info
  String? getCurrentTenantId() {
    return _tenantService.getTenantId();
  }

  String? getCurrentTenantName() {
    return _tenantService.getTenantName();
  }

  /// Switch to different tenant
  Future<bool> switchTenant(String tenantId) async {
    final tenant = _tenantService.getTenantById(tenantId);
    if (tenant == null) return false;
    
    await _tenantService.selectTenant(tenant);
    return true;
  }
  */
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
