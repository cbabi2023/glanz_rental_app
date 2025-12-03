import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/staff_service.dart';
import '../models/user_profile.dart';

/// Staff Service Provider
final staffServiceProvider = Provider<StaffService>((ref) {
  return StaffService();
});

/// Staff List Provider
/// If branchId is null, returns all staff
final staffProvider = FutureProvider.family<List<UserProfile>, String?>((ref, branchId) async {
  final service = ref.watch(staffServiceProvider);
  return await service.getStaff(branchId: branchId);
});

/// Single Staff Member Provider
final staffMemberProvider = FutureProvider.family<UserProfile?, String>((ref, staffId) async {
  final service = ref.watch(staffServiceProvider);
  return await service.getStaffMember(staffId);
});

