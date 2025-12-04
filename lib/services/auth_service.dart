import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/supabase_client.dart';
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
    final response = await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
    return response.user;
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
      print('Error fetching user profile: $e');
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
      print('Error fetching user profile with branch: $e');
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
      print('Error updating GST settings: $e');
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
      print('Error updating branch: $e');
      rethrow;
    }
  }
}

