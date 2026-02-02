import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Supabase configuration loaded from environment variables
/// 
/// Get your credentials from: https://supabase.com/dashboard/project/_/settings/api
class SupabaseConfig {
  /// Supabase project URL
  static String get url => dotenv.env['SUPABASE_URL'] ?? '';

  /// Supabase anonymous/public API key (safe to use in client apps)
  static String get anonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  /// Validate that configuration is loaded
  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}
