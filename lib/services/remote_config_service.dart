import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Remote Config Service using Supabase
/// Handles version checking and force update logic
class RemoteConfigService {
  static final RemoteConfigService _instance = RemoteConfigService._internal();
  factory RemoteConfigService() => _instance;
  RemoteConfigService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  
  Map<String, String> _config = {};
  bool _initialized = false;

  /// Fetch all config values from Supabase
  Future<void> initialize() async {
    try {
      final response = await _supabase
          .from('app_config')
          .select('config_key, config_value');

      _config = {
        for (var item in response as List)
          item['config_key'] as String: item['config_value'] as String
      };
      
      _initialized = true;
      print('📋 Remote Config loaded: ${_config.length} keys');
    } catch (e) {
      print('⚠️ Failed to load remote config: $e');
      // Use default values if remote config fails
      _config = _getDefaultConfig();
      _initialized = true;
    }
  }

  Map<String, String> _getDefaultConfig() {
    return {
      'min_android_version': '1.0.0',
      'min_ios_version': '1.0.0',
      'force_update_enabled': 'false',
      'update_message_title': 'Update Required',
      'update_message_body': 'Please update to the latest version to continue using the app.',
      'playstore_url': 'https://play.google.com/store/apps/details?id=com.yourcompany.yourapp',
      'appstore_url': 'https://apps.apple.com/app/id123456789',
    };
  }

  /// Get config value by key
  String getString(String key, {String defaultValue = ''}) {
    if (!_initialized) {
      print('⚠️ RemoteConfig not initialized, using default');
      return _getDefaultConfig()[key] ?? defaultValue;
    }
    return _config[key] ?? defaultValue;
  }

  bool getBool(String key, {bool defaultValue = false}) {
    final value = getString(key, defaultValue: defaultValue.toString());
    return value.toLowerCase() == 'true';
  }

  /// Check if current app version is below minimum required version
  Future<UpdateStatus> checkForUpdate() async {
    try {
      // Get current app version
      final PackageInfo packageInfo = await PackageInfo.fromPlatform();
      final String currentVersion = packageInfo.version;

      // Check if force update is enabled
      final bool forceUpdateEnabled = getBool('force_update_enabled');
      
      if (!forceUpdateEnabled) {
        return UpdateStatus(
          isUpdateRequired: false,
          currentVersion: currentVersion,
        );
      }

      // Get minimum required version (Android for now, can add iOS logic)
      final String minVersion = getString('min_android_version', defaultValue: '1.0.0');

      // Compare versions
      final bool needsUpdate = _isVersionLower(currentVersion, minVersion);

      return UpdateStatus(
        isUpdateRequired: needsUpdate,
        currentVersion: currentVersion,
        minimumVersion: minVersion,
        updateTitle: getString('update_message_title'),
        updateMessage: getString('update_message_body'),
        storeUrl: getString('playstore_url'),
      );
    } catch (e) {
      print('Error checking for update: $e');
      return UpdateStatus(isUpdateRequired: false, currentVersion: '0.0.0');
    }
  }

  /// Compare two version strings (e.g., "1.2.3" vs "1.3.0")
  /// Returns true if currentVersion < minimumVersion
  bool _isVersionLower(String currentVersion, String minimumVersion) {
    final current = _parseVersion(currentVersion);
    final minimum = _parseVersion(minimumVersion);

    for (int i = 0; i < 3; i++) {
      if (current[i] < minimum[i]) return true;
      if (current[i] > minimum[i]) return false;
    }
    
    return false; // Versions are equal
  }

  /// Parse version string "1.2.3" into [1, 2, 3]
  List<int> _parseVersion(String version) {
    try {
      return version
          .split('.')
          .take(3)
          .map((e) => int.tryParse(e) ?? 0)
          .toList();
    } catch (e) {
      return [0, 0, 0];
    }
  }

  /// Refresh config from server
  Future<void> refresh() async {
    await initialize();
  }
}

/// Update status data class
class UpdateStatus {
  final bool isUpdateRequired;
  final String currentVersion;
  final String? minimumVersion;
  final String? updateTitle;
  final String? updateMessage;
  final String? storeUrl;

  UpdateStatus({
    required this.isUpdateRequired,
    required this.currentVersion,
    this.minimumVersion,
    this.updateTitle,
    this.updateMessage,
    this.storeUrl,
  });

  @override
  String toString() {
    return 'UpdateStatus(required: $isUpdateRequired, current: $currentVersion, min: $minimumVersion)';
  }
}
