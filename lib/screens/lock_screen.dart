import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/biometric_service.dart';
import 'home_screen.dart';
import 'host/host_dashboard_screen.dart';

class LockScreen extends StatefulWidget {
  final bool isHost;
  static bool isShown = false;

  const LockScreen({super.key, required this.isHost});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> with WidgetsBindingObserver {
  static const Color _bgTop = Color(0xFFF7F8FC);
  static const Color _bgBottom = Color(0xFFEEF1F8);
  static const Color _surface = Colors.white;
  static const Color _primary = Color(0xFF3347A8);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);

  bool _isAuthenticating = false;
  String _error = '';
  String _biometricType = 'Biometric';

  @override
  void initState() {
    super.initState();
    LockScreen.isShown = true;
    WidgetsBinding.instance.addObserver(this);
    _initBiometricType();
    _authenticate();
  }

  @override
  void dispose() {
    LockScreen.isShown = false;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Auto-authenticate when app resumes
    if (state == AppLifecycleState.resumed && !_isAuthenticating) {
      _authenticate();
    }
  }

  Future<void> _initBiometricType() async {
    final types = await BiometricService.getAvailableBiometrics();
    if (mounted) {
      setState(() {
        _biometricType = BiometricService.getBiometricTypeName(types);
      });
    }
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;

    setState(() {
      _isAuthenticating = true;
      _error = '';
    });

    try {
      final success = await BiometricService.authenticate(
        reason: 'Unlock Committee App',
      );

      if (success && mounted) {
        _navigateToApp();
      } else if (mounted) {
        setState(() {
          _error = 'Authentication failed. Tap to try again.';
          _isAuthenticating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error: $e';
          _isAuthenticating = false;
        });
      }
    }
  }

  void _navigateToApp() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder:
            (_) =>
                widget.isHost
                    ? const HostDashboardScreen()
                    : const HomeScreen(),
      ),
    );
  }

  IconData _biometricIcon() {
    return _biometricType == 'Face ID'
        ? Icons.face_rounded
        : Icons.fingerprint_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgTop, _bgBottom],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: -90,
                right: -30,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _primary.withValues(alpha: 0.08),
                  ),
                ),
              ),
              Positioned(
                bottom: -100,
                left: -40,
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _primary.withValues(alpha: 0.06),
                  ),
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 76,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE9EEFC),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'SECURE',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                            color: _primary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        width: 88,
                        height: 88,
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF3347A8,
                              ).withValues(alpha: 0.15),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          size: 42,
                          color: _primary,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Kameti is locked',
                        style: GoogleFonts.inter(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: _textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isAuthenticating
                            ? 'Verifying with $_biometricType...'
                            : 'Authenticate to continue to your dashboard',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          height: 1.45,
                          color: _textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        constraints: const BoxConstraints(maxWidth: 340),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF0F172A,
                              ).withValues(alpha: 0.08),
                              blurRadius: 22,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 92,
                              height: 92,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFE9EEFC),
                                border: Border.all(
                                  color:
                                      _isAuthenticating
                                          ? _primary
                                          : const Color(0xFFC9D4EE),
                                  width: 1.6,
                                ),
                              ),
                              child:
                                  _isAuthenticating
                                      ? const Padding(
                                        padding: EdgeInsets.all(26),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.8,
                                          color: _primary,
                                        ),
                                      )
                                      : Icon(
                                        _biometricIcon(),
                                        size: 44,
                                        color: _primary,
                                      ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _biometricType,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: _textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _isAuthenticating
                                  ? 'Please wait while we verify your identity'
                                  : 'Use your $_biometricType to unlock securely',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: _textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 18),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed:
                                    _isAuthenticating ? null : _authenticate,
                                style: ElevatedButton.styleFrom(
                                  elevation: 0,
                                  backgroundColor: _primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                icon: Icon(
                                  _isAuthenticating
                                      ? Icons.hourglass_top_rounded
                                      : _biometricIcon(),
                                  size: 18,
                                ),
                                label: Text(
                                  _isAuthenticating
                                      ? 'Authenticating...'
                                      : 'Unlock with $_biometricType',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_error.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxWidth: 340),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1F2),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                size: 18,
                                color: Color(0xFFB91C1C),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _error,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: const Color(0xFFB91C1C),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
