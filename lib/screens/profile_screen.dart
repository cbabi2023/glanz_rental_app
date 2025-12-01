import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../models/user_profile.dart';

/// Profile Screen
/// 
/// Displays user profile information, GST settings, and password change
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
    // Always initialize from profile data (like useEffect in web app)
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
    // Validate GST rate
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

      // Invalidate user profile to refresh
      ref.invalidate(userProfileProvider);
      
      // Reset initialization flag so fields get updated on next build
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
        
        // Check if it's a database column error (similar to web app)
        if (errorMessage.contains('column') || errorMessage.contains('does not exist')) {
          displayMessage = 'Database migration not run. Please run supabase-gst-migration.sql in Supabase SQL editor';
        } else {
          displayMessage = errorMessage;
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(displayMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5), // Longer duration for migration error
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
    final authService = ref.read(authServiceProvider);
    await authService.signOut();
    if (mounted) {
      context.go('/login');
    }
  }

  String _formatRole(UserRole role) {
    switch (role) {
      case UserRole.superAdmin:
        return 'SUPER ADMIN';
      case UserRole.branchAdmin:
        return 'BRANCH ADMIN';
      case UserRole.staff:
        return 'STAFF';
    }
  }

  @override
  Widget build(BuildContext context) {
    final userProfile = ref.watch(userProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        automaticallyImplyLeading: false, // Remove back button since it's in bottom nav
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(userProfileProvider);
          _fieldsInitialized = false; // Reset so fields re-initialize after refresh
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 80), // Extra bottom padding for bottom nav
          child: userProfile.when(
            data: (profile) {
              if (profile == null) {
                return const Center(
                  child: Text('User profile not found'),
                );
              }

              // Initialize fields from profile (similar to useEffect in web app)
              // This ensures fields are always synced with profile data
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

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // User Information Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'User Information',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildInfoRow('Full Name', profile.fullName),
                          const SizedBox(height: 12),
                          _buildInfoRow('Username', profile.username),
                          const SizedBox(height: 12),
                          _buildInfoRow('Phone', profile.phone),
                          const SizedBox(height: 12),
                          _buildInfoRow('Role', _formatRole(profile.role)),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // GST Settings Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'GST Settings',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // GST Number
                          TextField(
                            controller: _gstNumberController,
                            decoration: const InputDecoration(
                              labelText: 'GST Number (Optional)',
                              hintText: 'Enter GST number (e.g., 27AAAAA0000A1Z5)',
                              border: OutlineInputBorder(),
                            ),
                            maxLength: 15,
                          ),
                          const SizedBox(height: 16),

                          // UPI ID
                          TextField(
                            controller: _upiIdController,
                            decoration: const InputDecoration(
                              labelText: 'UPI ID (Optional)',
                              hintText: 'yourname@paytm or yourname@upi',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Enter your UPI ID for payment QR codes',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Enable GST Toggle
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Enable GST'),
                              Switch(
                                value: _gstEnabled,
                                onChanged: (value) {
                                  setState(() {
                                    _gstEnabled = value;
                                  });
                                },
                              ),
                            ],
                          ),
                          Text(
                            _gstEnabled
                                ? 'GST will be applied to all orders'
                                : 'GST will not be applied to orders',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),

                          // GST Rate (only when enabled)
                          if (_gstEnabled) ...[
                            const SizedBox(height: 16),
                            TextField(
                              controller: _gstRateController,
                              decoration: const InputDecoration(
                                labelText: 'GST Rate (%)',
                                hintText: '5.00',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Enter the GST percentage rate (e.g., 5.00 for 5%, 18.00 for 18%)',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],

                          // GST Calculation Method (only when enabled)
                          if (_gstEnabled) ...[
                            const SizedBox(height: 16),
                            const Text(
                              'GST Calculation Method',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            RadioListTile<bool>(
                              title: const Text('GST Excluded'),
                              subtitle: Text(
                                'GST (${_gstRateController.text}%) will be added on top of the order total',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                              value: false,
                              groupValue: _gstIncluded,
                              onChanged: (value) {
                                setState(() {
                                  _gstIncluded = false;
                                });
                              },
                            ),
                            RadioListTile<bool>(
                              title: const Text('GST Included'),
                              subtitle: Text(
                                'GST (${_gstRateController.text}%) is already included in the item prices',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                              value: true,
                              groupValue: _gstIncluded,
                              onChanged: (value) {
                                setState(() {
                                  _gstIncluded = true;
                                });
                              },
                            ),
                          ],

                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoadingGst ? null : _handleSaveGst,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0B63FF),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: _isLoadingGst
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Text('Save GST Settings'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Change Password Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Change Password',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _currentPasswordController,
                            decoration: const InputDecoration(
                              labelText: 'Current Password',
                              border: OutlineInputBorder(),
                            ),
                            obscureText: true,
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _newPasswordController,
                            decoration: const InputDecoration(
                              labelText: 'New Password',
                              border: OutlineInputBorder(),
                            ),
                            obscureText: true,
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _confirmPasswordController,
                            decoration: const InputDecoration(
                              labelText: 'Confirm New Password',
                              border: OutlineInputBorder(),
                            ),
                            obscureText: true,
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isLoadingPassword ? null : _handleChangePassword,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0B63FF),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: _isLoadingPassword
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : const Text('Update Password'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Logout Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _handleLogout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Logout'),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(),
            ),
            error: (error, stack) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error loading profile: ${error.toString()}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      ref.invalidate(userProfileProvider);
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Column(
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          width: double.infinity,
          child: Text(
            value,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }
}

