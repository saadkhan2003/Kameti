import 'package:committee_app/services/database_service.dart';
import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();
  
  /// Check if device supports biometric authentication
  static Future<bool> isDeviceSupported() async {
    try {
      return await _auth.isDeviceSupported();
    } catch (e) {
      debugPrint('Biometric device check error: $e');
      return false;
    }
  }
  
  /// Check if biometrics are enrolled on the device
  static Future<bool> canCheckBiometrics() async {
    try {
      return await _auth.canCheckBiometrics;
    } catch (e) {
      debugPrint('Biometric availability check error: $e');
      return false;
    }
  }
  
  /// Get available biometric types
  static Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (e) {
      debugPrint('Biometric types error: $e');
      return [];
    }
  }
  
  /// Authenticate using biometrics
  static Future<bool> authenticate({String reason = 'Unlock Committee App'}) async {
    try {
      final isAvailable = await canCheckBiometrics();
      if (!isAvailable) return false;
      
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (e) {
      debugPrint('Biometric auth error: $e');
      return false;
    }
  }
  
  /// Check if biometric lock is enabled by user
  static Future<bool> isBiometricLockEnabled() async {
    final dbService = DatabaseService();
    return dbService.isBiometricEnabled();
  }
  
  /// Enable/disable biometric lock
  static Future<void> setBiometricLockEnabled(bool enabled) async {
    final dbService = DatabaseService();
    await dbService.setBiometricEnabled(enabled);
  }
  
  /// Get a friendly name for the biometric type
  static String getBiometricTypeName(List<BiometricType> types) {
    if (types.contains(BiometricType.face)) {
      return 'Face ID';
    } else if (types.contains(BiometricType.fingerprint)) {
      return 'Fingerprint';
    } else if (types.contains(BiometricType.iris)) {
      return 'Iris';
    }
    return 'Biometric';
  }
}
