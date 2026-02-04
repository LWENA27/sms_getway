import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/marketing_campaign.dart';
import '../../contacts/contact_model.dart';
import '../../core/tenant_service.dart';

/// Campaign Create/Edit Screen
/// Create new marketing campaign or edit existing one
class CampaignCreateScreen extends StatefulWidget {
  final MarketingCampaign? campaign;

  const CampaignCreateScreen({super.key, this.campaign});

  @override
  State<CampaignCreateScreen> createState() => _CampaignCreateScreenState();
}

class _CampaignCreateScreenState extends State<CampaignCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _supabase = Supabase.instance.client;
  final _tenantService = TenantService();

  final _nameController = TextEditingController();
  final _messageController = TextEditingController();

  List<Contact> _availableContacts = [];
  Set<String> _selectedContactIds = {};
  bool _loading = false;
  bool _loadingContacts = false;

  bool get _isEditing => widget.campaign != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _nameController.text = widget.campaign!.name;
      _messageController.text = widget.campaign!.messageTemplate;
    }
    _loadContacts();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    setState(() => _loadingContacts = true);

    try {
      await _tenantService.initialize();
      final tenantId = _tenantService.currentTenant?.id;
      if (tenantId == null) throw Exception('No tenant selected');

      final response = await _supabase
          .schema('sms_gateway')
          .from('contacts')
          .select()
          .eq('tenant_id', tenantId)
          .order('name');

      final contacts =
          (response as List).map((json) => Contact.fromJson(json)).toList();

      setState(() {
        _availableContacts = contacts;
        _loadingContacts = false;
      });
    } catch (e) {
      setState(() => _loadingContacts = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading contacts: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _renderPreview() {
    String message = _messageController.text;

    // Use first selected contact for preview, or sample data
    Contact? sampleContact;
    if (_selectedContactIds.isNotEmpty) {
      sampleContact = _availableContacts.firstWhere(
        (c) => _selectedContactIds.contains(c.id),
        orElse: () => _availableContacts.first,
      );
    }

    final firstName = sampleContact?.firstName ?? 'John';
    final lastName = sampleContact?.lastName ?? 'Doe';
    final phone = sampleContact?.phoneNumber ?? '+255712345678';

    message = message.replaceAll('{first_name}', firstName);
    message = message.replaceAll('{last_name}', lastName);
    message = message.replaceAll('{phone}', phone);

    return message;
  }

  Future<void> _saveCampaign({bool activate = false}) async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedContactIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one contact'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      await _tenantService.initialize();
      final tenantId = _tenantService.currentTenant?.id;
      if (tenantId == null) throw Exception('No tenant selected');

      final userId = _supabase.auth.currentUser?.id;

      String campaignId;

      if (_isEditing) {
        // Update existing campaign
        await _supabase
            .schema('sms_gateway')
            .from('marketing_campaigns')
            .update({
          'name': _nameController.text.trim(),
          'message_template': _messageController.text.trim(),
          if (activate) ...{
            'status': 'active',
            'activated_at': DateTime.now().toIso8601String(),
          },
        }).eq('id', widget.campaign!.id);

        campaignId = widget.campaign!.id;
      } else {
        // Create new campaign
        final response = await _supabase
            .schema('sms_gateway')
            .from('marketing_campaigns')
            .insert({
              'tenant_id': tenantId,
              'name': _nameController.text.trim(),
              'message_template': _messageController.text.trim(),
              'status': activate ? 'active' : 'draft',
              'total_contact_count': _selectedContactIds.length,
              'created_by': userId,
              if (activate) 'activated_at': DateTime.now().toIso8601String(),
            })
            .select()
            .single();

        campaignId = response['id'] as String;

        // Add selected contacts to campaign
        final contactsToAdd = _availableContacts
            .where((c) => _selectedContactIds.contains(c.id))
            .map((c) => {
                  'campaign_id': campaignId,
                  'contact_id': c.id,
                  'phone_number': c.phoneNumber,
                  'first_name': c.firstName,
                  'last_name': c.lastName,
                  'status': 'pending',
                })
            .toList();

        if (contactsToAdd.isNotEmpty) {
          await _supabase
              .schema('sms_gateway')
              .from('marketing_campaign_contacts')
              .insert(contactsToAdd);
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              activate
                  ? '✅ Campaign activated!'
                  : _isEditing
                      ? '✅ Campaign updated'
                      : '✅ Campaign created',
            ),
          ),
        );
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Campaign' : 'New Campaign'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Campaign Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Campaign Name',
                hintText: 'e.g., Spring Sale 2026',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.campaign),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a campaign name';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Message Template
            Text(
              'Message Template',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: 'Hi {first_name}, check out our new offers!',
                border: OutlineInputBorder(),
                helperText:
                    'Use {first_name}, {last_name}, {phone} for personalization',
              ),
              maxLines: 4,
              maxLength: 160,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a message';
                }
                return null;
              },
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // Preview Card
            if (_messageController.text.isNotEmpty) ...[
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.preview, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            'Preview',
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(_renderPreview()),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Contact Selection
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Contacts',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      if (_selectedContactIds.length ==
                          _availableContacts.length) {
                        _selectedContactIds.clear();
                      } else {
                        _selectedContactIds =
                            _availableContacts.map((c) => c.id).toSet();
                      }
                    });
                  },
                  icon: Icon(
                    _selectedContactIds.length == _availableContacts.length
                        ? Icons.deselect
                        : Icons.select_all,
                    size: 18,
                  ),
                  label: Text(
                    _selectedContactIds.length == _availableContacts.length
                        ? 'Deselect All'
                        : 'Select All',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (_loadingContacts)
              const Center(child: CircularProgressIndicator())
            else if (_availableContacts.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Icon(Icons.contacts_outlined, size: 48),
                      const SizedBox(height: 8),
                      const Text('No contacts available'),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          // Navigate to contacts screen
                        },
                        child: const Text('Add Contacts'),
                      ),
                    ],
                  ),
                ),
              )
            else
              Card(
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(Icons.group, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            '${_selectedContactIds.length} of ${_availableContacts.length} selected',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _availableContacts.length,
                        itemBuilder: (context, index) {
                          final contact = _availableContacts[index];
                          final isSelected =
                              _selectedContactIds.contains(contact.id);

                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: (selected) {
                              setState(() {
                                if (selected == true) {
                                  _selectedContactIds.add(contact.id);
                                } else {
                                  _selectedContactIds.remove(contact.id);
                                }
                              });
                            },
                            title: Text(contact.fullName),
                            subtitle: Text(contact.phoneNumber),
                            secondary: CircleAvatar(
                              child: Text(
                                contact.firstName
                                        ?.substring(0, 1)
                                        .toUpperCase() ??
                                    contact.name.substring(0, 1).toUpperCase(),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _loading ? null : () => _saveCampaign(activate: false),
                    child: _loading
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save as Draft'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        _loading ? null : () => _saveCampaign(activate: true),
                    child: _loading
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save & Activate'),
                  ),
                ),
              ],
            ),

            // Warning Card
            const SizedBox(height: 16),
            Card(
              color: Colors.orange.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Daily limit: 100 SMS/day. Each contact receives max 2 SMS per 30 days.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade900,
                        ),
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
}
