import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/staff_provider.dart';
import '../../providers/branches_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_profile.dart';
import '../../models/branch.dart';

/// Staff List Screen
///
/// Manage staff members (Super Admin & Branch Admin only)
class StaffListScreen extends ConsumerStatefulWidget {
  const StaffListScreen({super.key});

  @override
  ConsumerState<StaffListScreen> createState() => _StaffListScreenState();
}

class _StaffListScreenState extends ConsumerState<StaffListScreen> {
  final _searchController = TextEditingController();
  String? _searchQuery;
  String? _roleFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<UserProfile> _filterStaff(List<UserProfile> staff) {
    var filtered = staff;

    // Apply role filter
    if (_roleFilter != null) {
      filtered = filtered.where((s) => s.role.value == _roleFilter).toList();
    }

    // Apply search filter
    if (_searchQuery != null && _searchQuery!.isNotEmpty) {
      final query = _searchQuery!.toLowerCase();
      filtered = filtered.where((s) {
        return s.fullName.toLowerCase().contains(query) ||
            s.username.toLowerCase().contains(query) ||
            s.phone.toLowerCase().contains(query);
      }).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = ref.watch(userProfileProvider);
    final branchId = userProfile.value?.branchId;
    final isSuperAdmin = userProfile.value?.isSuperAdmin ?? false;

    // Fetch staff - filter by branch if branch admin
    final staffAsync = ref.watch(staffProvider(isSuperAdmin ? null : branchId));
    final branchesAsync = ref.watch(branchesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF0F1724)),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Staff Management',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F1724),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.add_circle_outline,
              color: Color(0xFF0B63FF),
            ),
            onPressed: () => _showCreateStaffDialog(context, branchesAsync),
            tooltip: 'Add Staff',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(staffProvider(isSuperAdmin ? null : branchId));
        },
        child: staffAsync.when(
          data: (staff) {
            final filteredStaff = _filterStaff(staff);

            if (filteredStaff.isEmpty &&
                _searchQuery == null &&
                _roleFilter == null) {
              return _EmptyState(
                onAddStaff: () =>
                    _showCreateStaffDialog(context, branchesAsync),
              );
            }

            return Column(
              children: [
                // Search Bar
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search staff...',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      suffixIcon:
                          _searchQuery != null && _searchQuery!.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _searchQuery = null;
                                  _searchController.clear();
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF0B63FF),
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.isEmpty ? null : value;
                      });
                    },
                  ),
                ),
                // Role Filter Chips
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'All',
                          selected: _roleFilter == null,
                          onTap: () {
                            setState(() {
                              _roleFilter = null;
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Super Admin',
                          selected: _roleFilter == 'super_admin',
                          onTap: () {
                            setState(() {
                              _roleFilter = 'super_admin';
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Branch Admin',
                          selected: _roleFilter == 'branch_admin',
                          onTap: () {
                            setState(() {
                              _roleFilter = 'branch_admin';
                            });
                          },
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Staff',
                          selected: _roleFilter == 'staff',
                          onTap: () {
                            setState(() {
                              _roleFilter = 'staff';
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredStaff.length,
                    itemBuilder: (context, index) {
                      final staffMember = filteredStaff[index];
                      return _StaffCard(
                        staff: staffMember,
                        onEdit: () => _showEditStaffDialog(
                          context,
                          staffMember,
                          branchesAsync,
                        ),
                        onDelete: () =>
                            _showDeleteStaffDialog(context, staffMember),
                      );
                    },
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading staff',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error.toString(),
                    style: TextStyle(color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      ref.invalidate(
                        staffProvider(isSuperAdmin ? null : branchId),
                      );
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateStaffDialog(context, branchesAsync),
        backgroundColor: const Color(0xFF0B63FF),
        icon: const Icon(Icons.person_add),
        label: const Text('Add Staff'),
      ),
    );
  }

  Future<void> _showCreateStaffDialog(
    BuildContext context,
    AsyncValue<List<Branch>> branchesAsync,
  ) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _StaffFormDialog(branchesAsync: branchesAsync),
    );

    if (result != null && mounted) {
      try {
        final service = ref.read(staffServiceProvider);
        await service.createStaff(
          email: result['email'] as String,
          password: result['password'] as String,
          username: result['username'] as String,
          fullName: result['fullName'] as String,
          phone: result['phone'] as String,
          role: result['role'] as UserRole,
          branchId: result['branchId'] as String?,
        );

        final userProfile = ref.read(userProfileProvider);
        final branchId = userProfile.value?.branchId;
        final isSuperAdmin = userProfile.value?.isSuperAdmin ?? false;

        ref.invalidate(staffProvider(isSuperAdmin ? null : branchId));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Staff member created successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to create staff: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _showEditStaffDialog(
    BuildContext context,
    UserProfile staff,
    AsyncValue<List<Branch>> branchesAsync,
  ) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) =>
          _StaffFormDialog(staff: staff, branchesAsync: branchesAsync),
    );

    if (result != null && mounted) {
      try {
        final service = ref.read(staffServiceProvider);
        await service.updateStaff(
          staffId: staff.id,
          username: result['username'] as String,
          fullName: result['fullName'] as String,
          phone: result['phone'] as String,
          role: result['role'] as UserRole?,
          branchId: result['branchId'] as String?,
        );

        final userProfile = ref.read(userProfileProvider);
        final branchId = userProfile.value?.branchId;
        final isSuperAdmin = userProfile.value?.isSuperAdmin ?? false;

        ref.invalidate(staffProvider(isSuperAdmin ? null : branchId));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Staff member updated successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update staff: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _showDeleteStaffDialog(
    BuildContext context,
    UserProfile staff,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Staff'),
        content: Text(
          'Are you sure you want to delete "${staff.fullName}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final service = ref.read(staffServiceProvider);
        await service.deleteStaff(staff.id);

        final userProfile = ref.read(userProfileProvider);
        final branchId = userProfile.value?.branchId;
        final isSuperAdmin = userProfile.value?.isSuperAdmin ?? false;

        ref.invalidate(staffProvider(isSuperAdmin ? null : branchId));

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Staff member deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete staff: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

/// Staff Card Widget
class _StaffCard extends StatelessWidget {
  final UserProfile staff;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _StaffCard({
    required this.staff,
    required this.onEdit,
    required this.onDelete,
  });

  String _formatRole(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return 'Super Admin';
      case UserRole.branchAdmin:
        return 'Branch Admin';
      case UserRole.staff:
        return 'Staff';
    }
  }

  Color _getRoleColor(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return Colors.red;
      case UserRole.branchAdmin:
        return Colors.blue;
      case UserRole.staff:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    final roleColor = _getRoleColor(staff.role);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: roleColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.person, color: roleColor, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        staff.fullName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F1724),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: roleColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _formatRole(staff.role),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: roleColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      onEdit();
                    } else if (value == 'delete') {
                      onDelete();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 20, color: Color(0xFF0B63FF)),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.alternate_email,
                  size: 16,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 8),
                Text(
                  staff.username,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.phone, size: 16, color: Colors.grey.shade600),
                const SizedBox(width: 8),
                Text(
                  staff.phone,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Filter Chip Widget
class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF0B63FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFF0B63FF) : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}

/// Staff Form Dialog
class _StaffFormDialog extends ConsumerStatefulWidget {
  final UserProfile? staff;
  final AsyncValue<List<Branch>> branchesAsync;

  const _StaffFormDialog({this.staff, required this.branchesAsync});

  @override
  ConsumerState<_StaffFormDialog> createState() => _StaffFormDialogState();
}

class _StaffFormDialogState extends ConsumerState<_StaffFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();

  UserRole _selectedRole = UserRole.staff;
  String? _selectedBranchId;

  @override
  void initState() {
    super.initState();
    if (widget.staff != null) {
      _usernameController.text = widget.staff!.username;
      _fullNameController.text = widget.staff!.fullName;
      _phoneController.text = widget.staff!.phone;
      _selectedRole = widget.staff!.role;
      _selectedBranchId = widget.staff!.branchId;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = ref.watch(userProfileProvider);
    final isSuperAdmin = userProfile.value?.isSuperAdmin ?? false;
    final userBranchId = userProfile.value?.branchId;

    return AlertDialog(
      title: Text(widget.staff == null ? 'Create Staff' : 'Edit Staff'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (widget.staff == null) ...[
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email *',
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Email is required';
                      }
                      if (!value.contains('@')) {
                        return 'Invalid email format';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Password *',
                      prefixIcon: Icon(Icons.lock),
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Password is required';
                      }
                      if (value.length < 6) {
                        return 'Password must be at least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username *',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Username is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name *',
                    prefixIcon: Icon(Icons.badge),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Full name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Phone *',
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Phone is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                if (isSuperAdmin) ...[
                  DropdownButtonFormField<UserRole>(
                    initialValue: _selectedRole,
                    decoration: const InputDecoration(
                      labelText: 'Role *',
                      prefixIcon: Icon(Icons.security),
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      if (isSuperAdmin)
                        const DropdownMenuItem(
                          value: UserRole.superAdmin,
                          child: Text('Super Admin'),
                        ),
                      const DropdownMenuItem(
                        value: UserRole.branchAdmin,
                        child: Text('Branch Admin'),
                      ),
                      const DropdownMenuItem(
                        value: UserRole.staff,
                        child: Text('Staff'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedRole = value;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                ],
                widget.branchesAsync.when(
                  data: (branches) {
                    return DropdownButtonFormField<String>(
                      initialValue: _selectedBranchId,
                      decoration: const InputDecoration(
                        labelText: 'Branch',
                        prefixIcon: Icon(Icons.store),
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('No Branch'),
                        ),
                        ...branches.map((branch) {
                          return DropdownMenuItem<String>(
                            value: branch.id,
                            child: Text(branch.name),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedBranchId = value;
                        });
                      },
                    );
                  },
                  loading: () => const CircularProgressIndicator(),
                  error: (_, __) => const Text('Error loading branches'),
                ),
                if (!isSuperAdmin && userBranchId != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Staff will be assigned to your branch',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate()) {
              Navigator.pop(context, {
                'email': _emailController.text.trim(),
                'password': _passwordController.text,
                'username': _usernameController.text.trim(),
                'fullName': _fullNameController.text.trim(),
                'phone': _phoneController.text.trim(),
                'role': _selectedRole,
                'branchId': isSuperAdmin ? _selectedBranchId : userBranchId,
              });
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0B63FF),
            foregroundColor: Colors.white,
          ),
          child: Text(widget.staff == null ? 'Create' : 'Update'),
        ),
      ],
    );
  }
}

/// Empty State Widget
class _EmptyState extends StatelessWidget {
  final VoidCallback onAddStaff;

  const _EmptyState({required this.onAddStaff});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.people_outlined,
                size: 64,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No staff members yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first staff member to get started',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onAddStaff,
              icon: const Icon(Icons.person_add),
              label: const Text('Add Staff'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0B63FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
