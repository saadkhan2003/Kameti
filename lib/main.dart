import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:upgrader/upgrader.dart';
import 'supabase_config.dart';
import 'services/database_service.dart';
import 'services/app_open_ad_service.dart';
import 'services/review_service.dart';
import 'utils/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/lock_screen.dart';
import 'services/biometric_service.dart';
import 'services/auth_service.dart';
import 'services/sync_status_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await DatabaseService.initialize();

  // Initialize Google Mobile Ads SDK (only on mobile, not web)
  if (!kIsWeb) {
    await MobileAds.instance.initialize();
    // Begin loading the first App Open Ad in the background immediately.
    // By the time the splash screen finishes, the ad will be ready.
    await AppOpenAdService.instance.initialize();
    if (kDebugMode) debugPrint('✅ Google Mobile Ads SDK initialized');
  }

  // Load environment variables (renamed to avoid Netlify 404 on dotfiles)
  await dotenv.load(fileName: "assets/env");
  if (kDebugMode) debugPrint('📦 Environment variables loaded');

  // Initialize Supabase (new backend)
  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
      authOptions: FlutterAuthClientOptions(
        authFlowType: kIsWeb ? AuthFlowType.pkce : AuthFlowType.pkce,
      ),
    );
    if (kDebugMode) debugPrint('✅ Supabase initialized');
  } else {
    if (kDebugMode) {
      debugPrint('⚠️  Supabase not configured - add credentials to .env');
    }
  }

  // Firebase has been fully replaced by Supabase.
  // Initialization removed to prevent "RESOURCE_EXHAUSTED" errors.

  // Increment launch counter for in-app review eligibility tracking.
  if (!kIsWeb) {
    await ReviewService().recordAppLaunch();
  }

  runApp(const CommitteeApp());
}

class CommitteeApp extends StatefulWidget {
  const CommitteeApp({super.key});

  @override
  State<CommitteeApp> createState() => _CommitteeAppState();
}

class _CommitteeAppState extends State<CommitteeApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SyncStatusService.navigatorKey = navigatorKey;
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
      _maybeShowResumeAd();
    }
  }

  Future<void> _checkBiometricLock() async {
    // Check if lock is enabled
    final isEnabled = await BiometricService.isBiometricLockEnabled();
    // Only lock if enabled and not already showing lock screen
    if (isEnabled && !LockScreen.isShown) {
      final user = AuthService().currentUser;
      final isRealHost =
          user != null && !user.isAnonymous && user.email != null;

      navigatorKey.currentState?.pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => LockScreen(isHost: isRealHost),
          transitionDuration: Duration.zero,
        ),
      );
    }
  }

  /// Show an App Open Ad when the app returns from background,
  /// but ONLY when biometric lock is not involved (the lock screen
  /// gives a better re-entry experience than an ad).
  Future<void> _maybeShowResumeAd() async {
    if (kIsWeb) return;
    final isBiometricEnabled = await BiometricService.isBiometricLockEnabled();
    if (!isBiometricEnabled) {
      AppOpenAdService.instance.showResumeAd();
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = MaterialApp(
      navigatorKey: navigatorKey,
      title: 'Kameti',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: const SplashScreen(),
    );

    // Wrap with UpgradeAlert on mobile only.
    // This silently checks the App Store / Play Store and shows an
    // optional update dialog when a new version is available.
    if (kIsWeb) return app;

    return UpgradeAlert(
      upgrader: Upgrader(durationUntilAlertAgain: const Duration(days: 3)),
      dialogStyle: UpgradeDialogStyle.material,
      child: app,
    );
  }
}
