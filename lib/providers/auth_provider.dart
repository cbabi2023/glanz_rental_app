import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import '../models/user_profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Auth Service Provider
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// Auth State Stream Provider
///
/// Provides stream of authentication state changes
final authStateProvider = StreamProvider<AuthState>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

/// Current User Provider
///
/// Provides the current authenticated user (from Supabase Auth)
final currentUserProvider = Provider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.currentUser;
});

/// User Profile Provider
///
/// Provides the current user's profile (from profiles table)
final userProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final authService = ref.watch(authServiceProvider);
  return await authService.getUserProfile();
});

/// User Profile with Branch Provider
///
/// Provides the current user's profile with branch information
final userProfileWithBranchProvider = FutureProvider<UserProfile?>((ref) async {
  final authService = ref.watch(authServiceProvider);
  return await authService.getUserProfileWithBranch();
});

/// Is Authenticated Provider
///
/// Provides boolean indicating if user is authenticated
final isAuthenticatedProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  return user != null;
});
