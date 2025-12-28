import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme.dart';
import '../core/tenant_service.dart';
import '../services/local_data_service.dart';
import '../services/web_sms_service.dart';
import '../api/native_sms_service.dart';
import '../contacts/contact_model.dart';
import '../groups/group_model.dart';

class BulkSmsScreen extends StatefulWidget {
  final VoidCallback? onNavigateToLogs;

  const BulkSmsScreen({super.key, this.onNavigateToLogs});

  @override
  State<BulkSmsScreen> createState() => _BulkSmsScreenState();
}

class _BulkSmsScreenState extends State<BulkSmsScreen> {
  final messageController = TextEditingController();
  List<Contact> selectedContacts = [];
  List<Contact> availableContacts = [];
  List<Group> availableGroups = [];
  bool isLoading = false;
  bool isLoadingContacts = true;
  String selectedMode = 'contacts'; // 'contacts' or 'group'
  String? selectedGroupId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    try {
      // Load from local database (offline-first)
      final contacts = await LocalDataService().getContacts();
      final groups = await LocalDataService().getGroups();

      if (mounted) {
        setState(() {
          availableContacts = contacts;
          availableGroups = groups;
          isLoadingContacts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoadingContacts = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  void _sendSms() async {
    if (messageController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a message')),
      );
      return;
    }

    List<Contact> recipients = [];
    if (selectedMode == 'contacts') {
      recipients = selectedContacts;
    } else if (selectedMode == 'group' && selectedGroupId != null) {
      try {
        // Load group contacts from local database
        recipients =
            await LocalDataService().getGroupContacts(selectedGroupId!);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error loading group members: $e')),
          );
        }
        return;
      }
    }

    if (recipients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select recipients')),
      );
      return;
    }

    // Load selected SMS channel from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final selectedChannel = prefs.getString('sms_channel') ?? 'thisPhone';
    debugPrint('📱 Using SMS Channel: $selectedChannel');

    setState(() => isLoading = true);

    try {
      final tenantId = TenantService().tenantId;
      if (tenantId == null) {
        throw 'No tenant selected';
      }

      // Platform detection: Check if we can send SMS natively
      final bool isAndroid = !kIsWeb && Platform.isAndroid;

      // If not Android, queue SMS for processing by mobile app
      if (!isAndroid) {
        await _queueSmsForMobile(recipients, messageController.text);
        return; // Exit early
      }

      // Android platform - Request SMS permission for "This Phone" channel
      if (selectedChannel == 'thisPhone') {
        final status = await Permission.sms.request();
        if (!status.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('SMS permission denied')),
            );
          }
          setState(() => isLoading = false);
          return;
        }
      }

      // Android platform - proceed with normal SMS sending
      int successCount = 0;
      int failureCount = 0;

      if (selectedChannel == 'thisPhone') {
        // Send SMS using device's native SMS capability
        await _sendSmsUsingDevice(
          recipients: recipients,
          message: messageController.text,
          tenantId: tenantId,
          onSuccess: (count) => successCount = count,
          onFailure: (count) => failureCount = count,
        );
      } else if (selectedChannel == 'quickSMS') {
        // Send SMS using QuickSMS API (to be implemented)
        debugPrint('🚀 Using QuickSMS API channel (not yet implemented)');
        // For now, just log to database
        await _logSmsToDatabase(
          recipients: recipients,
          message: messageController.text,
          tenantId: tenantId,
          channel: 'quickSMS',
          onSuccess: (count) => successCount = count,
          onFailure: (count) => failureCount = count,
        );
      }

      if (mounted) {
        setState(() => isLoading = false);
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('SMS Sent Successfully!'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text('✅ Success: $successCount'),
                const SizedBox(height: 8),
                if (failureCount > 0) Text('❌ Failed: $failureCount'),
                const SizedBox(height: 8),
                Text(
                  'Channel: ${selectedChannel == 'thisPhone' ? 'This Phone' : 'QuickSMS'}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'What would you like to do next?',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  messageController.clear();
                  setState(() {
                    selectedContacts = [];
                    selectedGroupId = null;
                  });
                },
                child: const Text('Send More'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onNavigateToLogs?.call();
                },
                child: const Text('View Logs'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
      debugPrint('❌ Error sending SMS: $e');
    }
  }

  Future<void> _sendSmsUsingDevice({
    required List<Contact> recipients,
    required String message,
    required String tenantId,
    required Function(int) onSuccess,
    required Function(int) onFailure,
  }) async {
    int successCount = 0;
    int failureCount = 0;

    try {
      // Extract phone numbers from recipients
      final phoneNumbers = recipients.map((r) => r.phoneNumber).toList();

      debugPrint(
          '📱 Sending SMS to ${phoneNumbers.length} recipients using native Android');

      // Send bulk SMS using native Android
      final result = await NativeSmsService.sendBulkSms(
        phoneNumbers: phoneNumbers,
        message: message,
      );

      successCount = result['successCount'] as int;
      final failedNumbers = result['failedNumbers'] as List<String>;
      failureCount = failedNumbers.length;

      debugPrint(
          '✅ Native SMS send complete: $successCount sent, $failureCount failed');

      // Log SMS to local database (offline-first)
      for (final recipient in recipients) {
        try {
          final wasSent = !failedNumbers.contains(recipient.phoneNumber);

          await LocalDataService().logSms(
            phoneNumber: recipient.phoneNumber,
            message: message,
            status: wasSent ? 'sent' : 'failed',
            contactId: recipient.id,
            channel: 'thisPhone',
          );

          debugPrint('📊 SMS logged for ${recipient.phoneNumber}');
        } catch (e) {
          debugPrint('❌ Error logging SMS for ${recipient.phoneNumber}: $e');
        }
      }
    } catch (e) {
      failureCount = recipients.length;
      debugPrint('❌ Error sending bulk SMS: $e');
    }

    onSuccess(successCount);
    onFailure(failureCount);
  }

  /// Queue SMS for mobile app processing (Web/iOS/non-Android platforms)
  Future<void> _queueSmsForMobile(
      List<Contact> recipients, String message) async {
    try {
      final phoneNumbers = recipients.map((r) => r.phoneNumber).toList();

      debugPrint(
          '🌐 [Platform: ${kIsWeb ? "Web" : Platform.operatingSystem}] Queuing ${phoneNumbers.length} SMS');

      // Queue SMS requests using WebSmsService
      await WebSmsService().queueBulkSms(
        phoneNumbers: phoneNumbers,
        message: message,
        priority: 0,
        metadata: {
          'source': 'bulk_sms_screen',
          'platform': kIsWeb ? 'web' : Platform.operatingSystem,
        },
      );

      debugPrint('✅ SMS queued successfully');

      if (mounted) {
        setState(() => isLoading = false);

        // Show popup: SMS pending, login to mobile to send
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                Icon(Icons.schedule_send,
                    color: Theme.of(context).primaryColor),
                const SizedBox(width: 12),
                const Text('SMS Pending'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '📱 ${phoneNumbers.length} SMS queued for sending',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 20, color: Colors.orange.shade700),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'To send these SMS:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text('✅ Login to mobile app (Android)'),
                      const Text('✅ Enable queue processing in Settings'),
                      const Text('✅ Keep app running in background'),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  messageController.clear();
                  setState(() {
                    selectedContacts = [];
                    selectedGroupId = null;
                  });
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error queuing SMS: $e');
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error queuing SMS: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _logSmsToDatabase({
    required List<Contact> recipients,
    required String message,
    required String tenantId,
    required String channel,
    required Function(int) onSuccess,
    required Function(int) onFailure,
  }) async {
    int successCount = 0;
    int failureCount = 0;

    for (final recipient in recipients) {
      try {
        await LocalDataService().logSms(
          phoneNumber: recipient.phoneNumber,
          message: message,
          status: 'sent',
          contactId: recipient.id,
          channel: channel,
        );

        successCount++;
        debugPrint('✅ SMS logged via $channel for ${recipient.phoneNumber}');
      } catch (e) {
        failureCount++;
        debugPrint('❌ Error logging SMS for ${recipient.phoneNumber}: $e');
      }
    }

    onSuccess(successCount);
    onFailure(failureCount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send SMS'),
        elevation: 0,
      ),
      body: isLoadingContacts
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.paddingMedium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Mode selector
                  Text(
                    'Mode',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Contacts'),
                          selected: selectedMode == 'contacts',
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                selectedMode = 'contacts';
                                selectedGroupId = null;
                              });
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ChoiceChip(
                          label: const Text('Group'),
                          selected: selectedMode == 'group',
                          onSelected: (selected) {
                            if (selected) {
                              setState(() => selectedMode = 'group');
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Group selector
                  if (selectedMode == 'group') ...[
                    Text(
                      'Select Group',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: selectedGroupId,
                      hint: const Text('Choose a group'),
                      items: availableGroups
                          .map((group) => DropdownMenuItem(
                                value: group.id,
                                child: Text(
                                  '${group.name} (${group.memberCount ?? 0} members)',
                                ),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() => selectedGroupId = value);
                      },
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Individual contact selector
                  if (selectedMode == 'contacts') ...[
                    Text(
                      'Select Recipients (${selectedContacts.length} selected)',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 250,
                      child: ListView.builder(
                        itemCount: availableContacts.length,
                        itemBuilder: (context, index) {
                          final contact = availableContacts[index];
                          final isSelected =
                              selectedContacts.any((c) => c.id == contact.id);
                          return CheckboxListTile(
                            title: Text(contact.name),
                            subtitle: Text(contact.phoneNumber),
                            value: isSelected,
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  selectedContacts.add(contact);
                                } else {
                                  selectedContacts
                                      .removeWhere((c) => c.id == contact.id);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Message input
                  Text(
                    'Message',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: messageController,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: 'Enter your message',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Characters: ${messageController.text.length}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                  ),
                  const SizedBox(height: 24),

                  // Send button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: isLoading ? null : _sendSms,
                      icon: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                      label: Text(isLoading ? 'Sending...' : 'Send SMS'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  @override
  void dispose() {
    messageController.dispose();
    super.dispose();
  }
}
