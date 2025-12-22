/// Tenant Service - Manages multi-tenant context for SMS Gateway
/// Stores current tenant selection in SharedPreferences
library;

import 'package:shared_preferences/shared_preferences.dart';

class TenantModel {
  final String id;
  final String name;
  final String slug;
  final String clientId;

  TenantModel({
    required this.id,
    required this.name,
    required this.slug,
    required this.clientId,
  });

  // Serialize to JSON for storage
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'slug': slug,
        'clientId': clientId,
      };

  // Deserialize from JSON
  factory TenantModel.fromJson(Map<String, dynamic> json) => TenantModel(
        id: json['id'] as String,
        name: json['name'] as String,
        slug: json['slug'] as String,
        clientId: json['clientId'] as String,
      );
}

class TenantService {
  static const String _currentTenantKey = 'current_tenant';
  static const String _tenantsListKey = 'tenants_list';

  late SharedPreferences _prefs;

  // Singleton pattern
  static final TenantService _instance = TenantService._internal();

  factory TenantService() {
    return _instance;
  }

  TenantService._internal();

  /// Initialize the service (call once at app startup)
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  /// Get current selected tenant
  /// Returns null if no tenant selected
  TenantModel? getCurrentTenant() {
    final tenantJson = _prefs.getString(_currentTenantKey);
    if (tenantJson == null) return null;

    try {
      // Parse JSON string back to map
      final Map<String, dynamic> json =
          Map.from((_prefs.get(_currentTenantKey) as Map?) ?? {});
      return TenantModel.fromJson(json);
    } catch (e) {
      print('Error parsing current tenant: $e');
      return null;
    }
  }

  /// Get current tenant ID only
  String? getCurrentTenantId() {
    return getCurrentTenant()?.id;
  }

  /// Select a tenant and store in SharedPreferences
  Future<bool> selectTenant(TenantModel tenant) async {
    try {
      // Store as JSON string
      final jsonStr = tenant.toJson().toString();

      // Also store separately for quick access
      await _prefs.setString('tenant_id', tenant.id);
      await _prefs.setString('tenant_name', tenant.name);
      await _prefs.setString('client_id', tenant.clientId);

      // Store full tenant object
      // Note: SharedPreferences doesn't have Map support, so we store as map representation
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        _currentTenantKey,
        [tenant.id, tenant.name, tenant.slug, tenant.clientId],
      );

      return true;
    } catch (e) {
      print('Error selecting tenant: $e');
      return false;
    }
  }

  /// Get current tenant ID (shortcut)
  String? getTenantId() {
    return _prefs.getString('tenant_id');
  }

  /// Get current tenant name
  String? getTenantName() {
    return _prefs.getString('tenant_name');
  }

  /// Get current client ID
  String? getClientId() {
    return _prefs.getString('client_id');
  }

  /// Set list of available tenants for current user
  /// Called after successful login
  Future<void> setTenantsList(List<TenantModel> tenants) async {
    try {
      // Store tenant IDs as list for quick reference
      final tenantIds = tenants.map((t) => t.id).toList();
      await _prefs.setStringList('available_tenant_ids', tenantIds);

      // Store full tenant data
      final tenantsJson = tenants
          .map((t) => '${t.id}|${t.name}|${t.slug}|${t.clientId}')
          .toList();
      await _prefs.setStringList('available_tenants', tenantsJson);
    } catch (e) {
      print('Error setting tenants list: $e');
    }
  }

  /// Get list of available tenants for current user
  List<TenantModel> getTenantsList() {
    try {
      final tenantsJson = _prefs.getStringList('available_tenants') ?? [];
      return tenantsJson.map((json) {
        final parts = json.split('|');
        return TenantModel(
          id: parts[0],
          name: parts[1],
          slug: parts[2],
          clientId: parts[3],
        );
      }).toList();
    } catch (e) {
      print('Error getting tenants list: $e');
      return [];
    }
  }

  /// Get count of available tenants
  int getTenantsCount() {
    return getTenantsList().length;
  }

  /// Check if user should see tenant picker
  /// Returns true if user has 2+ tenants
  bool shouldShowTenantPicker() {
    return getTenantsCount() >= 2;
  }

  /// Auto-select tenant if only one available
  /// Returns true if auto-selected, false if picker needed
  bool autoSelectIfSingleTenant() {
    final tenants = getTenantsList();
    if (tenants.length == 1) {
      selectTenant(tenants[0]);
      return true;
    }
    return false;
  }

  /// Clear current tenant selection (on logout)
  Future<void> clearTenant() async {
    await _prefs.remove('tenant_id');
    await _prefs.remove('tenant_name');
    await _prefs.remove('client_id');
    await _prefs.remove(_currentTenantKey);
    await _prefs.remove('available_tenants');
    await _prefs.remove('available_tenant_ids');
  }

  /// Get tenant by ID from available tenants
  TenantModel? getTenantById(String id) {
    try {
      final tenants = getTenantsList();
      return tenants.firstWhere((t) => t.id == id);
    } catch (e) {
      return null;
    }
  }
}
