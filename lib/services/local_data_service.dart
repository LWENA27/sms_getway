/// Local Data Service - Abstraction layer for offline-first data operations
/// All screens use this service instead of directly calling Supabase
library;

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/app_database.dart';
import '../core/tenant_service.dart';
import '../contacts/contact_model.dart';
import '../groups/group_model.dart';
import '../sms/sms_log_model.dart';
import 'sync_service.dart';

/// Service that handles all local data operations
/// Provides an offline-first interface for the app
class LocalDataService {
  // Singleton pattern
  static final LocalDataService _instance = LocalDataService._internal();
  factory LocalDataService() => _instance;
  LocalDataService._internal();

  AppDatabase? _db;
  AppDatabase? get db {
    try {
      _db ??= AppDatabase.instance;
      return _db;
    } catch (e) {
      // On web, local database is not supported
      debugPrint('⚠️ Local database not available (web platform): $e');
      return null;
    }
  }

  final SyncService _sync = SyncService();
  final SupabaseClient _supabase = Supabase.instance.client;
  final _uuid = const Uuid();

  // Check if running on web
  bool get isWeb => kIsWeb;

  // ============================================================================
  // INITIALIZATION
  // ============================================================================

  /// Initialize the service
  Future<void> initialize() async {
    if (!isWeb) {
      await _sync.initialize();
    }
    debugPrint('✅ LocalDataService initialized');
  }

  /// Pull initial data when switching tenants
  Future<void> loadTenantData(String tenantId) async {
    if (!isWeb) {
      await _sync.pullInitialData(tenantId);
    }
  }

  // ============================================================================
  // CONTACT OPERATIONS
  // ============================================================================

  /// Get all contacts for current tenant
  Future<List<Contact>> getContacts() async {
    final tenantId = TenantService().tenantId;
    debugPrint('🔍 getContacts called with tenantId: $tenantId');
    if (tenantId == null) return [];

    // On web, fetch directly from Supabase
    if (kIsWeb || db == null) {
      try {
        debugPrint('🌐 Fetching contacts from Supabase for tenant: $tenantId');
        final response = await _supabase
            .schema('sms_gateway')
            .from('contacts')
            .select()
            .eq('tenant_id', tenantId)
            .eq('user_id', Supabase.instance.client.auth.currentUser!.id)
            .order('name');

        final remoteContacts = response as List;
        debugPrint('✅ Fetched ${remoteContacts.length} contacts from Supabase');
        return remoteContacts
            .map((json) => Contact(
                  id: json['id'],
                  userId: json['user_id'],
                  tenantId: json['tenant_id'],
                  name: json['name'],
                  phoneNumber: json['phone_number'],
                  createdAt: DateTime.parse(json['created_at']),
                ))
            .toList();
      } catch (e) {
        debugPrint('❌ Error fetching contacts from Supabase: $e');
        return [];
      }
    }

    final localContacts = await db!.getContacts(tenantId);
    return localContacts.map(_localContactToModel).toList();
  }

  /// Add a new contact
  Future<Contact> addContact({
    required String name,
    required String phoneNumber,
  }) async {
    final tenantId = TenantService().tenantId;
    final userId = Supabase.instance.client.auth.currentUser?.id;

    if (tenantId == null || userId == null) {
      throw Exception('No tenant selected');
    }

    final id = _uuid.v4();
    final now = DateTime.now();

    // On web, insert directly to Supabase
    if (kIsWeb || db == null) {
      try {
        await _supabase.schema('sms_gateway').from('contacts').insert({
          'id': id,
          'tenant_id': tenantId,
          'user_id': userId,
          'name': name,
          'phone_number': phoneNumber,
          'created_at': now.toIso8601String(),
        });
      } catch (e) {
        debugPrint('❌ Error adding contact to Supabase: $e');
        rethrow;
      }
    } else {
      await db!.upsertContact(LocalContactsCompanion(
        id: Value(id),
        tenantId: Value(tenantId),
        userId: Value(userId),
        name: Value(name),
        phoneNumber: Value(phoneNumber),
        createdAt: Value(now),
        syncStatus: const Value('pending_create'),
      ));

      // Trigger sync if online
      _triggerSyncIfOnline();
    }

    return Contact(
      id: id,
      userId: userId,
      tenantId: tenantId,
      name: name,
      phoneNumber: phoneNumber,
      createdAt: now,
    );
  }

  /// Update a contact
  Future<void> updateContact({
    required String id,
    required String name,
    required String phoneNumber,
  }) async {
    // On web, update directly in Supabase
    if (kIsWeb || db == null) {
      try {
        await _supabase.schema('sms_gateway').from('contacts').update({
          'name': name,
          'phone_number': phoneNumber,
        }).eq('id', id);
      } catch (e) {
        debugPrint('❌ Error updating contact in Supabase: $e');
        rethrow;
      }
      return;
    }

    final existing = await db!.getContact(id);
    if (existing == null) return;

    // If it was already pending_create, keep that status
    final syncStatus = existing.syncStatus == 'pending_create'
        ? 'pending_create'
        : 'pending_update';

    await db!.upsertContact(LocalContactsCompanion(
      id: Value(id),
      tenantId: Value(existing.tenantId),
      userId: Value(existing.userId),
      name: Value(name),
      phoneNumber: Value(phoneNumber),
      createdAt: Value(existing.createdAt),
      updatedAt: Value(DateTime.now()),
      syncStatus: Value(syncStatus),
    ));

    _triggerSyncIfOnline();
  }

  /// Delete a contact
  Future<void> deleteContact(String id) async {
    // On web, delete directly from Supabase
    if (kIsWeb || db == null) {
      try {
        await _supabase
            .schema('sms_gateway')
            .from('contacts')
            .delete()
            .eq('id', id);
      } catch (e) {
        debugPrint('❌ Error deleting contact from Supabase: $e');
        rethrow;
      }
      return;
    }

    final existing = await db!.getContact(id);
    if (existing == null) return;

    // If never synced, just delete locally
    if (existing.syncStatus == 'pending_create') {
      await db!.deleteContact(id);
    } else {
      // Mark for remote deletion
      await db!.markContactForDeletion(id);
      _triggerSyncIfOnline();
    }
  }

  /// Bulk import contacts
  Future<Map<String, int>> importContacts(
      List<Map<String, String>> contacts) async {
    final tenantId = TenantService().tenantId;
    final userId = TenantService().currentTenant?.clientId;

    if (tenantId == null || userId == null) {
      throw Exception('No tenant selected');
    }

    int imported = 0;
    int skipped = 0;
    int errors = 0;

    for (final contact in contacts) {
      final name = contact['name']?.trim() ?? '';
      final phone = contact['phone']?.trim() ?? '';

      if (name.isEmpty || phone.isEmpty) {
        errors++;
        continue;
      }

      try {
        await db!.upsertContact(LocalContactsCompanion(
          id: Value(_uuid.v4()),
          tenantId: Value(tenantId),
          userId: Value(userId),
          name: Value(name),
          phoneNumber: Value(phone),
          createdAt: Value(DateTime.now()),
          syncStatus: const Value('pending_create'),
        ));
        imported++;
      } catch (e) {
        if (e.toString().contains('UNIQUE')) {
          skipped++;
        } else {
          errors++;
        }
      }
    }

    _triggerSyncIfOnline();

    return {'imported': imported, 'skipped': skipped, 'errors': errors};
  }

  // ============================================================================
  // GROUP OPERATIONS
  // ============================================================================

  /// Get all groups for current tenant
  Future<List<Group>> getGroups() async {
    final tenantId = TenantService().tenantId;
    debugPrint('🔍 getGroups called with tenantId: $tenantId');
    if (tenantId == null) return [];

    // On web, fetch from Supabase
    if (kIsWeb || db == null) {
      try {
        debugPrint('🌐 Fetching groups from Supabase for tenant: $tenantId');
        final response = await _supabase
            .schema('sms_gateway')
            .from('groups')
            .select('*, group_members(count)')
            .eq('tenant_id', tenantId)
            .order('name');

        final remoteGroups = response as List;
        debugPrint('✅ Fetched ${remoteGroups.length} groups from Supabase');
        return remoteGroups
            .map((json) => Group(
                  id: json['id'],
                  userId: json['user_id'],
                  tenantId: json['tenant_id'],
                  name: json['name'],
                  createdAt: DateTime.parse(json['created_at']),
                  memberCount: json['group_members']?[0]?['count'] ?? 0,
                ))
            .toList();
      } catch (e) {
        debugPrint('❌ Error fetching groups from Supabase: $e');
        return [];
      }
    }

    final localGroups = await db!.getGroups(tenantId);
    final groups = <Group>[];

    for (final lg in localGroups) {
      final memberCount = await db!.getGroupMemberCount(lg.id);
      groups.add(Group(
        id: lg.id,
        userId: lg.userId,
        tenantId: lg.tenantId,
        name: lg.name,
        createdAt: lg.createdAt,
        memberCount: memberCount,
      ));
    }

    return groups;
  }

  /// Create a new group with members
  Future<Group> createGroup({
    required String name,
    required List<String> contactIds,
  }) async {
    final tenantId = TenantService().tenantId;
    final userId = TenantService().currentTenant?.clientId;

    if (tenantId == null || userId == null) {
      throw Exception('No tenant selected');
    }

    final groupId = _uuid.v4();
    final now = DateTime.now();

    // On web, insert directly to Supabase
    if (kIsWeb || db == null) {
      try {
        // Create group
        await _supabase.schema('sms_gateway').from('groups').insert({
          'id': groupId,
          'tenant_id': tenantId,
          'user_id': userId,
          'name': name,
          'created_at': now.toIso8601String(),
        });

        // Add members
        if (contactIds.isNotEmpty) {
          final members = contactIds
              .map((contactId) => {
                    'id': _uuid.v4(),
                    'group_id': groupId,
                    'contact_id': contactId,
                    'tenant_id': tenantId,
                    'added_at': now.toIso8601String(),
                  })
              .toList();

          await _supabase
              .schema('sms_gateway')
              .from('group_members')
              .insert(members);
        }
      } catch (e) {
        debugPrint('❌ Error creating group in Supabase: $e');
        rethrow;
      }
    } else {
      // Create group
      await db!.upsertGroup(LocalGroupsCompanion(
        id: Value(groupId),
        tenantId: Value(tenantId),
        userId: Value(userId),
        name: Value(name),
        createdAt: Value(now),
        syncStatus: const Value('pending_create'),
      ));

      // Add members
      for (final contactId in contactIds) {
        await db!.insertGroupMember(LocalGroupMembersCompanion(
          id: Value(_uuid.v4()),
          groupId: Value(groupId),
          contactId: Value(contactId),
          tenantId: Value(tenantId),
          addedAt: Value(now),
          syncStatus: const Value('pending_create'),
        ));
      }

      _triggerSyncIfOnline();
    }

    return Group(
      id: groupId,
      userId: userId,
      tenantId: tenantId,
      name: name,
      createdAt: now,
      memberCount: contactIds.length,
    );
  }

  /// Get contacts for a group
  Future<List<Contact>> getGroupContacts(String groupId) async {
    // On web, fetch from Supabase
    if (kIsWeb || db == null) {
      try {
        final response = await _supabase
            .schema('sms_gateway')
            .from('group_members')
            .select('contact_id, contacts(*)')
            .eq('group_id', groupId);

        final members = response as List;
        return members.where((m) => m['contacts'] != null).map((m) {
          final c = m['contacts'];
          return Contact(
            id: c['id'],
            userId: c['user_id'],
            tenantId: c['tenant_id'],
            name: c['name'],
            phoneNumber: c['phone_number'],
            createdAt: DateTime.parse(c['created_at']),
          );
        }).toList();
      } catch (e) {
        debugPrint('❌ Error fetching group contacts from Supabase: $e');
        return [];
      }
    }

    final members = await db!.getGroupMembers(groupId);
    final contacts = <Contact>[];

    for (final member in members) {
      final contact = await db!.getContact(member.contactId);
      if (contact != null) {
        contacts.add(_localContactToModel(contact));
      }
    }

    return contacts;
  }

  /// Delete a group
  Future<void> deleteGroup(String groupId) async {
    // On web, delete from Supabase
    if (kIsWeb || db == null) {
      try {
        // Delete group members first
        await _supabase
            .schema('sms_gateway')
            .from('group_members')
            .delete()
            .eq('group_id', groupId);

        // Then delete group
        await _supabase
            .schema('sms_gateway')
            .from('groups')
            .delete()
            .eq('id', groupId);
      } catch (e) {
        debugPrint('❌ Error deleting group from Supabase: $e');
        rethrow;
      }
      return;
    }

    // Mark group members for deletion
    final members = await db!.getGroupMembers(groupId);
    for (final member in members) {
      await db!.markGroupMemberForDeletion(member.id);
    }

    // Mark group for deletion
    await db!.markGroupForDeletion(groupId);

    _triggerSyncIfOnline();
  }

  // ============================================================================
  // SMS LOG OPERATIONS
  // ============================================================================

  /// Get SMS logs for current tenant
  Future<List<SmsLog>> getSmsLogs({String? statusFilter}) async {
    final tenantId = TenantService().tenantId;
    if (tenantId == null) return [];

    // On web, fetch from Supabase
    if (kIsWeb || db == null) {
      try {
        debugPrint('🔍 Fetching SMS logs from Supabase for tenant: $tenantId');

        var query = _supabase
            .schema('sms_gateway')
            .from('sms_logs')
            .select()
            .eq('tenant_id', tenantId);

        if (statusFilter != null) {
          query = query.eq('status', statusFilter);
          debugPrint('🔍 Filtering by status: $statusFilter');
        }

        final response =
            await query.order('created_at', ascending: false).limit(500);
        final remoteLogs = response as List;

        debugPrint('✅ Fetched ${remoteLogs.length} SMS logs from Supabase');

        return remoteLogs
            .map((json) => SmsLog(
                  id: json['id'],
                  userId: json['user_id'],
                  tenantId: json['tenant_id'],
                  contactId: json['contact_id'],
                  phoneNumber: json['phone_number'] ?? json['recipient'],
                  message: json['message'],
                  status: json['status'],
                  sentAt: json['sent_at'] != null
                      ? DateTime.parse(json['sent_at'])
                      : null,
                  errorMessage: json['error_message'],
                  createdAt: DateTime.parse(json['created_at']),
                ))
            .toList();
      } catch (e) {
        debugPrint('❌ Error fetching SMS logs from Supabase: $e');
        return [];
      }
    }

    final localLogs =
        await db!.getSmsLogs(tenantId, statusFilter: statusFilter);
    return localLogs.map(_localSmsLogToModel).toList();
  }

  /// Log an SMS (called when sending)
  Future<SmsLog> logSms({
    required String phoneNumber,
    required String message,
    required String status,
    String? contactId,
    String? errorMessage,
    String? channel,
  }) async {
    final tenantId = TenantService().tenantId;
    final userId = TenantService().currentTenant?.clientId;

    if (tenantId == null || userId == null) {
      throw Exception('No tenant selected');
    }

    final id = _uuid.v4();
    final now = DateTime.now();

    // On web, insert directly to Supabase (SMS won't actually be sent on web)
    if (kIsWeb || db == null) {
      try {
        await _supabase.schema('sms_gateway').from('sms_logs').insert({
          'id': id,
          'tenant_id': tenantId,
          'user_id': userId,
          'contact_id': contactId,
          'phone_number': phoneNumber,
          'message': message,
          'status': status,
          'sent_at': status == 'sent' ? now.toIso8601String() : null,
          'error_message': errorMessage,
          'created_at': now.toIso8601String(),
        });
      } catch (e) {
        debugPrint('❌ Error logging SMS to Supabase: $e');
        // Don't rethrow - allow SMS log to be created in memory
      }
    } else {
      await db!.insertSmsLog(LocalSmsLogsCompanion(
        id: Value(id),
        tenantId: Value(tenantId),
        userId: Value(userId),
        contactId: Value(contactId),
        phoneNumber: Value(phoneNumber),
        message: Value(message),
        status: Value(status),
        sentAt: Value(status == 'sent' ? now : null),
        errorMessage: Value(errorMessage),
        channel: Value(channel),
        createdAt: Value(now),
        syncStatus: const Value('pending_create'),
      ));

      // Don't block for sync - SMS sending should be fast
      Future.delayed(const Duration(seconds: 2), () {
        _triggerSyncIfOnline();
      });
    }

    return SmsLog(
      id: id,
      userId: userId,
      tenantId: tenantId,
      contactId: contactId,
      phoneNumber: phoneNumber,
      message: message,
      status: status,
      sentAt: status == 'sent' ? now : null,
      errorMessage: errorMessage,
      createdAt: now,
    );
  }

  // ============================================================================
  // DASHBOARD
  // ============================================================================

  /// Get dashboard counts
  Future<Map<String, int>> getDashboardCounts() async {
    final tenantId = TenantService().tenantId;
    debugPrint('🔍 getDashboardCounts called with tenantId: $tenantId');
    if (tenantId == null) {
      return {'contacts': 0, 'groups': 0, 'smsLogs': 0};
    }

    // On web, fetch counts from Supabase
    if (kIsWeb || db == null) {
      try {
        debugPrint(
            '🌐 Fetching dashboard counts from Supabase for tenant: $tenantId');

        final contactsResponse = await _supabase
            .schema('sms_gateway')
            .from('contacts')
            .select('id')
            .eq('tenant_id', tenantId)
            .count(CountOption.exact);
        debugPrint('📊 Contacts count: ${contactsResponse.count}');

        final groupsResponse = await _supabase
            .schema('sms_gateway')
            .from('groups')
            .select('id')
            .eq('tenant_id', tenantId)
            .count(CountOption.exact);
        debugPrint('📊 Groups count: ${groupsResponse.count}');

        final logsResponse = await _supabase
            .schema('sms_gateway')
            .from('sms_logs')
            .select('id')
            .eq('tenant_id', tenantId)
            .count(CountOption.exact);
        debugPrint('📊 SMS Logs count: ${logsResponse.count}');

        return {
          'contacts': contactsResponse.count,
          'groups': groupsResponse.count,
          'smsLogs': logsResponse.count,
          'sms_sent': logsResponse.count,
          'sms_pending': 0, // No pending on web
        };
      } catch (e) {
        debugPrint('❌ Error fetching dashboard counts from Supabase: $e');
        return {
          'contacts': 0,
          'groups': 0,
          'smsLogs': 0,
          'sms_sent': 0,
          'sms_pending': 0
        };
      }
    }

    return db!.getDashboardCounts(tenantId);
  }

  /// Get pending sync count
  Future<int> getPendingSyncCount() async {
    final tenantId = TenantService().tenantId;
    if (tenantId == null) return 0;

    if (db == null) return 0;
    return db!.getPendingSyncCount(tenantId);
  }

  // ============================================================================
  // SYNC
  // ============================================================================

  /// Force sync now
  Future<SyncResult> syncNow() async {
    return _sync.syncAll();
  }

  /// Get sync service for UI updates
  SyncService get syncService => _sync;

  /// Check if online
  bool get isOnline => _sync.isOnline;

  // ============================================================================
  // HELPERS
  // ============================================================================

  /// Trigger sync if online (non-blocking)
  void _triggerSyncIfOnline() {
    if (_sync.isOnline) {
      Future.delayed(const Duration(milliseconds: 500), () {
        _sync.syncAll();
      });
    }
  }

  /// Convert LocalContact to Contact model
  Contact _localContactToModel(LocalContact lc) {
    return Contact(
      id: lc.id,
      userId: lc.userId,
      tenantId: lc.tenantId,
      name: lc.name,
      phoneNumber: lc.phoneNumber,
      createdAt: lc.createdAt,
    );
  }

  /// Convert LocalSmsLog to SmsLog model
  SmsLog _localSmsLogToModel(LocalSmsLog ll) {
    return SmsLog(
      id: ll.id,
      userId: ll.userId,
      tenantId: ll.tenantId,
      contactId: ll.contactId,
      phoneNumber: ll.phoneNumber,
      message: ll.message,
      status: ll.status,
      sentAt: ll.sentAt,
      errorMessage: ll.errorMessage,
      createdAt: ll.createdAt,
    );
  }

  /// Clear all local data (on logout)
  Future<void> clearAllData() async {
    if (db == null) return;
    await db!.clearAllData();
  }

  /// Clear tenant data (on workspace switch)
  Future<void> clearTenantData(String tenantId) async {
    if (db == null) return;
    await db!.clearTenantData(tenantId);
  }
}
