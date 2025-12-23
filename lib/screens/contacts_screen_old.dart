import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../core/theme.dart';
import '../contacts/contact_model.dart';
import '../groups/group_model.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Contact> contacts = [];
  List<Group> groups = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
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
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('❌ No user logged in');
        return;
      }

      debugPrint('📱 Loading contacts for user: $userId');

      final response = await Supabase.instance.client
          .schema('sms_gateway')
          .from('contacts')
          .select()
          .eq('user_id', userId);

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
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final response = await Supabase.instance.client
          .schema('sms_gateway')
          .from('groups')
          .select('*, group_members(id)')
          .eq('user_id', userId);

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contact deleted')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts & Groups'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.contacts), text: 'Contacts'),
            Tab(icon: Icon(Icons.group), text: 'Groups'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildContactsTab(),
          _buildGroupsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_tabController.index == 0) {
            _addContact();
          } else {
            _createGroup();
          }
        },
        child: const Icon(Icons.add),
      ),
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
            const Icon(Icons.contacts_outlined,
                size: 64, color: Colors.grey),
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
                )
              : ListView.builder(
                  itemCount: contacts.length,
                  itemBuilder: (context, index) {
                    final contact = contacts[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: AppTheme.paddingMedium,
                        vertical: AppTheme.paddingSmall,
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(contact.name[0].toUpperCase()),
                        ),
                        title: Text(contact.name),
                        subtitle: Text(contact.phoneNumber),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _deleteContact(contact.id),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addContact,
        child: const Icon(Icons.add),
      ),
    );
  }
}

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

  void _save() async {
    if (nameController.text.isEmpty || phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw 'User not found';

      // Get tenant_id from sms_gateway.users
      final userProfile = await Supabase.instance.client
          .schema('sms_gateway')
          .from('users')
          .select('tenant_id')
          .eq('id', userId)
          .single();

      final tenantId = userProfile['tenant_id'] as String;

      final contact = Contact(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: userId,
        tenantId: tenantId,
        name: nameController.text,
        phoneNumber: phoneController.text,
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
              hintText: 'e.g., John Doe',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: phoneController,
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              hintText: 'e.g., +1234567890',
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
              : const Text('Add'),
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
