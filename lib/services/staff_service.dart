import '../core/supabase_client.dart';
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
      print('Error fetching staff member $staffId: $e');
      return null;
    }
  }

  /// Create a new staff member
  /// Uses RPC function to create user and profile (requires server-side function)
  Future<UserProfile> createStaff({
    required String email,
    required String password,
    required String username,
    required String fullName,
    required String phone,
    required UserRole role,
    String? branchId,
  }) async {
    // Call RPC function to create user (this should be created in Supabase)
    final response = await _supabase.rpc('create_staff_user', params: {
      'p_email': email,
      'p_password': password,
      'p_username': username,
      'p_full_name': fullName,
      'p_phone': phone,
      'p_role': role.value,
      'p_branch_id': branchId,
    });

    // RPC should return the created profile
    if (response is Map<String, dynamic>) {
      return UserProfile.fromJson(response);
    } else {
      throw Exception('Unexpected response from create_staff_user RPC');
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

  /// Delete a staff member (deletes both profile and auth user)
  /// Uses RPC function for proper deletion
  Future<void> deleteStaff(String staffId) async {
    // Call RPC function to delete user (this should be created in Supabase)
    await _supabase.rpc('delete_staff_user', params: {
      'p_user_id': staffId,
    });
  }
}

