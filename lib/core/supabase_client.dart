import 'package:supabase_flutter/supabase_flutter.dart';
import 'config.dart';

/// Supabase Service
///
/// Centralized Supabase client initialization and access
class SupabaseService {
  static SupabaseClient? _client;

  /// Initialize Supabase with credentials from AppConfig
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
      realtimeClientOptions: const RealtimeClientOptions(
        logLevel: RealtimeLogLevel.info,
      ),
    );
    _client = Supabase.instance.client;
  }

  /// Get the Supabase client instance
  static SupabaseClient get client {
    if (_client == null) {
      throw Exception(
        'Supabase not initialized. Call SupabaseService.initialize() first.',
      );
    }
    return _client!;
  }

  /// Quick access to auth
  static GoTrueClient get auth => client.auth;

  /// Quick access to database (Postgrest)
  static PostgrestClient get database => client.rest;

  /// Quick access to storage (use client.storage.from('bucket') directly)
  // static StorageClient get storage => client.storage;

  /// Quick access to realtime
  static RealtimeClient get realtime => client.realtime;

  /// Get current user
  static User? get currentUser => client.auth.currentUser;

  /// Stream of auth state changes
  static Stream<AuthState> get authStateChanges =>
      client.auth.onAuthStateChange;

  /// Check if user is authenticated
  static bool get isAuthenticated => currentUser != null;
}
