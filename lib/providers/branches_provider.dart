import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/branches_service.dart';
import '../models/branch.dart';

/// Branches Service Provider
final branchesServiceProvider = Provider<BranchesService>((ref) {
  return BranchesService();
});

/// Branches List Provider
final branchesProvider = FutureProvider<List<Branch>>((ref) async {
  final service = ref.watch(branchesServiceProvider);
  return await service.getBranches();
});

/// Single Branch Provider
final branchProvider = FutureProvider.family<Branch?, String>((ref, branchId) async {
  final service = ref.watch(branchesServiceProvider);
  return await service.getBranch(branchId);
});

