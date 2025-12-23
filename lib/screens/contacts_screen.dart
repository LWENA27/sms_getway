import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import '../core/theme.dart';
import '../core/tenant_service.dart';
import '../contacts/contact_model.dart';
import '../groups/group_model.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Contact> contacts = [];
  List<Group> groups = [];
  bool isLoading = true;

  // Selection mode for bulk operations
  bool isSelectionMode = false;
  Set<String> selectedContactIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        // Exit selection mode when switching tabs
        if (isSelectionMode) {
          setState(() {
            isSelectionMode = false;
            selectedContactIds.clear();
          });
        }
        setState(() {});
      }
    });
    _loadContacts();
    _loadGroups();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _loadContacts() async {
    try {
      final tenantId = TenantService().tenantId;
      if (tenantId == null) {
        debugPrint('❌ No tenant selected');
        return;
      }

      debugPrint('📱 Loading contacts for tenant: $tenantId');

      final response = await Supabase.instance.client
          .schema('sms_gateway')
          .from('contacts')
          .select()
          .eq('tenant_id', tenantId);

      debugPrint('✅ Loaded ${(response as List).length} contacts');

      if (mounted) {
        setState(() {
          contacts =
              (response as List).map((json) => Contact.fromJson(json)).toList();
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading data: $e');
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading contacts: $e')),
        );
      }
    }
  }

  void _loadGroups() async {
    try {
      final tenantId = TenantService().tenantId;
      if (tenantId == null) return;

      final response = await Supabase.instance.client
          .schema('sms_gateway')
          .from('groups')
          .select('*, group_members(id)')
          .eq('tenant_id', tenantId);

      if (mounted) {
        setState(() {
          groups = (response as List).map((json) {
            final group = Group.fromJson(json);
            // Count the actual members from the joined data
            final memberCount = json['group_members'] != null
                ? (json['group_members'] as List).length
                : 0;
            return group.copyWith(memberCount: memberCount);
          }).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading groups: $e')),
        );
      }
    }
  }

  void _addContact() {
    showDialog(
      context: context,
      builder: (context) => AddContactDialog(
        onAdd: (contact) {
          _loadContacts();
          Navigator.pop(context);
        },
      ),
    );
  }

  void _deleteContact(String id) async {
    try {
      await Supabase.instance.client
          .schema('sms_gateway')
          .from('contacts')
          .delete()
          .eq('id', id);
      _loadContacts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Contact deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  /// Toggle selection mode
  void _toggleSelectionMode() {
    setState(() {
      isSelectionMode = !isSelectionMode;
      if (!isSelectionMode) {
        selectedContactIds.clear();
      }
    });
  }

  /// Toggle contact selection
  void _toggleContactSelection(String id) {
    setState(() {
      if (selectedContactIds.contains(id)) {
        selectedContactIds.remove(id);
        // Exit selection mode if no contacts selected
        if (selectedContactIds.isEmpty) {
          isSelectionMode = false;
        }
      } else {
        selectedContactIds.add(id);
      }
    });
  }

  /// Select all contacts
  void _selectAllContacts() {
    setState(() {
      if (selectedContactIds.length == contacts.length) {
        // Deselect all
        selectedContactIds.clear();
      } else {
        // Select all
        selectedContactIds = contacts.map((c) => c.id).toSet();
      }
    });
  }

  /// Delete selected contacts
  void _deleteSelectedContacts() async {
    if (selectedContactIds.isEmpty) return;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Contacts'),
        content: Text(
          'Are you sure you want to delete ${selectedContactIds.length} contact${selectedContactIds.length > 1 ? 's' : ''}?\n\nThis action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show progress dialog
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Text('Deleting ${selectedContactIds.length} contacts...'),
          ],
        ),
      ),
    );

    try {
      int deleted = 0;
      int errors = 0;

      for (final id in selectedContactIds) {
        try {
          await Supabase.instance.client
              .schema('sms_gateway')
              .from('contacts')
              .delete()
              .eq('id', id);
          deleted++;
        } catch (e) {
          errors++;
          debugPrint('Error deleting contact $id: $e');
        }
      }

      // Close progress dialog
      if (mounted) Navigator.pop(context);

      // Exit selection mode
      setState(() {
        isSelectionMode = false;
        selectedContactIds.clear();
      });

      // Reload contacts
      _loadContacts();

      // Show result
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errors == 0
                  ? '$deleted contact${deleted > 1 ? 's' : ''} deleted'
                  : '$deleted deleted, $errors failed',
            ),
            backgroundColor: errors == 0 ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _createGroup() {
    showDialog(
      context: context,
      builder: (context) => CreateGroupDialog(
        onCreate: (group) {
          _loadGroups();
          Navigator.pop(context);
        },
      ),
    );
  }

  void _deleteGroup(String id) async {
    try {
      await Supabase.instance.client
          .schema('sms_gateway')
          .from('groups')
          .delete()
          .eq('id', id);
      _loadGroups();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group deleted')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _showGroupMembers(Group group) {
    showDialog(
      context: context,
      builder: (context) => GroupMembersDialog(
        group: group,
        onUpdate: _loadGroups,
      ),
    );
  }

  /// Default country code for phone number formatting (Tanzania)
  static const String _defaultCountryCode = '+255';

  /// Format phone number to international format
  /// Converts local numbers like 0653489534 to +255653489534
  String _formatPhoneNumber(String phone) {
    // Remove all non-digit characters except +
    phone = phone.replaceAll(RegExp(r'[^\d+]'), '');

    if (phone.isEmpty) return '';

    // Already has + prefix - assume it's international
    if (phone.startsWith('+')) {
      return phone;
    }

    // Starts with 00 - replace with +
    if (phone.startsWith('00')) {
      return '+${phone.substring(2)}';
    }

    // Starts with 0 - replace with country code
    if (phone.startsWith('0')) {
      return '$_defaultCountryCode${phone.substring(1)}';
    }

    // Starts with country code without + (e.g., 255...)
    if (phone.startsWith('255') && phone.length >= 12) {
      return '+$phone';
    }

    // Otherwise, assume local and add country code
    return '$_defaultCountryCode$phone';
  }

  /// Import contacts from a CSV file
  void _importCsvContacts() async {
    try {
      // Pick CSV file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return; // User cancelled
      }

      final file = result.files.first;
      if (file.path == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not read file')),
          );
        }
        return;
      }

      // Show loading dialog
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Reading file...'),
            ],
          ),
        ),
      );

      // Read and parse CSV
      final fileContent = await File(file.path!).readAsString();
      final csvTable = const CsvToListConverter().convert(fileContent);

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (csvTable.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('CSV file is empty')),
          );
        }
        return;
      }

      // Detect header row and find columns
      int nameIndex = 0;
      int phoneIndex = 1;
      int startRow = 0;

      if (csvTable.isNotEmpty) {
        final firstRow = csvTable[0];
        for (int i = 0; i < firstRow.length; i++) {
          final cell = firstRow[i].toString().toLowerCase().trim();
          if (cell.contains('name')) {
            nameIndex = i;
            startRow = 1;
          } else if (cell.contains('phone') ||
              cell.contains('number') ||
              cell.contains('mobile')) {
            phoneIndex = i;
            startRow = 1;
          }
        }
      }

      // Parse contacts for preview
      List<Map<String, String>> parsedContacts = [];
      List<String> warnings = [];

      for (int i = startRow; i < csvTable.length; i++) {
        final row = csvTable[i];
        if (row.length < 2) continue;

        String name = row[nameIndex].toString().trim();
        String rawPhone = row[phoneIndex].toString().trim();
        String formattedPhone = _formatPhoneNumber(rawPhone);

        if (name.isEmpty || formattedPhone.isEmpty) {
          warnings.add('Row ${i + 1}: Missing name or phone');
          continue;
        }

        // Validate phone (at least 10 digits for international)
        if (formattedPhone.replaceAll('+', '').length < 10) {
          warnings.add('Row ${i + 1}: Invalid phone "$rawPhone"');
          continue;
        }

        parsedContacts.add({
          'name': name,
          'phone': formattedPhone,
          'original': rawPhone,
        });
      }

      if (parsedContacts.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No valid contacts found in file')),
          );
        }
        return;
      }

      // Show confirmation screen
      if (mounted) {
        _showImportConfirmation(parsedContacts, warnings, 'CSV');
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import error: $e')),
        );
      }
    }
  }

  /// Import contacts from a VCF (vCard) file
  void _importVcfContacts() async {
    try {
      // Pick VCF file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['vcf', 'vcard'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return; // User cancelled
      }

      final file = result.files.first;
      if (file.path == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not read file')),
          );
        }
        return;
      }

      // Show loading dialog
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Reading VCF file...'),
            ],
          ),
        ),
      );

      // Read and parse VCF
      final fileContent = await File(file.path!).readAsString();
      final vcards = _parseVcf(fileContent);

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      if (vcards.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('VCF file is empty or invalid')),
          );
        }
        return;
      }

      // Parse contacts for preview with formatted phone numbers
      List<Map<String, String>> parsedContacts = [];
      List<String> warnings = [];

      for (int i = 0; i < vcards.length; i++) {
        final vcard = vcards[i];
        final name = vcard['name'] ?? '';
        final rawPhone = vcard['phone'] ?? '';
        final formattedPhone = _formatPhoneNumber(rawPhone);

        if (name.isEmpty || formattedPhone.isEmpty) {
          warnings.add('Contact ${i + 1}: Missing name or phone');
          continue;
        }

        // Validate phone (at least 10 digits for international)
        if (formattedPhone.replaceAll('+', '').length < 10) {
          warnings.add('Contact ${i + 1}: Invalid phone "$rawPhone"');
          continue;
        }

        parsedContacts.add({
          'name': name,
          'phone': formattedPhone,
          'original': rawPhone,
        });
      }

      if (parsedContacts.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No valid contacts found in file')),
          );
        }
        return;
      }

      // Show confirmation screen
      if (mounted) {
        _showImportConfirmation(parsedContacts, warnings, 'VCF');
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('VCF import error: $e')),
        );
      }
    }
  }

  /// Show confirmation dialog before importing contacts
  void _showImportConfirmation(
    List<Map<String, String>> contacts,
    List<String> warnings,
    String source,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    source == 'CSV' ? Icons.table_chart : Icons.contact_phone,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Import from $source',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          '${contacts.length} contacts ready to import',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Warnings if any
            if (warnings.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${warnings.length} contacts skipped (invalid data)',
                        style: const TextStyle(color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            // Info about phone format
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info, color: Colors.blue, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Numbers will be converted to international format ($_defaultCountryCode)',
                      style: const TextStyle(color: Colors.blue, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(),
            // Contact list preview
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: contacts.length,
                itemBuilder: (context, index) {
                  final contact = contacts[index];
                  final showConversion =
                      contact['original'] != contact['phone'];
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(contact['name']![0].toUpperCase()),
                    ),
                    title: Text(contact['name']!),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          contact['phone']!,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            color: Colors.green,
                          ),
                        ),
                        if (showConversion)
                          Text(
                            'Original: ${contact['original']}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                          ),
                      ],
                    ),
                    trailing: const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 20,
                    ),
                  );
                },
              ),
            ),
            // Action buttons
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _executeImport(contacts);
                        },
                        icon: const Icon(Icons.download),
                        label: Text('Import ${contacts.length} Contacts'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Execute the actual import after confirmation
  void _executeImport(List<Map<String, String>> contacts) async {
    // Show progress dialog
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('Importing contacts...'),
          ],
        ),
      ),
    );

    try {
      // Get user info
      final userId = Supabase.instance.client.auth.currentUser?.id;
      final tenantId = TenantService().tenantId;
      if (userId == null || tenantId == null) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('User not logged in or no tenant selected')),
          );
        }
        return;
      }

      int imported = 0;
      int skipped = 0;
      int errors = 0;
      List<String> errorMessages = [];

      for (int i = 0; i < contacts.length; i++) {
        final contact = contacts[i];
        final name = contact['name']!;
        final phone = contact['phone']!;

        try {
          await Supabase.instance.client
              .schema('sms_gateway')
              .from('contacts')
              .insert({
            'id': const Uuid().v4(),
            'user_id': userId,
            'tenant_id': tenantId,
            'name': name,
            'phone_number': phone,
          });
          imported++;
        } catch (e) {
          if (e.toString().contains('duplicate') ||
              e.toString().contains('unique')) {
            skipped++;
            errorMessages.add('${i + 1}. "$name": Duplicate');
          } else {
            errors++;
            errorMessages.add('${i + 1}. "$name": $e');
          }
        }
      }

      // Close progress dialog
      if (mounted) Navigator.pop(context);

      // Reload contacts
      _loadContacts();

      // Show result
      if (mounted) {
        _showImportResultDialog(imported, skipped, errors, errorMessages);
      }
    } catch (e) {
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import error: $e')),
        );
      }
    }
  }

  /// Parse VCF (vCard) content into a list of contacts
  List<Map<String, String>> _parseVcf(String content) {
    final List<Map<String, String>> contacts = [];
    final lines = content.split('\n');

    String? currentName;
    String? currentPhone;
    bool inVcard = false;

    for (var line in lines) {
      line = line.trim();

      if (line.startsWith('BEGIN:VCARD')) {
        inVcard = true;
        currentName = null;
        currentPhone = null;
      } else if (line.startsWith('END:VCARD')) {
        if (inVcard && (currentName != null || currentPhone != null)) {
          contacts.add({
            'name': currentName ?? 'Unknown',
            'phone': currentPhone ?? '',
          });
        }
        inVcard = false;
      } else if (inVcard) {
        // Parse FN (Full Name) - preferred
        if (line.startsWith('FN:') || line.startsWith('FN;')) {
          currentName = _extractVcfValue(line);
        }
        // Parse N (Name) as fallback - format: Last;First;Middle;Prefix;Suffix
        else if (line.startsWith('N:') || line.startsWith('N;')) {
          if (currentName == null || currentName.isEmpty) {
            final nameParts = _extractVcfValue(line).split(';');
            if (nameParts.length >= 2) {
              final firstName = nameParts[1].trim();
              final lastName = nameParts[0].trim();
              currentName = '$firstName $lastName'.trim();
            } else if (nameParts.isNotEmpty) {
              currentName = nameParts[0].trim();
            }
          }
        }
        // Parse TEL (Phone) - prefer CELL or first available
        else if (line.startsWith('TEL')) {
          // Extract phone number
          final phone = _extractVcfValue(line);
          // Prefer cell phone, but take first if no cell
          if (line.toUpperCase().contains('CELL') ||
              line.toUpperCase().contains('MOBILE') ||
              currentPhone == null) {
            currentPhone = phone;
          }
        }
      }
    }

    return contacts;
  }

  /// Extract value from VCF line (handles various formats)
  String _extractVcfValue(String line) {
    // Handle lines like "TEL;TYPE=CELL:+1234567890" or "FN:John Doe"
    final colonIndex = line.indexOf(':');
    if (colonIndex == -1) return line;
    return line.substring(colonIndex + 1).trim();
  }

  void _showImportResultDialog(
      int imported, int skipped, int errors, List<String> errorMessages) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              imported > 0 ? Icons.check_circle : Icons.info,
              color: imported > 0 ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 8),
            const Text('Import Complete'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildResultRow(Icons.check, Colors.green, 'Imported', imported),
            _buildResultRow(Icons.skip_next, Colors.orange, 'Skipped', skipped),
            if (errors > 0)
              _buildResultRow(Icons.error, Colors.red, 'Errors', errors),
            if (errorMessages.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Details:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 150),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: errorMessages
                        .take(10)
                        .map(
                          (msg) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(msg,
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
              if (errorMessages.length > 10)
                Text(
                  '... and ${errorMessages.length - 10} more',
                  style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic),
                ),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(IconData icon, Color color, String label, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 8),
          Text('$label: '),
          Text('$count',
              style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_add),
              title: const Text('Add Contact'),
              subtitle: const Text('Manually enter a new contact'),
              onTap: () {
                Navigator.pop(context);
                _addContact();
              },
            ),
            ListTile(
              leading: const Icon(Icons.upload_file),
              title: const Text('Import from CSV'),
              subtitle: const Text('Import contacts from a CSV file'),
              onTap: () {
                Navigator.pop(context);
                _importCsvContacts();
              },
            ),
            ListTile(
              leading: const Icon(Icons.contact_phone),
              title: const Text('Import from VCF'),
              subtitle: const Text('Import contacts from vCard file'),
              onTap: () {
                Navigator.pop(context);
                _importVcfContacts();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: isSelectionMode ? _buildSelectionAppBar() : _buildNormalAppBar(),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildContactsTab(),
          _buildGroupsTab(),
        ],
      ),
      floatingActionButton: isSelectionMode
          ? null // Hide FAB in selection mode
          : FloatingActionButton(
              onPressed: () {
                if (_tabController.index == 0) {
                  _showAddOptions(); // Show options: Add Contact or Import CSV
                } else {
                  _createGroup();
                }
              },
              child: const Icon(Icons.add),
            ),
    );
  }

  /// Normal AppBar with tabs
  PreferredSizeWidget _buildNormalAppBar() {
    return AppBar(
      title: const Text('Contacts & Groups'),
      elevation: 0,
      bottom: TabBar(
        controller: _tabController,
        tabs: const [
          Tab(icon: Icon(Icons.contacts), text: 'Contacts'),
          Tab(icon: Icon(Icons.group), text: 'Groups'),
        ],
      ),
    );
  }

  /// Selection mode AppBar with actions
  PreferredSizeWidget _buildSelectionAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () {
          setState(() {
            isSelectionMode = false;
            selectedContactIds.clear();
          });
        },
      ),
      title: Text('${selectedContactIds.length} selected'),
      elevation: 0,
      actions: [
        // Select all button
        IconButton(
          icon: Icon(
            selectedContactIds.length == contacts.length
                ? Icons.deselect
                : Icons.select_all,
          ),
          tooltip: selectedContactIds.length == contacts.length
              ? 'Deselect all'
              : 'Select all',
          onPressed: _selectAllContacts,
        ),
        // Delete button
        IconButton(
          icon: const Icon(Icons.delete),
          tooltip: 'Delete selected',
          onPressed:
              selectedContactIds.isEmpty ? null : _deleteSelectedContacts,
        ),
      ],
    );
  }

  Widget _buildContactsTab() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (contacts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.contacts_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No contacts yet'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _addContact,
              icon: const Icon(Icons.add),
              label: const Text('Add Contact'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: contacts.length,
      itemBuilder: (context, index) {
        final contact = contacts[index];
        final isSelected = selectedContactIds.contains(contact.id);

        return Card(
          margin: const EdgeInsets.symmetric(
            horizontal: AppTheme.paddingMedium,
            vertical: AppTheme.paddingSmall,
          ),
          color: isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : null,
          child: ListTile(
            leading: isSelectionMode
                ? Checkbox(
                    value: isSelected,
                    onChanged: (_) => _toggleContactSelection(contact.id),
                  )
                : CircleAvatar(
                    child: Text(contact.name[0].toUpperCase()),
                  ),
            title: Text(contact.name),
            subtitle: Text(contact.phoneNumber),
            trailing: isSelectionMode
                ? null
                : IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteContact(contact.id),
                  ),
            onTap: isSelectionMode
                ? () => _toggleContactSelection(contact.id)
                : null,
            onLongPress: isSelectionMode
                ? null
                : () {
                    // Enter selection mode on long press
                    setState(() {
                      isSelectionMode = true;
                      selectedContactIds.add(contact.id);
                    });
                  },
          ),
        );
      },
    );
  }

  Widget _buildGroupsTab() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (groups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.group_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('No groups yet'),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _createGroup,
              icon: const Icon(Icons.add),
              label: const Text('Create Group'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        return Card(
          margin: const EdgeInsets.symmetric(
            horizontal: AppTheme.paddingMedium,
            vertical: AppTheme.paddingSmall,
          ),
          child: ListTile(
            leading: CircleAvatar(
              child: Text(group.name[0].toUpperCase()),
            ),
            title: Text(group.name),
            subtitle: Text('${group.memberCount ?? 0} members'),
            trailing: IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteGroup(group.id),
            ),
            onTap: () => _showGroupMembers(group),
          ),
        );
      },
    );
  }
}

// Add Contact Dialog
class AddContactDialog extends StatefulWidget {
  final Function(Contact) onAdd;

  const AddContactDialog({required this.onAdd, super.key});

  @override
  State<AddContactDialog> createState() => _AddContactDialogState();
}

class _AddContactDialogState extends State<AddContactDialog> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  bool isLoading = false;
  String? formattedPhone;

  /// Default country code for phone number formatting (Tanzania)
  static const String _defaultCountryCode = '+255';

  /// Format phone number to international format
  String _formatPhoneNumber(String phone) {
    phone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (phone.isEmpty) return '';
    if (phone.startsWith('+')) return phone;
    if (phone.startsWith('00')) return '+${phone.substring(2)}';
    if (phone.startsWith('0'))
      return '$_defaultCountryCode${phone.substring(1)}';
    if (phone.startsWith('255') && phone.length >= 12) return '+$phone';
    return '$_defaultCountryCode$phone';
  }

  void _updateFormattedPhone() {
    final raw = phoneController.text.trim();
    if (raw.isNotEmpty) {
      setState(() {
        formattedPhone = _formatPhoneNumber(raw);
      });
    } else {
      setState(() {
        formattedPhone = null;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    phoneController.addListener(_updateFormattedPhone);
  }

  void _save() async {
    if (nameController.text.isEmpty || phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    final phone = _formatPhoneNumber(phoneController.text.trim());

    // Validate phone (at least 10 digits for international)
    if (phone.replaceAll('+', '').length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid phone number')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      final tenantId = TenantService().tenantId;
      if (userId == null || tenantId == null)
        throw 'User not logged in or no tenant selected';

      final contact = Contact(
        id: const Uuid().v4(),
        userId: userId,
        tenantId: tenantId,
        name: nameController.text,
        phoneNumber: phone, // Use formatted phone
        createdAt: DateTime.now(),
      );

      await Supabase.instance.client
          .schema('sms_gateway')
          .from('contacts')
          .insert(contact.toJson());

      if (mounted) {
        widget.onAdd(contact);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Contact'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'John Doe',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: phoneController,
            decoration: InputDecoration(
              labelText: 'Phone Number',
              hintText: '0653489534',
              helperText: formattedPhone != null
                  ? 'Will be saved as: $formattedPhone'
                  : 'Numbers will be formatted to international format',
              helperStyle: TextStyle(
                color: formattedPhone != null ? Colors.green : Colors.grey,
                fontSize: 12,
              ),
            ),
            keyboardType: TextInputType.phone,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: isLoading ? null : _save,
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    super.dispose();
  }
}

// Create Group Dialog
class CreateGroupDialog extends StatefulWidget {
  final Function(Group) onCreate;

  const CreateGroupDialog({required this.onCreate, super.key});

  @override
  State<CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<CreateGroupDialog> {
  final nameController = TextEditingController();
  List<Contact> selectedContacts = [];
  List<Contact> availableContacts = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadAvailableContacts();
  }

  void _loadAvailableContacts() async {
    try {
      final tenantId = TenantService().tenantId;
      if (tenantId == null) return;

      final response = await Supabase.instance.client
          .schema('sms_gateway')
          .from('contacts')
          .select()
          .eq('tenant_id', tenantId);

      if (mounted) {
        setState(() {
          availableContacts =
              (response as List).map((json) => Contact.fromJson(json)).toList();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading contacts: $e')),
        );
      }
    }
  }

  void _save() async {
    if (nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter group name')),
      );
      return;
    }

    if (selectedContacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one member')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      final tenantId = TenantService().tenantId;
      if (userId == null || tenantId == null)
        throw 'User not logged in or no tenant selected';

      final groupId = const Uuid().v4();

      final group = Group(
        id: groupId,
        userId: userId,
        tenantId: tenantId,
        name: nameController.text,
        createdAt: DateTime.now(),
        memberCount: selectedContacts.length,
      );

      await Supabase.instance.client
          .schema('sms_gateway')
          .from('groups')
          .insert(group.toJson());

      // Add members
      for (final contact in selectedContacts) {
        final member = GroupMember(
          id: const Uuid().v4(),
          groupId: groupId,
          contactId: contact.id,
          tenantId: tenantId,
          addedAt: DateTime.now(),
        );
        await Supabase.instance.client
            .schema('sms_gateway')
            .from('group_members')
            .insert(member.toJson());
      }

      if (mounted) {
        widget.onCreate(group);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.paddingMedium),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Create Group',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Group Name',
                  hintText: 'e.g., Work Team',
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Select Members (${selectedContacts.length} selected)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 300,
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
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: isLoading ? null : _save,
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Create'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }
}

// Group Members Dialog
class GroupMembersDialog extends StatefulWidget {
  final Group group;
  final VoidCallback onUpdate;

  const GroupMembersDialog({
    required this.group,
    required this.onUpdate,
    super.key,
  });

  @override
  State<GroupMembersDialog> createState() => _GroupMembersDialogState();
}

class _GroupMembersDialogState extends State<GroupMembersDialog> {
  List<Contact> members = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  void _loadMembers() async {
    try {
      final memberIds = await Supabase.instance.client
          .schema('sms_gateway')
          .from('group_members')
          .select('contact_id')
          .eq('group_id', widget.group.id);

      final contactIds =
          (memberIds as List).map((m) => m['contact_id'] as String).toList();

      if (contactIds.isEmpty) {
        if (mounted) {
          setState(() {
            members = [];
            isLoading = false;
          });
        }
        return;
      }

      final contacts = await Supabase.instance.client
          .schema('sms_gateway')
          .from('contacts')
          .select()
          .inFilter('id', contactIds);

      if (mounted) {
        setState(() {
          members =
              (contacts as List).map((json) => Contact.fromJson(json)).toList();
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.group.name} Members'),
      content: isLoading
          ? const SizedBox(
              width: 300,
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            )
          : SizedBox(
              width: 300,
              height: 300,
              child: members.isEmpty
                  ? const Center(child: Text('No members'))
                  : ListView.builder(
                      itemCount: members.length,
                      itemBuilder: (context, index) {
                        final member = members[index];
                        return ListTile(
                          title: Text(member.name),
                          subtitle: Text(member.phoneNumber),
                        );
                      },
                    ),
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
