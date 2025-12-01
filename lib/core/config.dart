/// App Configuration
///
/// Supabase connection settings
///
/// To configure:
/// 1. Go to your Supabase project dashboard: https://app.supabase.com
/// 2. Select your project
/// 3. Go to Settings > API
/// 4. Copy the "Project URL" and paste it below as supabaseUrl
/// 5. Copy the "anon/public" key and paste it below as supabaseAnonKey
///
/// Note: For production, consider using environment variables or secure storage
class AppConfig {
  // Supabase Configuration
  // Replace these with your actual Supabase credentials
  static const String supabaseUrl = 'https://ptkszsydlwzdbszryfej.supabase.co';
  // Example: 'https://xxxxxxxxxxxxx.supabase.co'

  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB0a3N6c3lkbHd6ZGJzenJ5ZmVqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjQyNDUxNjEsImV4cCI6MjA3OTgyMTE2MX0.C4tdrjRI9vmu0KdcgWsP1a_SX0lH0Zu3SM-Pz0u56Js';
  // Example: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...' (very long string)

  // App Configuration
  static const String appName = 'Glanz Rental';
  static const String appVersion = '1.0.0';
}
