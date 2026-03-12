import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'supabase_service.dart';

class PushNotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final SupabaseService _supabase = SupabaseService();

  /// Initialize Push Notifications, request permissions, and save the token
  Future<void> initialize() async {
    if (kIsWeb) return; // Wait for mobile devices

    try {
      // 1. Request permissions (shows prompt on iOS, no-op on Android 12-)
      NotificationSettings settings = await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        
        // 2. Get the FCM device token
        String? token = await _fcm.getToken();
        
        if (token != null) {
          if (kDebugMode) debugPrint('FCM Token: $token');
          // 3. Save token to Supabase
          await _supabase.saveDeviceToken(token);
        }

        // 4. Listen for token refreshes
        _fcm.onTokenRefresh.listen((newToken) async {
          if (kDebugMode) debugPrint('FCM Token Refreshed: $newToken');
          await _supabase.saveDeviceToken(newToken);
        });

      } else {
        if (kDebugMode) debugPrint('User declined or has not accepted notification permissions');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error initializing Push Notifications: $e');
    }
  }
}
