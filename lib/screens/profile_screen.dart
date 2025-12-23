import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _phoneController = TextEditingController();

  String? userEmail;
  String? userId;
  DateTime? createdAt;
  bool isLoading = true;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _loadUserProfile() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() => isLoading = false);
        return;
      }

      setState(() {
        userEmail = user.email;
        userId = user.id;
        createdAt = DateTime.parse(user.createdAt);
      });

      // Try to load additional profile data from sms_gateway.users
      try {
        final profile = await Supabase.instance.client
            .schema('sms_gateway')
            .from('users')
            .select('display_name, phone_number')
            .eq('id', user.id)
            .maybeSingle();

        if (profile != null) {
          _displayNameController.text = profile['display_name'] ?? '';
          _phoneController.text = profile['phone_number'] ?? '';
        }
      } catch (e) {
        debugPrint('Profile data not found or error: $e');
      }

      setState(() => isLoading = false);
    } catch (e) {
      debugPrint('Error loading profile: $e');
      setState(() => isLoading = false);
    }
  }

  void _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isSaving = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw 'User not logged in';

      // Update profile in sms_gateway.users
      await Supabase.instance.client
          .schema('sms_gateway')
          .from('users')
          .update({
        'display_name': _displayNameController.text.trim(),
        'phone_number': _phoneController.text.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  void _changePassword() {
    showDialog(
      context: context,
      builder: (context) => _ChangePasswordDialog(),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppTheme.paddingLarge),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Avatar
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor:
                                AppTheme.primaryColor.withAlpha(50),
                            child: Text(
                              (userEmail?.isNotEmpty == true)
                                  ? userEmail![0].toUpperCase()
                                  : 'U',
                              style: const TextStyle(
                                fontSize: 40,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.paddingLarge),

                    // Email (Read-only)
                    Text(
                      'Email',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    const SizedBox(height: AppTheme.paddingSmall),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppTheme.paddingMedium),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMedium),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.email, color: Colors.grey),
                          const SizedBox(width: AppTheme.paddingMedium),
                          Expanded(
                            child: Text(
                              userEmail ?? 'N/A',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                          const Icon(Icons.lock, color: Colors.grey, size: 16),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppTheme.paddingSmall),
                    Text(
                      'Email cannot be changed',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                    ),
                    const SizedBox(height: AppTheme.paddingLarge),

                    // Display Name (Editable)
                    Text(
                      'Display Name',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    const SizedBox(height: AppTheme.paddingSmall),
                    TextFormField(
                      controller: _displayNameController,
                      decoration: const InputDecoration(
                        hintText: 'Enter your display name',
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (value != null && value.length > 50) {
                          return 'Name must be less than 50 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppTheme.paddingLarge),

                    // Phone Number (Editable)
                    Text(
                      'Phone Number',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                    const SizedBox(height: AppTheme.paddingSmall),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        hintText: 'Enter your phone number',
                        prefixIcon: Icon(Icons.phone),
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: AppTheme.paddingLarge),

                    // Account Info Section
                    const Divider(),
                    const SizedBox(height: AppTheme.paddingMedium),
                    Text(
                      'Account Information',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: AppTheme.paddingMedium),

                    // User ID
                    _buildInfoRow(
                      context,
                      icon: Icons.fingerprint,
                      label: 'User ID',
                      value: userId ?? 'N/A',
                      isSmall: true,
                    ),
                    const SizedBox(height: AppTheme.paddingSmall),

                    // Member Since
                    _buildInfoRow(
                      context,
                      icon: Icons.calendar_today,
                      label: 'Member Since',
                      value: _formatDate(createdAt),
                    ),
                    const SizedBox(height: AppTheme.paddingLarge),

                    // Save Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: isSaving ? null : _saveProfile,
                        icon: isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: Text(isSaving ? 'Saving...' : 'Save Changes'),
                      ),
                    ),
                    const SizedBox(height: AppTheme.paddingMedium),

                    // Change Password Button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _changePassword,
                        icon: const Icon(Icons.lock_reset),
                        label: const Text('Change Password'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    bool isSmall = false,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: AppTheme.paddingMedium),
        Text(
          '$label: ',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: isSmall ? 11 : null,
                ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Dialog for changing password
class _ChangePasswordDialog extends StatefulWidget {
  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool isLoading = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _newPasswordController.text),
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password changed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
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
      title: const Text('Change Password'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _newPasswordController,
              obscureText: _obscureNew,
              decoration: InputDecoration(
                labelText: 'New Password',
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(
                      _obscureNew ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscureNew = !_obscureNew),
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a new password';
                }
                if (value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirm,
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirm
                      ? Icons.visibility
                      : Icons.visibility_off),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              validator: (value) {
                if (value != _newPasswordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: isLoading ? null : _submit,
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Change'),
        ),
      ],
    );
  }
}
