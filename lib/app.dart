import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:committee_app/core/theme/app_theme.dart';
import 'package:committee_app/screens/splash_screen.dart';
import 'package:committee_app/screens/lock_screen.dart';
import 'package:committee_app/services/biometric_service.dart';
import 'package:committee_app/features/auth/data/auth_service.dart';

final navigatorKey = GlobalKey<NavigatorState>();

class CommitteeApp extends ConsumerStatefulWidget {
  const CommitteeApp({super.key});

  @override
  ConsumerState<CommitteeApp> createState() => _CommitteeAppState();
}

class _CommitteeAppState extends ConsumerState<CommitteeApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkBiometricLock();
    }
  }

  Future<void> _checkBiometricLock() async {
    // Check if lock is enabled
    final isEnabled = await BiometricService.isBiometricLockEnabled();
    // Only lock if enabled and not already showing lock screen
    if (isEnabled && !LockScreen.isShown) {
      // Note: In later steps, we will use ref.read(authServiceProvider)
      final user = AuthService().currentUser;
      final isRealHost = user != null && !user.isAnonymous && user.email != null;
      
      navigatorKey.currentState?.pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => LockScreen(isHost: isRealHost),
          transitionDuration: Duration.zero,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Kameti',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: const SplashScreen(),
    );
  }
}
