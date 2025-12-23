import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme.dart';
import '../core/theme_provider.dart';
import '../core/tenant_service.dart';
import '../services/local_data_service.dart';
import '../services/sync_service.dart';
import '../services/api_sms_queue_service.dart';
import '../main.dart';
import 'profile_screen.dart';
import 'tenant_selector_screen.dart';
import 'api_settings_screen.dart';

// SMS Channel options
enum SmsChannel { thisPhone, quickSMS }

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? userEmail;
  String? userId;
  SmsChannel selectedChannel = SmsChannel.thisPhone;
  final TenantService _tenantService = TenantService();

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadChannelPreference();
  }

  void _loadUserInfo() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      setState(() {
        userEmail = user.email;
        userId = user.id;
      });
    }
  }

  void _loadChannelPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedChannel = prefs.getString('sms_channel') ?? 'thisPhone';
      setState(() {
        selectedChannel = savedChannel == 'quickSMS'
            ? SmsChannel.quickSMS
            : SmsChannel.thisPhone;
      });
      debugPrint('✅ Loaded SMS channel: $savedChannel');
    } catch (e) {
      debugPrint('❌ Error loading channel preference: $e');
    }
  }

  void _saveChannelPreference(SmsChannel channel) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final channelName =
          channel == SmsChannel.quickSMS ? 'quickSMS' : 'thisPhone';
      await prefs.setString('sms_channel', channelName);
      setState(() {
        selectedChannel = channel;
      });
      debugPrint('✅ Saved SMS channel: $channelName');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Channel changed to: ${channel.name}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving channel: $e')),
        );
      }
      debugPrint('❌ Error saving channel preference: $e');
    }
  }

  void _showChannelDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select SMS Channel'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<SmsChannel>(
              title: const Text('This Phone'),
              subtitle: const Text('Send SMS using device SIM'),
              value: SmsChannel.thisPhone,
              groupValue: selectedChannel,
              onChanged: (channel) {
                if (channel != null) {
                  _saveChannelPreference(channel);
                  Navigator.pop(context);
                }
              },
            ),
            RadioListTile<SmsChannel>(
              title: const Text('QuickSMS'),
              subtitle: const Text('Send SMS using QuickSMS API'),
              value: SmsChannel.quickSMS,
              groupValue: selectedChannel,
              onChanged: (channel) {
                if (channel != null) {
                  _saveChannelPreference(channel);
                  Navigator.pop(context);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _switchWorkspace() {
    if (_tenantService.tenantsCount < 2) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => TenantSelectorScreen(
          tenants: _tenantService.tenants,
        ),
      ),
      (route) => false,
    );
  }

  void _logout() async {
    try {
      // Clear tenant data first
      await _tenantService.clear();
      // Then sign out
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        // Navigate to AuthWrapper which handles login screen
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthWrapper()),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error logging out: $e')),
        );
      }
    }
  }

  String _formatLastSync(DateTime? lastSync) {
    if (lastSync == null) return 'Never';
    final now = DateTime.now();
    final diff = now.difference(lastSync);

    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: 'Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ProfileScreen()),
              );
            },
          ),
        ],
      ),
      body: ListView(
        children: [
          const SizedBox(height: AppTheme.paddingMedium),

          // Current Workspace Section
          if (_tenantService.hasTenant) ...[
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        _tenantService.tenantName?.isNotEmpty == true
                            ? _tenantService.tenantName![0].toUpperCase()
                            : 'O',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Current Workspace',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _tenantService.tenantName ?? 'Unknown',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_tenantService.tenantsCount >= 2)
                    TextButton(
                      onPressed: _switchWorkspace,
                      child: const Text('Switch'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
          ],

          // Settings Options
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Notifications'),
            trailing: Switch(
              value: true,
              onChanged: (value) {
                // TODO: Implement notification toggle
              },
            ),
          ),
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, child) {
              return ListTile(
                leading: const Icon(Icons.dark_mode),
                title: const Text('Dark Mode'),
                trailing: Opacity(
                  opacity: themeProvider.isLoading ? 0.5 : 1.0,
                  child: Switch(
                    value: themeProvider.isDarkMode,
                    onChanged: themeProvider.isLoading
                        ? null // Disable switch while loading
                        : (value) async {
                            await themeProvider.toggleTheme();
                          },
                  ),
                ),
              );
            },
          ),
          const Divider(),
          // SMS Channel Selection
          ListTile(
            leading: const Icon(Icons.sms),
            title: const Text('SMS Channel'),
            subtitle: Text(
              selectedChannel == SmsChannel.quickSMS
                  ? 'QuickSMS'
                  : 'This Phone',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _showChannelDialog,
          ),

          // API Settings
          ListenableBuilder(
            listenable: ApiSmsQueueService(),
            builder: (context, _) {
              final apiService = ApiSmsQueueService();
              return ListTile(
                leading: const Icon(Icons.api),
                title: const Text('API Integration'),
                subtitle: Text(
                  apiService.isEnabled
                      ? 'Active - ${apiService.pendingCount} pending'
                      : 'Manage API keys & queue',
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (apiService.pendingCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${apiService.pendingCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ApiSettingsScreen(),
                    ),
                  );
                },
              );
            },
          ),
          const Divider(),

          // Sync Section
          ListenableBuilder(
            listenable: SyncService(),
            builder: (context, _) {
              final syncService = SyncService();
              return Column(
                children: [
                  ListTile(
                    leading: Icon(
                      syncService.isOnline ? Icons.cloud_done : Icons.cloud_off,
                      color: syncService.isOnline ? Colors.green : Colors.grey,
                    ),
                    title: const Text('Sync Status'),
                    subtitle: Text(
                      syncService.isOnline
                          ? (syncService.isSyncing
                              ? 'Syncing...'
                              : 'Connected - Last synced: ${_formatLastSync(syncService.lastSyncTime)}')
                          : 'Offline - Changes will sync when online',
                    ),
                    trailing: syncService.isSyncing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : IconButton(
                            icon: const Icon(Icons.sync),
                            onPressed: syncService.isOnline
                                ? () async {
                                    await LocalDataService().syncNow();
                                    if (mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text('Sync completed')),
                                      );
                                    }
                                  }
                                : null,
                          ),
                  ),
                  FutureBuilder<int>(
                    future: LocalDataService().getPendingSyncCount(),
                    builder: (context, snapshot) {
                      final pendingCount = snapshot.data ?? 0;
                      if (pendingCount > 0) {
                        return Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.pending,
                                  color: Colors.orange, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                '$pendingCount pending change${pendingCount > 1 ? 's' : ''} waiting to sync',
                                style: const TextStyle(color: Colors.orange),
                              ),
                            ],
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              );
            },
          ),
          const Divider(),

          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('About'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'SMS Gateway',
                applicationVersion: '1.0.0',
                applicationIcon: const Icon(Icons.sms, size: 48),
                children: [
                  const Text('Professional Bulk SMS Management System'),
                  const SizedBox(height: 16),
                  const Text('© 2024 SMS Gateway'),
                ],
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.help),
            title: const Text('Help & Support'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Navigate to help screen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Help & Support coming soon')),
              );
            },
          ),
          const Divider(),
          Consumer<ThemeProvider>(
            builder: (context, themeProvider, _) {
              return Padding(
                padding: const EdgeInsets.all(AppTheme.paddingLarge),
                // Use a unique key that changes with theme to prevent animation errors
                child: ElevatedButton(
                  key: ValueKey('logout_${themeProvider.isDarkMode}'),
                  onPressed: _logout,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.errorColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppTheme.paddingMedium,
                      horizontal: AppTheme.paddingLarge,
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.logout),
                      SizedBox(width: AppTheme.paddingSmall),
                      Text('Logout'),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
