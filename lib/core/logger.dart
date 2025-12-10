import 'package:flutter/foundation.dart';

/// Logger utility for production-safe logging
/// 
/// Uses debugPrint in debug mode and can be extended for production logging
class AppLogger {
  /// Log debug messages (only in debug mode)
  static void debug(String message) {
    if (kDebugMode) {
      debugPrint('🔍 [DEBUG] $message');
    }
  }

  /// Log info messages
  static void info(String message) {
    if (kDebugMode) {
      debugPrint('ℹ️ [INFO] $message');
    }
  }

  /// Log success messages
  static void success(String message) {
    if (kDebugMode) {
      debugPrint('✅ [SUCCESS] $message');
    }
  }

  /// Log warning messages
  static void warning(String message) {
    if (kDebugMode) {
      debugPrint('⚠️ [WARNING] $message');
    }
  }

  /// Log error messages
  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('❌ [ERROR] $message');
      if (error != null) {
        debugPrint('   Error: $error');
      }
      if (stackTrace != null) {
        debugPrint('   Stack trace: $stackTrace');
      }
    }
    // In production, you could send errors to a crash reporting service
    // e.g., Firebase Crashlytics, Sentry, etc.
  }

  /// Log error messages with emoji prefix (for compatibility)
  static void errorWithEmoji(String emoji, String message, [Object? error]) {
    if (kDebugMode) {
      debugPrint('$emoji [ERROR] $message');
      if (error != null) {
        debugPrint('   Error: $error');
      }
    }
  }
}

