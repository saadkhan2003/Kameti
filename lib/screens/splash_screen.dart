import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../services/database_service.dart';
import '../services/biometric_service.dart';
import '../services/app_open_ad_service.dart';
import '../screens/home_screen.dart';
import '../screens/host/host_dashboard_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/lock_screen.dart';
import '../screens/force_update_screen.dart';
import '../services/remote_config_service.dart';
import '../screens/auth/reset_password_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _titleFadeAnimation;
  late Animation<double> _subtitleFadeAnimation;
  late Animation<double> _loaderFadeAnimation;

  String _status = 'Initializing...';
  bool _isComplete = false;
  String _appVersion = '';

  static const Color _bgTop = Color(0xFFF7F8FC);
  static const Color _bgBottom = Color(0xFFEEF1F8);
  static const Color _surface = Colors.white;
  static const Color _primary = Color(0xFF3347A8);
  static const Color _primarySoft = Color(0xFFE8EDFF);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _textTertiary = Color(0xFF94A3B8);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOutCubic),
      ),
    );

    _titleFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.55, curve: Curves.easeOut),
      ),
    );

    _subtitleFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.38, 0.7, curve: Curves.easeOut),
      ),
    );

    _loaderFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.55, 0.9, curve: Curves.easeOut),
      ),
    );

    _controller.forward();
    _pulseController.repeat(reverse: true);
    _loadAppVersion();
    _setupAuthListener();
    _initializeApp();
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() {
        _appVersion = 'v${packageInfo.version}';
      });
    } catch (_) {
      // Ignore version lookup errors on unsupported platforms.
    }
  }

  void _setupAuthListener() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;

      debugPrint('Auth event: $event, session: ${session != null}');

      if (event == AuthChangeEvent.passwordRecovery) {
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
            );
          });
        }
      }

      // Handle OAuth sign-in completion on Web
      if (event == AuthChangeEvent.signedIn && session != null && kIsWeb) {
        debugPrint('OAuth sign-in completed on web');
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const HostDashboardScreen()),
            );
          });
        }
      }
    });
  }

  Future<void> _initializeApp() async {
    try {
      // Step 0: Check for updates
      setState(() => _status = 'Checking for updates...');
      final remoteConfig = RemoteConfigService();
      await remoteConfig.initialize();
      final updateStatus = await remoteConfig.checkForUpdate();

      if (updateStatus.isUpdateRequired && mounted) {
        _showForceUpdateDialog(updateStatus);
        return;
      }

      // Step 1: Database
      setState(() => _status = 'Loading database...');
      await Future.delayed(const Duration(milliseconds: 300));

      // Step 1.5: Check if first launch (show onboarding)
      final dbService = DatabaseService();
      final isFirstLaunch = await dbService.isFirstLaunch();

      if (isFirstLaunch) {
        setState(() => _status = 'Welcome!');
        await Future.delayed(const Duration(milliseconds: 500));

        if (mounted) {
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder:
                  (context, animation, secondaryAnimation) =>
                      const OnboardingScreen(),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 500),
            ),
          );
        }
        return;
      }

      // Step 2: Check auth
      setState(() => _status = 'Checking authentication...');
      await Future.delayed(const Duration(milliseconds: 300));

      final authService = AuthService();

      // Refresh session to ensure token is valid (Supabase)
      try {
        if (authService.currentUser != null) {
          await authService.reloadUser();
        }
      } catch (e) {
        debugPrint('Session refresh warning: $e');
      }

      final user = authService.currentUser;

      // Step 3: Validate Email Verification
      bool isRealHost = user != null && !user.isAnonymous && user.email != null;

      if (isRealHost && user.emailConfirmedAt == null) {
        debugPrint('User is unverified. Signing out override.');
        await authService.signOut();
        isRealHost = false; // Treat as logged out
      }

      // Step 3.5: Sync if logged in AND is a real host (and verified)

      if (isRealHost) {
        setState(() => _status = 'Syncing data...');
        try {
          final syncService = SyncService();
          await syncService
              .syncAll(user!.id)
              .timeout(
                const Duration(seconds: 5),
                onTimeout: () => SyncResult(success: true, message: 'Timeout'),
              );
        } catch (e) {
          debugPrint('Sync error: $e');
        }
      }

      // Step 4: Ready
      setState(() {
        _status = 'Ready!';
        _isComplete = true;
      });

      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        // Check if biometric lock is enabled
        final isBiometricEnabled =
            await BiometricService.isBiometricLockEnabled();

        if (isBiometricEnabled) {
          // Show lock screen
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              pageBuilder:
                  (context, animation, secondaryAnimation) =>
                      LockScreen(isHost: isRealHost),
              transitionsBuilder: (
                context,
                animation,
                secondaryAnimation,
                child,
              ) {
                return FadeTransition(opacity: animation, child: child);
              },
              transitionDuration: const Duration(milliseconds: 500),
            ),
          );
          return;
        }

        // Navigate: Real hosts go to Dashboard, everyone else goes to HomeScreen
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder:
                (context, animation, secondaryAnimation) =>
                    isRealHost
                        ? const HostDashboardScreen()
                        : const HomeScreen(),
            transitionsBuilder: (
              context,
              animation,
              secondaryAnimation,
              child,
            ) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );

        // Show App Open Ad on cold start (mobile only).
        // Delayed by 600ms so the destination screen is fully painted
        // behind the ad overlay before it appears.
        if (!kIsWeb) {
          Future.delayed(const Duration(milliseconds: 600), () {
            AppOpenAdService.instance.showColdStartAd();
          });
        }
      }
    } catch (e) {
      debugPrint('Splash init error: $e');
      setState(() => _status = 'Error: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  int _currentStep() {
    final lower = _status.toLowerCase();
    if (lower.contains('update')) return 0;
    if (lower.contains('database') || lower.contains('welcome')) return 1;
    if (lower.contains('authentication')) return 2;
    if (lower.contains('sync')) return 3;
    if (_isComplete || lower.contains('ready')) return 4;
    return 0;
  }

  Widget _buildStatusStepper() {
    const labels = ['Update', 'Database', 'Auth', 'Sync'];
    final step = _currentStep();

    return Row(
      children: List.generate(labels.length * 2 - 1, (index) {
        if (index.isOdd) {
          final segment = index ~/ 2;
          final active = segment < step;
          return Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              color: active ? _primary : const Color(0xFFDDE3F1),
            ),
          );
        }

        final itemIndex = index ~/ 2;
        final completed = itemIndex < step;
        final active = itemIndex == step && !_isComplete;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color:
                    completed
                        ? _primary
                        : (active ? _primarySoft : const Color(0xFFE2E8F0)),
                shape: BoxShape.circle,
                border: Border.all(
                  color:
                      completed
                          ? _primary
                          : (active ? _primary : const Color(0xFFCBD5E1)),
                  width: 1.5,
                ),
              ),
              child: Icon(
                completed ? Icons.check_rounded : Icons.circle,
                size: completed ? 14 : 8,
                color:
                    completed
                        ? Colors.white
                        : (active ? _primary : const Color(0xFF94A3B8)),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              labels[itemIndex],
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: completed || active ? _textPrimary : _textTertiary,
              ),
            ),
          ],
        );
      }),
    );
  }

  double _pulseOpacity() {
    if (_isComplete) return 1.0;
    if (_pulseController.value < 0.5) {
      return 0.6 + (_pulseController.value * 0.4);
    }
    return 0.8 + ((1 - _pulseController.value) * 0.4);
  }

  Widget _buildProgressBar() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        return Opacity(
          opacity: _pulseOpacity(),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 6,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation<Color>(_primary),
              value: _isComplete ? 1 : null,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_bgTop, _bgBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: -70,
                right: -30,
                child: Container(
                  width: 210,
                  height: 210,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _primary.withValues(alpha: 0.06),
                  ),
                ),
              ),
              Positioned(
                bottom: -90,
                left: -20,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _primary.withValues(alpha: 0.05),
                  ),
                ),
              ),
              Center(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _fadeAnimation.value,
                      child: Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 72,
                              height: 28,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE9EEFC),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'KAMETI',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: _primary,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Stack(
                              alignment: Alignment.center,
                              children: [
                                Container(
                                  width: 124,
                                  height: 124,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _primary.withValues(alpha: 0.1),
                                  ),
                                ),
                                Container(
                                  width: 94,
                                  height: 94,
                                  decoration: BoxDecoration(
                                    color: _surface,
                                    borderRadius: BorderRadius.circular(26),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF3347A8,
                                        ).withValues(alpha: 0.14),
                                        blurRadius: 24,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.account_balance_wallet_rounded,
                                    size: 44,
                                    color: _primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 22),
                            Opacity(
                              opacity: _titleFadeAnimation.value,
                              child: const Text(
                                'Kameti',
                                style: TextStyle(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w800,
                                  color: _textPrimary,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Opacity(
                              opacity: _subtitleFadeAnimation.value,
                              child: const Text(
                                'Your trusted committee companion',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: _textSecondary,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                            const SizedBox(height: 34),
                            Opacity(
                              opacity: _loaderFadeAnimation.value,
                              child: Container(
                                width: 280,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: _surface,
                                  borderRadius: BorderRadius.circular(18),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF0F172A,
                                      ).withValues(alpha: 0.06),
                                      blurRadius: 18,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.sync_rounded,
                                          size: 16,
                                          color: _primary,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _isComplete
                                                ? 'Ready to continue'
                                                : _status,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: _textPrimary,
                                            ),
                                          ),
                                        ),
                                        if (_isComplete)
                                          const Icon(
                                            Icons.check_circle_rounded,
                                            size: 18,
                                            color: _primary,
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    _buildProgressBar(),
                                    const SizedBox(height: 14),
                                    _buildStatusStepper(),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (_appVersion.isNotEmpty)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 16,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE9EEFC),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _appVersion,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: _textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showForceUpdateDialog(UpdateStatus updateStatus) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => ForceUpdateScreen(updateStatus: updateStatus),
      ),
    );
  }
}
