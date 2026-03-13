import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class PushNotificationService {
  final SupabaseService _supabase = SupabaseService();
  StreamSubscription<AuthState>? _authSub;
  String? _pendingToken;

  /// Initialize Push Notifications, request permissions, and save the token
  Future<void> initialize() async {
    if (kIsWeb) return; // Wait for mobile devices

    try {
      final FirebaseMessaging fcm = FirebaseMessaging.instance;
      
      // 1. Request permissions (shows prompt on iOS, no-op on Android 12-)
      NotificationSettings settings = await fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        
        // 2. Get the FCM device token
        String? token = await fcm.getToken();
        
        if (token != null) {
          if (kDebugMode) debugPrint('FCM Token: $token');
          _pendingToken = token;
          await _saveTokenWhenAuthAvailable();
        }

        // 3. Listen for token refreshes
        fcm.onTokenRefresh.listen((newToken) async {
          if (kDebugMode) debugPrint('FCM Token Refreshed: $newToken');
          _pendingToken = newToken;
          await _saveTokenWhenAuthAvailable();
        });

      } else {
        if (kDebugMode) debugPrint('User declined or has not accepted notification permissions');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error initializing Push Notifications: $e');
    }
  }

  Future<void> _saveTokenWhenAuthAvailable() async {
    final token = _pendingToken;
    if (token == null) return;

    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null) {
      await _supabase.saveDeviceToken(token);
      _pendingToken = null;
      await _authSub?.cancel();
      _authSub = null;
      return;
    }

    // If no user yet, subscribe to auth changes and try again when signed in.
    _authSub ??= Supabase.instance.client.auth.onAuthStateChange.listen(
      (event) async {
        if (event.event == AuthChangeEvent.signedIn ||
            event.event == AuthChangeEvent.tokenRefreshed) {
          if (kDebugMode) debugPrint('Auth signed in; saving pending FCM token');
          await _saveTokenWhenAuthAvailable();
        }
      },
    );
  }
}
