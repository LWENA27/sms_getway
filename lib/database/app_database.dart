/// Drift Local Database for Offline-First SMS Gateway
/// This database provides local storage with sync capabilities
library;

import 'package:drift/drift.dart';
import 'connection/connection.dart' as connection;

part 'app_database.g.dart';

/// Sync status for offline-first operations
enum SyncStatus {
  synced, // Data matches Supabase
  pendingCreate, // Created locally, needs to be pushed
  pendingUpdate, // Updated locally, needs to be pushed
  pendingDelete, // Deleted locally, needs to be pushed to delete remotely
}

/// Extension to convert SyncStatus to/from string for database storage
extension SyncStatusExtension on SyncStatus {
  String get value {
    switch (this) {
      case SyncStatus.synced:
        return 'synced';
      case SyncStatus.pendingCreate:
        return 'pending_create';
      case SyncStatus.pendingUpdate:
        return 'pending_update';
      case SyncStatus.pendingDelete:
        return 'pending_delete';
    }
  }

  static SyncStatus fromString(String value) {
    switch (value) {
      case 'synced':
        return SyncStatus.synced;
      case 'pending_create':
        return SyncStatus.pendingCreate;
      case 'pending_update':
        return SyncStatus.pendingUpdate;
      case 'pending_delete':
        return SyncStatus.pendingDelete;
      default:
        return SyncStatus.synced;
    }
  }
}

// ============================================================================
// TABLE DEFINITIONS
// ============================================================================

/// Local contacts table
class LocalContacts extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text().named('tenant_id')();
  TextColumn get userId => text().named('user_id')();
  TextColumn get name => text()();
  TextColumn get phoneNumber => text().named('phone_number')();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at').nullable()();
  TextColumn get syncStatus =>
      text().named('sync_status').withDefault(const Constant('synced'))();
  DateTimeColumn get lastSyncedAt =>
      dateTime().named('last_synced_at').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Local groups table
class LocalGroups extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text().named('tenant_id')();
  TextColumn get userId => text().named('user_id')();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  DateTimeColumn get updatedAt => dateTime().named('updated_at').nullable()();
  TextColumn get syncStatus =>
      text().named('sync_status').withDefault(const Constant('synced'))();
  DateTimeColumn get lastSyncedAt =>
      dateTime().named('last_synced_at').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Local group members table (joining table)
class LocalGroupMembers extends Table {
  TextColumn get id => text()();
  TextColumn get groupId => text().named('group_id')();
  TextColumn get contactId => text().named('contact_id')();
  TextColumn get tenantId => text().named('tenant_id')();
  DateTimeColumn get addedAt => dateTime().named('added_at')();
  TextColumn get syncStatus =>
      text().named('sync_status').withDefault(const Constant('synced'))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Local SMS logs table
class LocalSmsLogs extends Table {
  TextColumn get id => text()();
  TextColumn get tenantId => text().named('tenant_id')();
  TextColumn get userId => text().named('user_id')();
  TextColumn get contactId => text().named('contact_id').nullable()();
  TextColumn get phoneNumber => text().named('phone_number')();
  TextColumn get message => text()();
  TextColumn get status => text()(); // sent, failed, pending, delivered
  DateTimeColumn get sentAt => dateTime().named('sent_at').nullable()();
  TextColumn get errorMessage => text().named('error_message').nullable()();
  TextColumn get channel => text().nullable()(); // thisPhone, quickSMS, etc.
  DateTimeColumn get createdAt => dateTime().named('created_at')();
  TextColumn get syncStatus =>
      text().named('sync_status').withDefault(const Constant('synced'))();
  DateTimeColumn get lastSyncedAt =>
      dateTime().named('last_synced_at').nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Sync metadata table - tracks last sync times per table
class SyncMetadata extends Table {
  TextColumn get syncTableName => text().named('table_name')();
  TextColumn get tenantId => text().named('tenant_id')();
  DateTimeColumn get lastPulledAt =>
      dateTime().named('last_pulled_at').nullable()();
  DateTimeColumn get lastPushedAt =>
      dateTime().named('last_pushed_at').nullable()();
  IntColumn get pendingCount =>
      integer().named('pending_count').withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {syncTableName, tenantId};
}

// ============================================================================
// DATABASE CLASS
// ============================================================================

@DriftDatabase(tables: [
  LocalContacts,
  LocalGroups,
  LocalGroupMembers,
  LocalSmsLogs,
  SyncMetadata,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(connection.connect());

  @override
  int get schemaVersion => 1;

  // Singleton pattern
  static AppDatabase? _instance;
  static AppDatabase get instance {
    _instance ??= AppDatabase();
    return _instance!;
  }

  // ============================================================================
  // CONTACT OPERATIONS
  // ============================================================================

  /// Get all contacts for a tenant (excluding pending deletes)
  Future<List<LocalContact>> getContacts(String tenantId) {
    return (select(localContacts)
          ..where((c) => c.tenantId.equals(tenantId))
          ..where((c) => c.syncStatus.equals('pending_delete').not())
          ..orderBy([(c) => OrderingTerm.asc(c.name)]))
        .get();
  }

  /// Get a single contact by ID
  Future<LocalContact?> getContact(String id) {
    return (select(localContacts)..where((c) => c.id.equals(id)))
        .getSingleOrNull();
  }

  /// Insert or update a contact
  Future<void> upsertContact(LocalContactsCompanion contact) {
    return into(localContacts).insertOnConflictUpdate(contact);
  }

  /// Mark contact for deletion (soft delete)
  Future<void> markContactForDeletion(String id) {
    return (update(localContacts)..where((c) => c.id.equals(id))).write(
      LocalContactsCompanion(
        syncStatus: const Value('pending_delete'),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Permanently delete contact
  Future<void> deleteContact(String id) {
    return (delete(localContacts)..where((c) => c.id.equals(id))).go();
  }

  /// Get pending contacts for sync
  Future<List<LocalContact>> getPendingContacts(String tenantId) {
    return (select(localContacts)
          ..where((c) => c.tenantId.equals(tenantId))
          ..where((c) => c.syncStatus.equals('synced').not()))
        .get();
  }

  /// Mark contacts as synced
  Future<void> markContactsSynced(List<String> ids) async {
    for (final id in ids) {
      await (update(localContacts)..where((c) => c.id.equals(id))).write(
        LocalContactsCompanion(
          syncStatus: const Value('synced'),
          lastSyncedAt: Value(DateTime.now()),
        ),
      );
    }
  }

  // ============================================================================
  // GROUP OPERATIONS
  // ============================================================================

  /// Get all groups for a tenant with member counts
  Future<List<LocalGroup>> getGroups(String tenantId) {
    return (select(localGroups)
          ..where((g) => g.tenantId.equals(tenantId))
          ..where((g) => g.syncStatus.equals('pending_delete').not())
          ..orderBy([(g) => OrderingTerm.asc(g.name)]))
        .get();
  }

  /// Get group member count
  Future<int> getGroupMemberCount(String groupId) async {
    final count = await (select(localGroupMembers)
          ..where((m) => m.groupId.equals(groupId))
          ..where((m) => m.syncStatus.equals('pending_delete').not()))
        .get();
    return count.length;
  }

  /// Insert or update a group
  Future<void> upsertGroup(LocalGroupsCompanion group) {
    return into(localGroups).insertOnConflictUpdate(group);
  }

  /// Get pending groups for sync
  Future<List<LocalGroup>> getPendingGroups(String tenantId) {
    return (select(localGroups)
          ..where((g) => g.tenantId.equals(tenantId))
          ..where((g) => g.syncStatus.equals('synced').not()))
        .get();
  }

  // ============================================================================
  // GROUP MEMBER OPERATIONS
  // ============================================================================

  /// Get members for a group
  Future<List<LocalGroupMember>> getGroupMembers(String groupId) {
    return (select(localGroupMembers)
          ..where((m) => m.groupId.equals(groupId))
          ..where((m) => m.syncStatus.equals('pending_delete').not()))
        .get();
  }

  /// Insert group member
  Future<void> insertGroupMember(LocalGroupMembersCompanion member) {
    return into(localGroupMembers).insertOnConflictUpdate(member);
  }

  /// Get pending group members for sync
  Future<List<LocalGroupMember>> getPendingGroupMembers(String tenantId) {
    return (select(localGroupMembers)
          ..where((m) => m.tenantId.equals(tenantId))
          ..where((m) => m.syncStatus.equals('synced').not()))
        .get();
  }

  /// Mark group for deletion (soft delete)
  Future<void> markGroupForDeletion(String id) {
    return (update(localGroups)..where((g) => g.id.equals(id))).write(
      LocalGroupsCompanion(
        syncStatus: const Value('pending_delete'),
        lastSyncedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Mark group member for deletion (soft delete)
  Future<void> markGroupMemberForDeletion(String id) {
    return (update(localGroupMembers)..where((m) => m.id.equals(id))).write(
      const LocalGroupMembersCompanion(
        syncStatus: Value('pending_delete'),
      ),
    );
  }

  /// Permanently delete group
  Future<void> deleteGroup(String id) {
    return (delete(localGroups)..where((g) => g.id.equals(id))).go();
  }

  /// Permanently delete group member
  Future<void> deleteGroupMember(String id) {
    return (delete(localGroupMembers)..where((m) => m.id.equals(id))).go();
  }

  // ============================================================================
  // SMS LOG OPERATIONS
  // ============================================================================

  /// Get all SMS logs for a tenant
  Future<List<LocalSmsLog>> getSmsLogs(String tenantId,
      {String? statusFilter}) {
    var query = select(localSmsLogs)
      ..where((l) => l.tenantId.equals(tenantId))
      ..where((l) => l.syncStatus.equals('pending_delete').not())
      ..orderBy([(l) => OrderingTerm.desc(l.createdAt)]);

    if (statusFilter != null && statusFilter != 'all') {
      query = query..where((l) => l.status.equals(statusFilter));
    }

    return query.get();
  }

  /// Insert SMS log
  Future<void> insertSmsLog(LocalSmsLogsCompanion log) {
    return into(localSmsLogs).insertOnConflictUpdate(log);
  }

  /// Get pending SMS logs for sync
  Future<List<LocalSmsLog>> getPendingSmsLogs(String tenantId) {
    return (select(localSmsLogs)
          ..where((l) => l.tenantId.equals(tenantId))
          ..where((l) => l.syncStatus.equals('synced').not()))
        .get();
  }

  /// Mark SMS logs as synced
  Future<void> markSmsLogsSynced(List<String> ids) async {
    for (final id in ids) {
      await (update(localSmsLogs)..where((l) => l.id.equals(id))).write(
        LocalSmsLogsCompanion(
          syncStatus: const Value('synced'),
          lastSyncedAt: Value(DateTime.now()),
        ),
      );
    }
  }

  // ============================================================================
  // SYNC METADATA OPERATIONS
  // ============================================================================

  /// Get sync metadata for a table
  Future<SyncMetadataData?> getSyncMetadata(String tableName, String tenantId) {
    return (select(syncMetadata)
          ..where((m) => m.syncTableName.equals(tableName))
          ..where((m) => m.tenantId.equals(tenantId)))
        .getSingleOrNull();
  }

  /// Update sync metadata
  Future<void> updateSyncMetadata(SyncMetadataCompanion data) {
    return into(syncMetadata).insertOnConflictUpdate(data);
  }

  // ============================================================================
  // UTILITY OPERATIONS
  // ============================================================================

  /// Get counts for dashboard
  Future<Map<String, int>> getDashboardCounts(String tenantId) async {
    final contacts = await (select(localContacts)
          ..where((c) => c.tenantId.equals(tenantId))
          ..where((c) => c.syncStatus.equals('pending_delete').not()))
        .get();

    final groups = await (select(localGroups)
          ..where((g) => g.tenantId.equals(tenantId))
          ..where((g) => g.syncStatus.equals('pending_delete').not()))
        .get();

    final logs = await (select(localSmsLogs)
          ..where((l) => l.tenantId.equals(tenantId))
          ..where((l) => l.syncStatus.equals('pending_delete').not()))
        .get();

    return {
      'contacts': contacts.length,
      'groups': groups.length,
      'smsLogs': logs.length,
    };
  }

  /// Get total pending sync count
  Future<int> getPendingSyncCount(String tenantId) async {
    final pendingContacts = await getPendingContacts(tenantId);
    final pendingGroups = await getPendingGroups(tenantId);
    final pendingLogs = await getPendingSmsLogs(tenantId);
    return pendingContacts.length + pendingGroups.length + pendingLogs.length;
  }

  /// Clear all data for a tenant (used when switching workspaces)
  Future<void> clearTenantData(String tenantId) async {
    await (delete(localContacts)..where((c) => c.tenantId.equals(tenantId)))
        .go();
    await (delete(localGroups)..where((g) => g.tenantId.equals(tenantId))).go();
    await (delete(localGroupMembers)..where((m) => m.tenantId.equals(tenantId)))
        .go();
    await (delete(localSmsLogs)..where((l) => l.tenantId.equals(tenantId)))
        .go();
    await (delete(syncMetadata)..where((m) => m.tenantId.equals(tenantId)))
        .go();
  }

  /// Clear all local data (used on logout)
  Future<void> clearAllData() async {
    await delete(localContacts).go();
    await delete(localGroups).go();
    await delete(localGroupMembers).go();
    await delete(localSmsLogs).go();
    await delete(syncMetadata).go();
  }
}
