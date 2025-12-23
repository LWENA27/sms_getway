import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme.dart';
import '../core/theme_provider.dart';

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
        selectedChannel =
            savedChannel == 'quickSMS' ? SmsChannel.quickSMS : SmsChannel.thisPhone;
      });
      debugPrint('✅ Loaded SMS channel: $savedChannel');
    } catch (e) {
      debugPrint('❌ Error loading channel preference: $e');
    }
  }

  void _saveChannelPreference(SmsChannel channel) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final channelName = channel == SmsChannel.quickSMS ? 'quickSMS' : 'thisPhone';
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

  void _logout() async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error logging out: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        elevation: 0,
      ),
      body: ListView(
        children: [
          const SizedBox(height: AppTheme.paddingLarge),
          // User Profile Section
          Padding(
            padding: const EdgeInsets.all(AppTheme.paddingLarge),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.paddingLarge),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: AppTheme.primaryColor.withOpacity(0.2),
                      child: const Icon(
                        Icons.person,
                        size: 40,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    const SizedBox(height: AppTheme.paddingMedium),
                    Text(
                      userEmail ?? 'User',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppTheme.paddingSmall),
                    Text(
                      'User ID: ${userId ?? 'N/A'}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(),
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
