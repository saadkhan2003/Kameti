import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class PushNotificationService {
  final SupabaseService _supabase = SupabaseService();
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  StreamSubscription<AuthState>? _authSub;
  String? _pendingToken;

  /// Initialize Push Notifications, request permissions, and save the token.
  ///
  /// Also sets up a foreground notification display so messages are visible
  /// even when the app is in the foreground.
  Future<void> initialize() async {
    if (kIsWeb) return; // Wait for mobile devices

    await _initializeLocalNotifications();

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

        // 4. Show a local notification when a message arrives in the foreground
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

        // 5. Log when the user taps a notification
        FirebaseMessaging.onMessageOpenedApp.listen((message) {
          if (kDebugMode) {
            debugPrint('📌 Notification tapped: ${message.messageId}');
          }
        });

        // 6. Log initial message if app was launched from a notification
        FirebaseMessaging.instance.getInitialMessage().then((message) {
          if (message != null && kDebugMode) {
            debugPrint(
              '📌 App launched from notification: ${message.messageId}',
            );
          }
        });
      } else {
        if (kDebugMode) {
          debugPrint(
            'User declined or has not accepted notification permissions',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) debugPrint('Error initializing Push Notifications: $e');
    }
  }

  Future<void> _saveTokenWhenAuthAvailable() async {
    final token = _pendingToken;
    if (token == null) return;

    var currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      // If there is no session yet, create an anonymous session so we can
      // store the token and later target this device if needed.
      try {
        if (kDebugMode) debugPrint('No auth session; signing in anonymously');
        await Supabase.instance.client.auth.signInAnonymously();
        currentUser = Supabase.instance.client.auth.currentUser;
      } catch (e) {
        if (kDebugMode) debugPrint('Anonymous sign-in failed: $e');
      }
    }

    if (currentUser != null) {
      await _supabase.saveDeviceToken(token);
      _pendingToken = null;
      await _authSub?.cancel();
      _authSub = null;
      return;
    }

    // If still no user, subscribe to auth changes and try again when signed in.
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

  Future<void> _initializeLocalNotifications() async {
    // Use the default launcher icon name. If you have a custom notification icon,
    // add it in android/app/src/main/res/drawable/ and use that name here.
    final androidSettings = AndroidInitializationSettings('ic_launcher');
    final iosSettings = DarwinInitializationSettings();

    await _localNotifications.initialize(
      settings: InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );

    // Create a notification channel so Android can display notifications.
    const channel = AndroidNotificationChannel(
      'kameti_messages',
      'Notifications',
      description: 'Push notifications from Kameti',
      importance: Importance.high,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    if (kDebugMode) debugPrint('📩 FCM onMessage: ${message.messageId}');

    final notification = message.notification;
    if (notification == null) return;

    const channel = AndroidNotificationChannel(
      'kameti_messages',
      'Notifications',
      description: 'Push notifications from Kameti',
      importance: Importance.high,
    );

    final androidDetails = AndroidNotificationDetails(
      channel.id,
      channel.name,
      channelDescription: channel.description,
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_launcher',
    );

    final platformDetails = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      id: message.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: platformDetails,
    );
  }
}
