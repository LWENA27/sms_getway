/// Sync Service - Handles offline-first data synchronization
/// Pulls data from Supabase and pushes local changes when online
library;

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/app_database.dart';
import '../core/tenant_service.dart';

/// Sync status for the entire sync operation
enum OverallSyncStatus {
  idle,
  syncing,
  success,
  error,
  offline,
}

/// Result of a sync operation
class SyncResult {
  final bool success;
  final int pushedCount;
  final int pulledCount;
  final String? error;
  final DateTime timestamp;

  SyncResult({
    required this.success,
    this.pushedCount = 0,
    this.pulledCount = 0,
    this.error,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() =>
      'SyncResult(success: $success, pushed: $pushedCount, pulled: $pulledCount)';
}

/// Service to handle data synchronization between local DB and Supabase
class SyncService extends ChangeNotifier {
  // Singleton pattern
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  // Dependencies
  final AppDatabase _db = AppDatabase.instance;
  final SupabaseClient _supabase = Supabase.instance.client;
  final Connectivity _connectivity = Connectivity();

  // State
  OverallSyncStatus _status = OverallSyncStatus.idle;
  bool _isOnline = true;
  int _pendingCount = 0;
  SyncResult? _lastSyncResult;
  DateTime? _lastSyncTime;
  StreamSubscription? _connectivitySubscription;
  Timer? _autoSyncTimer;

  // Getters
  OverallSyncStatus get status => _status;
  bool get isOnline => _isOnline;
  int get pendingCount => _pendingCount;
  SyncResult? get lastSyncResult => _lastSyncResult;
  bool get hasPendingChanges => _pendingCount > 0;
  bool get isSyncing => _status == OverallSyncStatus.syncing;
  DateTime? get lastSyncTime => _lastSyncTime;

  /// Initialize the sync service
  Future<void> initialize() async {
    // Check initial connectivity
    final results = await _connectivity.checkConnectivity();
    _isOnline = !results.contains(ConnectivityResult.none);
    debugPrint('📡 Initial connectivity: ${_isOnline ? "Online" : "Offline"}');

    // Listen for connectivity changes
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen(_onConnectivityChanged);

    // Update pending count
    await _updatePendingCount();

    // Start auto-sync timer (every 5 minutes when online)
    _startAutoSyncTimer();

    notifyListeners();
  }

  /// Handle connectivity changes
  void _onConnectivityChanged(List<ConnectivityResult> results) {
    final wasOnline = _isOnline;
    _isOnline = !results.contains(ConnectivityResult.none);

    debugPrint('📡 Connectivity changed: ${_isOnline ? "Online" : "Offline"}');

    // If we just came online and have pending changes, trigger sync
    if (_isOnline && !wasOnline && _pendingCount > 0) {
      debugPrint('🔄 Back online with pending changes, triggering sync...');
      syncAll();
    }

    notifyListeners();
  }

  /// Start auto-sync timer
  void _startAutoSyncTimer() {
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (_isOnline && _pendingCount > 0) {
        debugPrint('⏰ Auto-sync triggered');
        syncAll();
      }
    });
  }

  /// Update pending count from database
  Future<void> _updatePendingCount() async {
    final tenantId = TenantService().tenantId;
    if (tenantId == null) {
      _pendingCount = 0;
    } else {
      _pendingCount = await _db.getPendingSyncCount(tenantId);
    }
    notifyListeners();
  }

  /// Perform a full sync (pull then push)
  Future<SyncResult> syncAll() async {
    if (_status == OverallSyncStatus.syncing) {
      return SyncResult(success: false, error: 'Sync already in progress');
    }

    if (!_isOnline) {
      _status = OverallSyncStatus.offline;
      notifyListeners();
      return SyncResult(success: false, error: 'No internet connection');
    }

    final tenantId = TenantService().tenantId;
    if (tenantId == null) {
      return SyncResult(success: false, error: 'No tenant selected');
    }

    _status = OverallSyncStatus.syncing;
    notifyListeners();

    try {
      int totalPulled = 0;
      int totalPushed = 0;

      // 1. Push local changes first
      final pushResult = await _pushChanges(tenantId);
      totalPushed = pushResult;

      // 2. Pull remote changes
      final pullResult = await _pullChanges(tenantId);
      totalPulled = pullResult;

      // Update pending count
      await _updatePendingCount();

      _status = OverallSyncStatus.success;
      _lastSyncTime = DateTime.now();
      _lastSyncResult = SyncResult(
        success: true,
        pushedCount: totalPushed,
        pulledCount: totalPulled,
      );

      debugPrint('✅ Sync complete: pushed $totalPushed, pulled $totalPulled');
    } catch (e) {
      debugPrint('❌ Sync error: $e');
      _status = OverallSyncStatus.error;
      _lastSyncResult = SyncResult(success: false, error: e.toString());
    }

    notifyListeners();
    return _lastSyncResult!;
  }

  /// Push local changes to Supabase
  Future<int> _pushChanges(String tenantId) async {
    int pushedCount = 0;

    // Push contacts
    pushedCount += await _pushContacts(tenantId);

    // Push groups
    pushedCount += await _pushGroups(tenantId);

    // Push group members
    pushedCount += await _pushGroupMembers(tenantId);

    // Push SMS logs
    pushedCount += await _pushSmsLogs(tenantId);

    return pushedCount;
  }

  /// Push pending contacts to Supabase
  Future<int> _pushContacts(String tenantId) async {
    final pendingContacts = await _db.getPendingContacts(tenantId);
    if (pendingContacts.isEmpty) return 0;

    int count = 0;
    final syncedIds = <String>[];
    final deletedIds = <String>[];

    for (final contact in pendingContacts) {
      try {
        if (contact.syncStatus == 'pending_create') {
          await _supabase.schema('sms_gateway').from('contacts').insert({
            'id': contact.id,
            'tenant_id': contact.tenantId,
            'user_id': contact.userId,
            'name': contact.name,
            'phone_number': contact.phoneNumber,
            'created_at': contact.createdAt.toIso8601String(),
          });
          syncedIds.add(contact.id);
          count++;
        } else if (contact.syncStatus == 'pending_update') {
          await _supabase.schema('sms_gateway').from('contacts').update({
            'name': contact.name,
            'phone_number': contact.phoneNumber,
          }).eq('id', contact.id);
          syncedIds.add(contact.id);
          count++;
        } else if (contact.syncStatus == 'pending_delete') {
          await _supabase
              .schema('sms_gateway')
              .from('contacts')
              .delete()
              .eq('id', contact.id);
          deletedIds.add(contact.id);
          count++;
        }
      } catch (e) {
        debugPrint('❌ Error pushing contact ${contact.id}: $e');
      }
    }

    // Mark as synced
    if (syncedIds.isNotEmpty) {
      await _db.markContactsSynced(syncedIds);
    }

    // Delete locally
    for (final id in deletedIds) {
      await _db.deleteContact(id);
    }

    return count;
  }

  /// Push pending groups to Supabase
  Future<int> _pushGroups(String tenantId) async {
    final pendingGroups = await _db.getPendingGroups(tenantId);
    if (pendingGroups.isEmpty) return 0;

    int count = 0;

    for (final group in pendingGroups) {
      try {
        if (group.syncStatus == 'pending_create') {
          await _supabase.schema('sms_gateway').from('groups').insert({
            'id': group.id,
            'tenant_id': group.tenantId,
            'user_id': group.userId,
            'name': group.name,
            'created_at': group.createdAt.toIso8601String(),
          });
          count++;
        } else if (group.syncStatus == 'pending_update') {
          await _supabase.schema('sms_gateway').from('groups').update({
            'name': group.name,
          }).eq('id', group.id);
          count++;
        } else if (group.syncStatus == 'pending_delete') {
          await _supabase
              .schema('sms_gateway')
              .from('groups')
              .delete()
              .eq('id', group.id);
          count++;
        }
      } catch (e) {
        debugPrint('❌ Error pushing group ${group.id}: $e');
      }
    }

    return count;
  }

  /// Push pending group members to Supabase
  Future<int> _pushGroupMembers(String tenantId) async {
    final pendingMembers = await _db.getPendingGroupMembers(tenantId);
    if (pendingMembers.isEmpty) return 0;

    int count = 0;

    for (final member in pendingMembers) {
      try {
        if (member.syncStatus == 'pending_create') {
          await _supabase.schema('sms_gateway').from('group_members').insert({
            'id': member.id,
            'group_id': member.groupId,
            'contact_id': member.contactId,
            'tenant_id': member.tenantId,
            'added_at': member.addedAt.toIso8601String(),
          });
          count++;
        } else if (member.syncStatus == 'pending_delete') {
          await _supabase
              .schema('sms_gateway')
              .from('group_members')
              .delete()
              .eq('id', member.id);
          count++;
        }
      } catch (e) {
        debugPrint('❌ Error pushing group member ${member.id}: $e');
      }
    }

    return count;
  }

  /// Push pending SMS logs to Supabase
  Future<int> _pushSmsLogs(String tenantId) async {
    final pendingLogs = await _db.getPendingSmsLogs(tenantId);
    if (pendingLogs.isEmpty) return 0;

    int count = 0;
    final syncedIds = <String>[];

    for (final log in pendingLogs) {
      try {
        if (log.syncStatus == 'pending_create') {
          await _supabase.schema('sms_gateway').from('sms_logs').insert({
            'id': log.id,
            'tenant_id': log.tenantId,
            'user_id': log.userId,
            'contact_id': log.contactId,
            'phone_number': log.phoneNumber,
            'message': log.message,
            'status': log.status,
            'sent_at': log.sentAt?.toIso8601String(),
            'error_message': log.errorMessage,
            'created_at': log.createdAt.toIso8601String(),
          });
          syncedIds.add(log.id);
          count++;
        }
      } catch (e) {
        debugPrint('❌ Error pushing SMS log ${log.id}: $e');
      }
    }

    // Mark as synced
    if (syncedIds.isNotEmpty) {
      await _db.markSmsLogsSynced(syncedIds);
    }

    return count;
  }

  /// Pull remote changes from Supabase
  Future<int> _pullChanges(String tenantId) async {
    int pulledCount = 0;

    // Pull contacts
    pulledCount += await _pullContacts(tenantId);

    // Pull groups
    pulledCount += await _pullGroups(tenantId);

    // Pull group members
    pulledCount += await _pullGroupMembers(tenantId);

    // Pull SMS logs (last 100 only for performance)
    pulledCount += await _pullSmsLogs(tenantId);

    return pulledCount;
  }

  /// Pull contacts from Supabase
  Future<int> _pullContacts(String tenantId) async {
    try {
      final response = await _supabase
          .schema('sms_gateway')
          .from('contacts')
          .select()
          .eq('tenant_id', tenantId);

      final remoteContacts = response as List;
      int count = 0;

      for (final json in remoteContacts) {
        final localContact = await _db.getContact(json['id']);

        // Skip if local has pending changes (local wins)
        if (localContact != null && localContact.syncStatus != 'synced') {
          continue;
        }

        await _db.upsertContact(LocalContactsCompanion(
          id: Value(json['id']),
          tenantId: Value(json['tenant_id']),
          userId: Value(json['user_id']),
          name: Value(json['name']),
          phoneNumber: Value(json['phone_number']),
          createdAt: Value(DateTime.parse(json['created_at'])),
          syncStatus: const Value('synced'),
          lastSyncedAt: Value(DateTime.now()),
        ));
        count++;
      }

      return count;
    } catch (e) {
      debugPrint('❌ Error pulling contacts: $e');
      return 0;
    }
  }

  /// Pull groups from Supabase
  Future<int> _pullGroups(String tenantId) async {
    try {
      final response = await _supabase
          .schema('sms_gateway')
          .from('groups')
          .select()
          .eq('tenant_id', tenantId);

      final remoteGroups = response as List;
      int count = 0;

      for (final json in remoteGroups) {
        await _db.upsertGroup(LocalGroupsCompanion(
          id: Value(json['id']),
          tenantId: Value(json['tenant_id']),
          userId: Value(json['user_id']),
          name: Value(json['name']),
          createdAt: Value(DateTime.parse(json['created_at'])),
          syncStatus: const Value('synced'),
          lastSyncedAt: Value(DateTime.now()),
        ));
        count++;
      }

      return count;
    } catch (e) {
      debugPrint('❌ Error pulling groups: $e');
      return 0;
    }
  }

  /// Pull group members from Supabase
  Future<int> _pullGroupMembers(String tenantId) async {
    try {
      final response = await _supabase
          .schema('sms_gateway')
          .from('group_members')
          .select()
          .eq('tenant_id', tenantId);

      final remoteMembers = response as List;
      int count = 0;

      for (final json in remoteMembers) {
        await _db.insertGroupMember(LocalGroupMembersCompanion(
          id: Value(json['id']),
          groupId: Value(json['group_id']),
          contactId: Value(json['contact_id']),
          tenantId: Value(json['tenant_id']),
          addedAt: Value(DateTime.parse(json['added_at'])),
          syncStatus: const Value('synced'),
        ));
        count++;
      }

      return count;
    } catch (e) {
      debugPrint('❌ Error pulling group members: $e');
      return 0;
    }
  }

  /// Pull SMS logs from Supabase (last 500)
  Future<int> _pullSmsLogs(String tenantId) async {
    try {
      final response = await _supabase
          .schema('sms_gateway')
          .from('sms_logs')
          .select()
          .eq('tenant_id', tenantId)
          .order('created_at', ascending: false)
          .limit(500);

      final remoteLogs = response as List;
      int count = 0;

      for (final json in remoteLogs) {
        await _db.insertSmsLog(LocalSmsLogsCompanion(
          id: Value(json['id']),
          tenantId: Value(json['tenant_id']),
          userId: Value(json['user_id']),
          contactId: Value(json['contact_id'] as String?),
          phoneNumber: Value(json['phone_number'] ?? json['recipient']),
          message: Value(json['message']),
          status: Value(json['status']),
          sentAt: Value(
              json['sent_at'] != null ? DateTime.parse(json['sent_at']) : null),
          errorMessage: Value(json['error_message'] as String?),
          createdAt: Value(DateTime.parse(json['created_at'])),
          syncStatus: const Value('synced'),
          lastSyncedAt: Value(DateTime.now()),
        ));
        count++;
      }

      return count;
    } catch (e) {
      debugPrint('❌ Error pulling SMS logs: $e');
      return 0;
    }
  }

  /// Pull data for initial load (when switching tenants)
  /// ✅ OPTIMIZED: Pull initial data with smart caching
  Future<void> pullInitialData(String tenantId) async {
    if (!_isOnline) {
      debugPrint('📡 Offline - using cached data');
      return;
    }

    // ✅ Check if data was recently pulled (within last 5 minutes)
    final prefs = await SharedPreferences.getInstance();
    final lastPullKey = 'last_pull_$tenantId';
    final lastPullStr = prefs.getString(lastPullKey);

    if (lastPullStr != null) {
      final lastPull = DateTime.parse(lastPullStr);
      final timeSinceLastPull = DateTime.now().difference(lastPull);

      if (timeSinceLastPull.inMinutes < 5) {
        debugPrint(
            '⚡ Using cached data (pulled ${timeSinceLastPull.inMinutes}m ago)');
        _status = OverallSyncStatus.success;
        notifyListeners();
        return;
      }
    }

    _status = OverallSyncStatus.syncing;
    notifyListeners();

    try {
      // Pull data in parallel for faster loading
      await Future.wait([
        _pullContacts(tenantId),
        _pullGroups(tenantId),
        _pullSmsLogs(tenantId),
      ]);

      // Pull group members after groups (dependency)
      await _pullGroupMembers(tenantId);

      // Save last pull timestamp
      await prefs.setString(lastPullKey, DateTime.now().toIso8601String());

      _status = OverallSyncStatus.success;
      debugPrint('✅ Initial data pull complete');
    } catch (e) {
      debugPrint('❌ Initial pull error: $e');
      _status = OverallSyncStatus.error;
    }

    notifyListeners();
  }

  /// Dispose resources
  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _autoSyncTimer?.cancel();
    super.dispose();
  }
}
