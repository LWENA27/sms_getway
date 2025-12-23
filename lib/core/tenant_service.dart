/// Tenant Service - Manages multi-tenant context for SMS Gateway
/// Stores current tenant selection in SharedPreferences
library;

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Model representing a tenant/workspace
class TenantModel {
  final String id;
  final String name;
  final String clientId;
  final String role;

  TenantModel({
    required this.id,
    required this.name,
    required this.clientId,
    required this.role,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'clientId': clientId,
        'role': role,
      };

  factory TenantModel.fromJson(Map<String, dynamic> json) => TenantModel(
        id: json['id'] as String,
        name: json['name'] as String,
        clientId: json['clientId'] as String,
        role: json['role'] as String,
      );

  @override
  String toString() => 'TenantModel(id: $id, name: $name, role: $role)';
}

/// Service to manage tenant selection and persistence
class TenantService extends ChangeNotifier {
  static const String _currentTenantKey = 'current_tenant_json';
  static const String _tenantsListKey = 'tenants_list_json';

  SharedPreferences? _prefs;
  TenantModel? _currentTenant;
  List<TenantModel> _tenants = [];
  bool _isInitialized = false;

  // Singleton pattern
  static final TenantService _instance = TenantService._internal();
  factory TenantService() => _instance;
  TenantService._internal();

  // Getters
  TenantModel? get currentTenant => _currentTenant;
  String? get tenantId => _currentTenant?.id;
  String? get tenantName => _currentTenant?.name;
  String? get clientId => _currentTenant?.clientId;
  List<TenantModel> get tenants => List.unmodifiable(_tenants);
  int get tenantsCount => _tenants.length;
  bool get isInitialized => _isInitialized;
  bool get hasTenant => _currentTenant != null;

  /// Initialize the service (call once at app startup)
  Future<void> initialize() async {
    if (_isInitialized) return;

    _prefs = await SharedPreferences.getInstance();
    await _loadFromStorage();
    _isInitialized = true;
    debugPrint('✅ TenantService initialized');
  }

  /// Load stored tenant data from SharedPreferences
  Future<void> _loadFromStorage() async {
    try {
      // Load tenants list
      final tenantsJson = _prefs?.getString(_tenantsListKey);
      if (tenantsJson != null) {
        final List<dynamic> tenantsList = jsonDecode(tenantsJson);
        _tenants = tenantsList
            .map((json) => TenantModel.fromJson(json as Map<String, dynamic>))
            .toList();
      }

      // Load current tenant
      final currentJson = _prefs?.getString(_currentTenantKey);
      if (currentJson != null) {
        _currentTenant = TenantModel.fromJson(jsonDecode(currentJson));
      }
    } catch (e) {
      debugPrint('❌ Error loading tenant data: $e');
    }
  }

  /// Fetch user's tenants from Supabase after login
  /// Returns: true if user has access, false if no tenants found
  Future<bool> loadTenantsForUser(String userId) async {
    try {
      debugPrint('🔍 Loading tenants for user: $userId');

      final supabase = Supabase.instance.client;

      // Query client_product_access joined with clients to get tenant info
      // Filter by product schema_name = 'sms_gateway'
      final response = await supabase.from('client_product_access').select('''
            tenant_id,
            role,
            client_id,
            clients!inner(name),
            products!inner(schema_name)
          ''').eq('user_id', userId).eq('products.schema_name', 'sms_gateway');

      debugPrint('📦 Raw response: $response');

      if ((response as List).isEmpty) {
        debugPrint('⚠️ No SMS Gateway access found for user');
        _tenants = [];
        await _saveToStorage();
        return false;
      }

      // Parse response into TenantModel list
      _tenants = response.map((record) {
        return TenantModel(
          id: record['tenant_id'] as String,
          name: record['clients']['name'] as String,
          clientId: record['client_id'] as String,
          role: record['role'] as String,
        );
      }).toList();

      debugPrint('✅ Found ${_tenants.length} tenant(s): $_tenants');
      await _saveToStorage();

      // Auto-select if only one tenant
      if (_tenants.length == 1) {
        await selectTenant(_tenants.first);
      }

      return true;
    } catch (e) {
      debugPrint('❌ Error loading tenants: $e');
      return false;
    }
  }

  /// Check if user should see tenant picker
  bool get shouldShowTenantPicker =>
      _tenants.length >= 2 && _currentTenant == null;

  /// Select a tenant and store in SharedPreferences
  Future<bool> selectTenant(TenantModel tenant) async {
    try {
      _currentTenant = tenant;
      await _saveToStorage();
      notifyListeners();
      debugPrint('✅ Selected tenant: ${tenant.name} (${tenant.id})');
      return true;
    } catch (e) {
      debugPrint('❌ Error selecting tenant: $e');
      return false;
    }
  }

  /// Save tenant data to SharedPreferences
  Future<void> _saveToStorage() async {
    try {
      // Save tenants list
      final tenantsJson = jsonEncode(_tenants.map((t) => t.toJson()).toList());
      await _prefs?.setString(_tenantsListKey, tenantsJson);

      // Save current tenant
      if (_currentTenant != null) {
        final currentJson = jsonEncode(_currentTenant!.toJson());
        await _prefs?.setString(_currentTenantKey, currentJson);
      } else {
        await _prefs?.remove(_currentTenantKey);
      }
    } catch (e) {
      debugPrint('❌ Error saving tenant data: $e');
    }
  }

  /// Clear all tenant data (on logout)
  Future<void> clear() async {
    _currentTenant = null;
    _tenants = [];
    await _prefs?.remove(_currentTenantKey);
    await _prefs?.remove(_tenantsListKey);
    notifyListeners();
    debugPrint('🧹 Tenant data cleared');
  }

  /// Switch to a different tenant (for multi-tenant users)
  Future<bool> switchTenant(String tenantId) async {
    final tenant = _tenants.firstWhere(
      (t) => t.id == tenantId,
      orElse: () => throw Exception('Tenant not found'),
    );
    return selectTenant(tenant);
  }

  /// Get tenant by ID
  TenantModel? getTenantById(String id) {
    try {
      return _tenants.firstWhere((t) => t.id == id);
    } catch (e) {
      return null;
    }
  }
}
