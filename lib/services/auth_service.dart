import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_client.dart';
import '../core/logger.dart';
import '../models/user_profile.dart';

/// Authentication Service
/// 
/// Handles user authentication and profile management
class AuthService {
  final _supabase = SupabaseService.client;

  /// Sign in with email and password
  Future<User?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    // Normalize email: trim and lowercase
    final normalizedEmail = email.trim().toLowerCase();
    // Trim password to remove any accidental whitespace
    final normalizedPassword = password.trim();
    
    // Validate inputs
    if (normalizedEmail.isEmpty) {
      throw Exception('Email cannot be empty');
    }
    if (normalizedPassword.isEmpty) {
      throw Exception('Password cannot be empty');
    }
    
    try {
    final response = await _supabase.auth.signInWithPassword(
        email: normalizedEmail,
        password: normalizedPassword,
    );
    return response.user;
    } on AuthException {
      // Re-throw auth exceptions as-is (they contain proper error messages)
      rethrow;
    } catch (e) {
      // Wrap unexpected errors
      throw Exception('Login failed: ${e.toString()}');
    }
  }

  /// Sign out current user
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  /// Get current authenticated user
  User? get currentUser => _supabase.auth.currentUser;

  /// Stream of authentication state changes
  Stream<AuthState> get authStateChanges => _supabase.auth.onAuthStateChange;

  /// Check if user is authenticated
  bool get isAuthenticated => currentUser != null;

  /// Get user profile from profiles table
  Future<UserProfile?> getUserProfile() async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();

      return UserProfile.fromJson(response);
    } catch (e) {
      AppLogger.error('Error fetching user profile', e);
      return null;
    }
  }

  /// Get user profile with branch information
  Future<UserProfile?> getUserProfileWithBranch() async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final response = await _supabase
          .from('profiles')
          .select('*, branch:branches(*)')
          .eq('id', user.id)
          .single();

      final profile = UserProfile.fromJson(response);
      return profile;
    } catch (e) {
      AppLogger.error('Error fetching user profile with branch', e);
      return null;
    }
  }

  /// Update user password
  Future<void> updatePassword(String newPassword) async {
    await _supabase.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  /// Update GST settings
  Future<UserProfile> updateGstSettings({
    String? gstNumber,
    required bool gstEnabled,
    double? gstRate,
    required bool gstIncluded,
    String? upiId,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    try {
      final updateData = <String, dynamic>{
        'gst_enabled': gstEnabled,
        'gst_included': gstIncluded,
      };

      if (gstNumber != null && gstNumber.trim().isNotEmpty) {
        updateData['gst_number'] = gstNumber.trim();
      } else {
        updateData['gst_number'] = null;
      }

      if (gstEnabled && gstRate != null) {
        updateData['gst_rate'] = gstRate;
      } else {
        updateData['gst_rate'] = null;
      }

      if (upiId != null && upiId.trim().isNotEmpty) {
        updateData['upi_id'] = upiId.trim();
      } else {
        updateData['upi_id'] = null;
      }

      await _supabase
          .from('profiles')
          .update(updateData)
          .eq('id', user.id);

      // Return updated profile
      final updatedProfile = await getUserProfile();
      if (updatedProfile == null) {
        throw Exception('Failed to retrieve updated profile');
      }
      return updatedProfile;
    } catch (e) {
      AppLogger.error('Error updating GST settings', e);
      rethrow;
    }
  }

  /// Update user branch
  Future<UserProfile> updateBranch(String? branchId) async {
    final user = currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    try {
      await _supabase
          .from('profiles')
          .update({'branch_id': branchId})
          .eq('id', user.id);

      // Return updated profile
      final updatedProfile = await getUserProfile();
      if (updatedProfile == null) {
        throw Exception('Failed to retrieve updated profile');
      }
      return updatedProfile;
    } catch (e) {
      AppLogger.error('Error updating branch', e);
      rethrow;
    }
  }

  /// Update company details
  Future<UserProfile> updateCompanyDetails({
    String? companyName,
    String? companyAddress,
    String? companyLogoUrl,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    try {
      final updateData = <String, dynamic>{};

      if (companyName != null) {
        updateData['company_name'] = companyName.trim().isEmpty ? null : companyName.trim();
      }

      if (companyAddress != null) {
        updateData['company_address'] = companyAddress.trim().isEmpty ? null : companyAddress.trim();
      }

      if (companyLogoUrl != null) {
        updateData['company_logo_url'] = companyLogoUrl.trim().isEmpty ? null : companyLogoUrl.trim();
      }

      await _supabase
          .from('profiles')
          .update(updateData)
          .eq('id', user.id);

      // Return updated profile
      final updatedProfile = await getUserProfile();
      if (updatedProfile == null) {
        throw Exception('Failed to retrieve updated profile');
      }
      return updatedProfile;
    } catch (e) {
      AppLogger.error('Error updating company details', e);
      rethrow;
    }
  }

  /// Update invoice settings
  Future<UserProfile> updateInvoiceSettings({
    required bool showInvoiceTerms,
    required bool showInvoiceQr,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw Exception('User not authenticated');
    }

    try {
      // First try updating with current DB column names (show_terms/show_qr_code)
      try {
        await _supabase
            .from('profiles')
            .update({
              'show_terms': showInvoiceTerms,
              'show_qr_code': showInvoiceQr,
            })
            .eq('id', user.id);
      } on PostgrestException catch (e) {
        // If columns not found, fallback to old names
        if (e.code == 'PGRST204' || e.message.contains('Could not find') || e.message.contains('column')) {
          await _supabase
              .from('profiles')
              .update({
                'show_invoice_terms': showInvoiceTerms,
                'show_invoice_qr': showInvoiceQr,
              })
              .eq('id', user.id);
        } else {
          rethrow;
        }
      }

      // Return updated profile
      final updatedProfile = await getUserProfile();
      if (updatedProfile == null) {
        throw Exception('Failed to retrieve updated profile');
      }
      return updatedProfile;
    } catch (e) {
      AppLogger.error('Error updating invoice settings', e);
      rethrow;
    }
  }
}

