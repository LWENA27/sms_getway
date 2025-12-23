import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../core/theme.dart';
import '../groups/group_model.dart';
import '../contacts/contact_model.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  List<Group> groups = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadGroups();
  }

  void _loadGroups() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final response = await Supabase.instance.client
          .schema('sms_gateway')
          .from('groups')
          .select()
          .eq('user_id', userId);

      if (mounted) {
        setState(() {
          groups =
              (response as List).map((json) => Group.fromJson(json)).toList();
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading groups: $e')),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups'),
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : groups.isEmpty
              ? Center(
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
                )
              : ListView.builder(
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
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createGroup,
        child: const Icon(Icons.add),
      ),
    );
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
}

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
