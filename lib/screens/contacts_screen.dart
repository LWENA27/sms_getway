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
      );
    }
    
    return ListView.builder(
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
            const Icon(Icons.group_outlined,
                size: 64, color: Colors.grey),
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
        id: const Uuid().v4(),
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
              hintText: 'John Doe',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: phoneController,
            decoration: const InputDecoration(
              labelText: 'Phone Number',
              hintText: '+1234567890',
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
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final response = await Supabase.instance.client
          .schema('sms_gateway')
          .from('contacts')
          .select()
          .eq('user_id', userId);

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
      if (userId == null) throw 'User not found';

      // Get tenant_id from sms_gateway.users
      final userProfile = await Supabase.instance.client
          .schema('sms_gateway')
          .from('users')
          .select('tenant_id')
          .eq('id', userId)
          .single();

      final tenantId = userProfile['tenant_id'] as String;
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
