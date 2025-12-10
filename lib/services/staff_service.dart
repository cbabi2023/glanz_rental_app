import '../core/supabase_client.dart';
import '../core/logger.dart';
import '../models/user_profile.dart';

/// Staff Service
///
/// Handles all staff/user profile management operations
class StaffService {
  final _supabase = SupabaseService.client;

  /// Get all staff (profiles)
  /// If branchId is provided, filter by branch
  Future<List<UserProfile>> getStaff({String? branchId}) async {
    dynamic query = _supabase
        .from('profiles')
        .select()
        .order('created_at', ascending: false);

    if (branchId != null) {
      query = query.eq('branch_id', branchId);
    }

    final response = await query;

    return (response as List)
        .map((json) => UserProfile.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get a single staff member by ID
  Future<UserProfile?> getStaffMember(String staffId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', staffId)
          .single();

      return UserProfile.fromJson(response);
    } catch (e) {
      AppLogger.error('Error fetching staff member $staffId', e);
      return null;
    }
  }

  /// Create a new staff member
  /// Creates auth user and profile directly
  Future<UserProfile> createStaff({
    required String email,
    required String password,
    required String username,
    required String fullName,
    required String phone,
    required UserRole role,
    String? branchId,
  }) async {
    // Step 1: Create auth user
    final authResponse = await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {'username': username, 'full_name': fullName, 'role': role.value},
    );

    if (authResponse.user == null) {
      throw Exception('Failed to create auth user');
    }

    final userId = authResponse.user!.id;

    // Step 2: Create or update profile in profiles table
    // (Profile might be auto-created by database trigger, so we use upsert)
    try {
      final profileResponse = await _supabase
          .from('profiles')
          .upsert({
            'id': userId,
            'username': username,
            'full_name': fullName,
            'phone': phone.isEmpty ? null : phone,
            'role': role.value,
            'branch_id': branchId,
          })
          .select()
          .single();

      return UserProfile.fromJson(profileResponse);
    } catch (e) {
      throw Exception('Failed to create profile: $e');
    }
  }

  /// Update a staff member's profile
  Future<UserProfile> updateStaff({
    required String staffId,
    required String username,
    required String fullName,
    required String phone,
    UserRole? role,
    String? branchId,
  }) async {
    final updateData = <String, dynamic>{
      'username': username,
      'full_name': fullName,
      'phone': phone,
    };

    if (role != null) {
      updateData['role'] = role.value;
    }

    if (branchId != null) {
      updateData['branch_id'] = branchId;
    }

    final response = await _supabase
        .from('profiles')
        .update(updateData)
        .eq('id', staffId)
        .select()
        .single();

    return UserProfile.fromJson(response);
  }

  /// Delete a staff member
  /// Note: This only deletes the profile. Auth user deletion requires admin privileges.
  /// To fully delete a user, you'll need to implement this on the backend with admin access.
  Future<void> deleteStaff(String staffId) async {
    // Delete profile from profiles table
    await _supabase.from('profiles').delete().eq('id', staffId);

    // Note: Auth user deletion requires admin/service role key
    // This should be handled by a backend function or admin panel
  }
}
