import '../core/supabase_client.dart';
import '../core/logger.dart';
import '../models/branch.dart';

/// Branches Service
///
/// Handles all branch-related database operations
class BranchesService {
  final _supabase = SupabaseService.client;

  /// Get all branches
  Future<List<Branch>> getBranches() async {
    final response = await _supabase
        .from('branches')
        .select('id, name, address, phone, is_main, created_at')
        .order('name', ascending: true); // Match website: order by name

    return (response as List)
        .map((json) => Branch.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Get a single branch by ID
  Future<Branch?> getBranch(String branchId) async {
    try {
      final response = await _supabase
          .from('branches')
          .select()
          .eq('id', branchId)
          .single();

      return Branch.fromJson(response);
    } catch (e) {
      AppLogger.error('Error fetching branch $branchId', e);
      return null;
    }
  }

  /// Create a new branch
  Future<Branch> createBranch({
    required String name,
    required String address,
    String? phone,
  }) async {
    final response = await _supabase
        .from('branches')
        .insert({
          'name': name,
          'address': address,
          'phone': phone,
        })
        .select()
        .single();

    return Branch.fromJson(response);
  }

  /// Update an existing branch
  Future<Branch> updateBranch({
    required String branchId,
    required String name,
    required String address,
    String? phone,
  }) async {
    final response = await _supabase
        .from('branches')
        .update({
          'name': name,
          'address': address,
          'phone': phone,
        })
        .eq('id', branchId)
        .select()
        .single();

    return Branch.fromJson(response);
  }

  /// Delete a branch
  Future<void> deleteBranch(String branchId) async {
    await _supabase.from('branches').delete().eq('id', branchId);
  }
}

