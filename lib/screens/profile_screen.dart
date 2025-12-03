import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../models/user_profile.dart';

/// Profile Screen
/// 
/// Modern, attractive profile screen displaying user information, GST settings, and password change
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _gstNumberController = TextEditingController();
  final _gstRateController = TextEditingController();
  final _upiIdController = TextEditingController();

  bool _gstEnabled = false;
  bool _gstIncluded = false;
  bool _isLoadingPassword = false;
  bool _isLoadingGst = false;
  bool _fieldsInitialized = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _gstNumberController.dispose();
    _gstRateController.dispose();
    _upiIdController.dispose();
    super.dispose();
  }

  void _initializeFields(UserProfile profile) {
    _gstNumberController.text = profile.gstNumber ?? '';
    _gstEnabled = profile.gstEnabled ?? false;
    _gstRateController.text = profile.gstRate?.toString() ?? '5.00';
    _gstIncluded = profile.gstIncluded ?? false;
    _upiIdController.text = profile.upiId ?? '';
    _fieldsInitialized = true;
  }

  Future<void> _handleChangePassword() async {
    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passwords do not match'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_newPasswordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 6 characters'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoadingPassword = true;
    });

    try {
      final authService = ref.read(authServiceProvider);
      await authService.updatePassword(_newPasswordController.text);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update password: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPassword = false;
        });
      }
    }
  }

  Future<void> _handleSaveGst() async {
    if (_gstEnabled) {
      final gstRateNum = double.tryParse(_gstRateController.text);
      if (gstRateNum == null || gstRateNum < 0 || gstRateNum > 100) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('GST rate must be a number between 0 and 100'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() {
      _isLoadingGst = true;
    });

    try {
      final authService = ref.read(authServiceProvider);
      await authService.updateGstSettings(
        gstNumber: _gstNumberController.text,
        gstEnabled: _gstEnabled,
        gstRate: _gstEnabled ? double.parse(_gstRateController.text) : null,
        gstIncluded: _gstIncluded,
        upiId: _upiIdController.text,
      );

      ref.invalidate(userProfileProvider);
      _fieldsInitialized = false;

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('GST settings saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final errorMessage = e.toString();
        String displayMessage = 'Failed to save GST settings';
        
        if (errorMessage.contains('column') || errorMessage.contains('does not exist')) {
          displayMessage = 'Database migration not run. Please run supabase-gst-migration.sql in Supabase SQL editor';
        } else {
          displayMessage = errorMessage;
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(displayMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingGst = false;
        });
      }
    }
  }

  Future<void> _handleLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (shouldLogout == true) {
      final authService = ref.read(authServiceProvider);
      await authService.signOut();
      if (mounted) {
        context.go('/login');
      }
    }
  }

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
        return const Color(0xFFFF6B6B);
      case UserRole.branchAdmin:
        return const Color(0xFF4ECDC4);
      case UserRole.staff:
        return const Color(0xFF95E1D3);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FB),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(userProfileProvider);
          _fieldsInitialized = false;
        },
        child: userProfile.when(
          data: (profile) {
            if (profile == null) {
              return const Center(
                child: Text('User profile not found'),
              );
            }

            if (!_fieldsInitialized || 
                _gstNumberController.text != (profile.gstNumber ?? '') ||
                _gstEnabled != (profile.gstEnabled ?? false) ||
                _gstRateController.text != (profile.gstRate?.toString() ?? '5.00') ||
                _gstIncluded != (profile.gstIncluded ?? false) ||
                _upiIdController.text != (profile.upiId ?? '')) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _initializeFields(profile);
                  });
                }
              });
            }

            return CustomScrollView(
              slivers: [
                // Modern Gradient Header
                SliverAppBar(
                  expandedHeight: 200,
                  floating: false,
                  pinned: true,
                  elevation: 0,
                  backgroundColor: Colors.white,
                  automaticallyImplyLeading: false,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF0B63FF),
                            const Color(0xFF0052D4),
                          ],
                        ),
                      ),
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  // User Avatar
                                  Container(
                                    width: 80,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 4,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        profile.fullName
                                            .split(' ')
                                            .map((n) => n.isNotEmpty ? n[0] : '')
                                            .take(2)
                                            .join()
                                            .toUpperCase(),
                                        style: const TextStyle(
                                          color: Color(0xFF0B63FF),
                                          fontSize: 32,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          profile.fullName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(0.3),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            _formatRole(profile.role),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Content
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // User Information Card
                        _SectionCard(
                          icon: Icons.person_outline,
                          title: 'User Information',
                          child: Column(
                            children: [
                              _InfoRow(
                                icon: Icons.person,
                                label: 'Full Name',
                                value: profile.fullName,
                              ),
                              const Divider(height: 32),
                              _InfoRow(
                                icon: Icons.alternate_email,
                                label: 'Username',
                                value: profile.username,
                              ),
                              const Divider(height: 32),
                              _InfoRow(
                                icon: Icons.phone,
                                label: 'Phone',
                                value: profile.phone,
                              ),
                              const Divider(height: 32),
                              _InfoRow(
                                icon: Icons.badge,
                                label: 'Role',
                                value: _formatRole(profile.role),
                                valueColor: _getRoleColor(profile.role),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // GST Settings Card
                        _SectionCard(
                          icon: Icons.receipt_long,
                          title: 'GST Settings',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _ModernTextField(
                                controller: _gstNumberController,
                                label: 'GST Number',
                                hint: 'Enter GST number (e.g., 27AAAAA0000A1Z5)',
                                icon: Icons.numbers,
                                maxLength: 15,
                              ),
                              const SizedBox(height: 16),
                              _ModernTextField(
                                controller: _upiIdController,
                                label: 'UPI ID',
                                hint: 'yourname@paytm or yourname@upi',
                                icon: Icons.qr_code,
                                helperText: 'Enter your UPI ID for payment QR codes',
                              ),
                              const SizedBox(height: 24),
                              _ModernSwitch(
                                value: _gstEnabled,
                                onChanged: (value) {
                                  setState(() {
                                    _gstEnabled = value;
                                  });
                                },
                                title: 'Enable GST',
                                subtitle: _gstEnabled
                                    ? 'GST will be applied to all orders'
                                    : 'GST will not be applied to orders',
                                icon: Icons.toggle_on,
                              ),
                              if (_gstEnabled) ...[
                                const SizedBox(height: 24),
                                _ModernTextField(
                                  controller: _gstRateController,
                                  label: 'GST Rate (%)',
                                  hint: '5.00',
                                  icon: Icons.percent,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  helperText: 'Enter the GST percentage rate (e.g., 5.00 for 5%, 18.00 for 18%)',
                                ),
                                const SizedBox(height: 24),
                                const Text(
                                  'GST Calculation Method',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0F1724),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _ModernRadioOption(
                                  value: false,
                                  groupValue: _gstIncluded,
                                  onChanged: (value) {
                                    setState(() {
                                      _gstIncluded = false;
                                    });
                                  },
                                  title: 'GST Excluded',
                                  subtitle: 'GST (${_gstRateController.text}%) will be added on top of the order total',
                                  icon: Icons.add_circle_outline,
                                ),
                                const SizedBox(height: 12),
                                _ModernRadioOption(
                                  value: true,
                                  groupValue: _gstIncluded,
                                  onChanged: (value) {
                                    setState(() {
                                      _gstIncluded = true;
                                    });
                                  },
                                  title: 'GST Included',
                                  subtitle: 'GST (${_gstRateController.text}%) is already included in the item prices',
                                  icon: Icons.check_circle_outline,
                                ),
                              ],
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isLoadingGst ? null : _handleSaveGst,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0B63FF),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: _isLoadingGst
                                      ? const SizedBox(
                                          height: 24,
                                          width: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      : const Text(
                                          'Save GST Settings',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Change Password Card
                        _SectionCard(
                          icon: Icons.lock_outline,
                          title: 'Change Password',
                          child: Column(
                            children: [
                              _ModernTextField(
                                controller: _currentPasswordController,
                                label: 'Current Password',
                                icon: Icons.lock,
                                obscureText: true,
                              ),
                              const SizedBox(height: 16),
                              _ModernTextField(
                                controller: _newPasswordController,
                                label: 'New Password',
                                icon: Icons.lock_open,
                                obscureText: true,
                              ),
                              const SizedBox(height: 16),
                              _ModernTextField(
                                controller: _confirmPasswordController,
                                label: 'Confirm New Password',
                                icon: Icons.verified_user,
                                obscureText: true,
                              ),
                              const SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isLoadingPassword ? null : _handleChangePassword,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF0B63FF),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: _isLoadingPassword
                                      ? const SizedBox(
                                          height: 24,
                                          width: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      : const Text(
                                          'Update Password',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Branch Management Card (Super Admin only)
                        if (profile.canManageBranches)
                          _SectionCard(
                            icon: Icons.store_outlined,
                            title: 'Branch Management',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Manage all branches in the system',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () => context.push('/branches'),
                                    icon: const Icon(Icons.store),
                                    label: const Text('Manage Branches'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0B63FF),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (profile.canManageBranches) const SizedBox(height: 16),

                        // Staff Management Card (Super Admin & Branch Admin)
                        if (profile.canManageStaff)
                          _SectionCard(
                            icon: Icons.people_outline,
                            title: 'Staff Management',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  profile.isSuperAdmin
                                      ? 'Manage all staff members across all branches'
                                      : 'Manage staff members in your branch',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    onPressed: () => context.push('/staff'),
                                    icon: const Icon(Icons.people),
                                    label: const Text('Manage Staff'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0B63FF),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (profile.canManageStaff) const SizedBox(height: 16),

                        // Logout Button
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _handleLogout,
                            icon: const Icon(Icons.logout, color: Colors.red),
                            label: const Text(
                              'Logout',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.red,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: const BorderSide(color: Colors.red, width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (error, stack) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red.shade300,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading profile',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error.toString(),
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () {
                      ref.invalidate(userProfileProvider);
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0B63FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Modern Section Card Widget
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0B63FF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: const Color(0xFF0B63FF),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F1724),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}

/// Modern Info Row Widget
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            size: 20,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: valueColor ?? const Color(0xFF0F1724),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Modern Text Field Widget
class _ModernTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? helperText;
  final int? maxLength;

  const _ModernTextField({
    required this.controller,
    required this.label,
    this.hint,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.helperText,
    this.maxLength,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          maxLength: maxLength,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            prefixIcon: Icon(icon, color: const Color(0xFF0B63FF)),
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
              borderSide: const BorderSide(color: Color(0xFF0B63FF), width: 2),
            ),
            filled: true,
            fillColor: Colors.grey.shade50,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
          ),
        ),
        if (helperText != null) ...[
          const SizedBox(height: 4),
          Text(
            helperText!,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ],
    );
  }
}

/// Modern Switch Widget
class _ModernSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String title;
  final String subtitle;
  final IconData icon;

  const _ModernSwitch({
    required this.value,
    required this.onChanged,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: value ? const Color(0xFF0B63FF).withOpacity(0.1) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value ? const Color(0xFF0B63FF) : Colors.grey.shade300,
          width: value ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: value ? const Color(0xFF0B63FF) : Colors.grey.shade600,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: value ? const Color(0xFF0F1724) : Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF0B63FF),
          ),
        ],
      ),
    );
  }
}

/// Modern Radio Option Widget
class _ModernRadioOption extends StatelessWidget {
  final bool value;
  final bool groupValue;
  final ValueChanged<bool?> onChanged;
  final String title;
  final String subtitle;
  final IconData icon;

  const _ModernRadioOption({
    required this.value,
    required this.groupValue,
    required this.onChanged,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = groupValue == value;
    
    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0B63FF).withOpacity(0.1) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF0B63FF) : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? const Color(0xFF0B63FF) : Colors.grey.shade600,
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? const Color(0xFF0F1724) : Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Radio<bool>(
              value: value,
              groupValue: groupValue,
              onChanged: onChanged,
              activeColor: const Color(0xFF0B63FF),
            ),
          ],
        ),
      ),
    );
  }
}
