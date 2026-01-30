import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:lottie/lottie.dart';
import 'package:committee_app/core/theme/app_theme.dart';
import 'package:committee_app/features/auth/data/auth_service.dart';
import 'package:committee_app/services/sync_service.dart';
import 'package:committee_app/services/database_service.dart';
import 'package:committee_app/services/biometric_service.dart';
import 'package:committee_app/screens/home_screen.dart';
import 'package:committee_app/screens/host/host_dashboard_screen.dart';
import 'package:committee_app/screens/onboarding_screen.dart';
import 'package:committee_app/screens/lock_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  String _status = 'Initializing...';
  bool _isComplete = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _controller.forward();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      setState(() => _status = 'Checking for updates...');
      try {
        final AppUpdateInfo updateInfo = await InAppUpdate.checkForUpdate();
        if (updateInfo.updateAvailability ==
                UpdateAvailability.updateAvailable &&
            updateInfo.immediateUpdateAllowed) {
          await InAppUpdate.performImmediateUpdate();
        }
      } catch (e) {
        debugPrint('Update check failed: $e');
      }

      setState(() => _status = 'Loading database...');
      await Future.delayed(const Duration(milliseconds: 300));

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

      setState(() => _status = 'Checking authentication...');
      await Future.delayed(const Duration(milliseconds: 300));

      final authService = AuthService();
      final user = authService.currentUser;

      final isRealHost =
          user != null && !user.isAnonymous && user.email != null;

      if (isRealHost) {
        setState(() => _status = 'Syncing data...');
        try {
          final syncService = SyncService();
          await syncService
              .syncAll(user.uid)
              .timeout(
                const Duration(seconds: 5),
                onTimeout: () => SyncResult(success: true, message: 'Timeout'),
              );
        } catch (e) {
          debugPrint('Sync error: $e');
        }
      }

      setState(() {
        _status = 'Ready!';
        _isComplete = true;
      });

      await Future.delayed(const Duration(milliseconds: 500));

      if (mounted) {
        final isBiometricEnabled =
            await BiometricService.isBiometricLockEnabled();

        if (isBiometricEnabled) {
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
      }
    } catch (e) {
      debugPrint('Splash init error: $e');
      setState(() => _status = 'Error: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Lottie.asset(
                      'assets/animations/animation.json',
                      width: 250,
                      height: 250,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 32),
                    const Text(
                      'Kameti',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Chit Fund Manager',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                        letterSpacing: 3,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 60),
                    if (!_isComplete)
                      SizedBox(
                        width: 180,
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                backgroundColor: Colors.grey[100],
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppTheme.primaryColor,
                                ),
                                minHeight: 4,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _status,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[400],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 32,
                        color: AppTheme.primaryColor,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
