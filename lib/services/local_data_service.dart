/// Local Data Service - Abstraction layer for offline-first data operations
/// All screens use this service instead of directly calling Supabase
library;

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

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

  final AppDatabase _db = AppDatabase.instance;
  final SyncService _sync = SyncService();
  final _uuid = const Uuid();

  // ============================================================================
  // INITIALIZATION
  // ============================================================================

  /// Initialize the service
  Future<void> initialize() async {
    await _sync.initialize();
    debugPrint('✅ LocalDataService initialized');
  }

  /// Pull initial data when switching tenants
  Future<void> loadTenantData(String tenantId) async {
    await _sync.pullInitialData(tenantId);
  }

  // ============================================================================
  // CONTACT OPERATIONS
  // ============================================================================

  /// Get all contacts for current tenant
  Future<List<Contact>> getContacts() async {
    final tenantId = TenantService().tenantId;
    if (tenantId == null) return [];

    final localContacts = await _db.getContacts(tenantId);
    return localContacts.map(_localContactToModel).toList();
  }

  /// Add a new contact
  Future<Contact> addContact({
    required String name,
    required String phoneNumber,
  }) async {
    final tenantId = TenantService().tenantId;
    final userId = TenantService().currentTenant?.clientId;

    if (tenantId == null || userId == null) {
      throw Exception('No tenant selected');
    }

    final id = _uuid.v4();
    final now = DateTime.now();

    await _db.upsertContact(LocalContactsCompanion(
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
    final existing = await _db.getContact(id);
    if (existing == null) return;

    // If it was already pending_create, keep that status
    final syncStatus = existing.syncStatus == 'pending_create'
        ? 'pending_create'
        : 'pending_update';

    await _db.upsertContact(LocalContactsCompanion(
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
    final existing = await _db.getContact(id);
    if (existing == null) return;

    // If never synced, just delete locally
    if (existing.syncStatus == 'pending_create') {
      await _db.deleteContact(id);
    } else {
      // Mark for remote deletion
      await _db.markContactForDeletion(id);
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
        await _db.upsertContact(LocalContactsCompanion(
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
    if (tenantId == null) return [];

    final localGroups = await _db.getGroups(tenantId);
    final groups = <Group>[];

    for (final lg in localGroups) {
      final memberCount = await _db.getGroupMemberCount(lg.id);
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

    // Create group
    await _db.upsertGroup(LocalGroupsCompanion(
      id: Value(groupId),
      tenantId: Value(tenantId),
      userId: Value(userId),
      name: Value(name),
      createdAt: Value(now),
      syncStatus: const Value('pending_create'),
    ));

    // Add members
    for (final contactId in contactIds) {
      await _db.insertGroupMember(LocalGroupMembersCompanion(
        id: Value(_uuid.v4()),
        groupId: Value(groupId),
        contactId: Value(contactId),
        tenantId: Value(tenantId),
        addedAt: Value(now),
        syncStatus: const Value('pending_create'),
      ));
    }

    _triggerSyncIfOnline();

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
    final members = await _db.getGroupMembers(groupId);
    final contacts = <Contact>[];

    for (final member in members) {
      final contact = await _db.getContact(member.contactId);
      if (contact != null) {
        contacts.add(_localContactToModel(contact));
      }
    }

    return contacts;
  }

  /// Delete a group
  Future<void> deleteGroup(String groupId) async {
    // Mark group members for deletion
    final members = await _db.getGroupMembers(groupId);
    for (final member in members) {
      await _db.markGroupMemberForDeletion(member.id);
    }

    // Mark group for deletion
    await _db.markGroupForDeletion(groupId);

    _triggerSyncIfOnline();
  }

  // ============================================================================
  // SMS LOG OPERATIONS
  // ============================================================================

  /// Get SMS logs for current tenant
  Future<List<SmsLog>> getSmsLogs({String? statusFilter}) async {
    final tenantId = TenantService().tenantId;
    if (tenantId == null) return [];

    final localLogs =
        await _db.getSmsLogs(tenantId, statusFilter: statusFilter);
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

    await _db.insertSmsLog(LocalSmsLogsCompanion(
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
    if (tenantId == null) {
      return {'contacts': 0, 'groups': 0, 'smsLogs': 0};
    }

    return _db.getDashboardCounts(tenantId);
  }

  /// Get pending sync count
  Future<int> getPendingSyncCount() async {
    final tenantId = TenantService().tenantId;
    if (tenantId == null) return 0;

    return _db.getPendingSyncCount(tenantId);
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
    await _db.clearAllData();
  }

  /// Clear tenant data (on workspace switch)
  Future<void> clearTenantData(String tenantId) async {
    await _db.clearTenantData(tenantId);
  }
}
