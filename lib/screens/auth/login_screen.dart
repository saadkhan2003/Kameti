import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthChangeEvent;
import '../../services/auth_service.dart';
import '../../services/analytics_service.dart';
import '../../services/toast_service.dart';
import '../../utils/app_theme.dart';
import '../splash_screen.dart';
import 'email_verification_screen.dart';
import 'package:committee_app/ui/theme/theme.dart';

class LoginScreen extends StatefulWidget {
  final bool startInSignupMode;

  const LoginScreen({super.key, this.startInSignupMode = false});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _authService = AuthService();

  late bool _isLogin;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  StreamSubscription? _authSub;
  // Guard: only navigate from the auth listener when Google OAuth is in progress
  bool _isGoogleOAuthPending = false;

  @override
  void initState() {
    super.initState();
    _isLogin = !widget.startInSignupMode;

    // Handle the OAuth redirect deep-link callback on mobile.
    // When the user completes Google sign-in in the browser, Supabase fires
    // AuthChangeEvent.signedIn and we navigate to the dashboard.
    if (!kIsWeb) {
      _authSub = _authService.authStateChanges.listen((authState) {
        if (authState.event == AuthChangeEvent.signedIn &&
            mounted &&
            _isGoogleOAuthPending) {
          _isGoogleOAuthPending = false;
          final user = _authService.currentUser;
          if (user != null) {
            AnalyticsService.logLogin();
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const SplashScreen()),
            );
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isLogin) {
        await _authService.signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

        AnalyticsService.logLogin();

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const SplashScreen()),
          );
        }
      } else {
        await _authService.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          displayName: _nameController.text.trim(),
        );
        // Send verification email
        await _authService.sendEmailVerification();
        AnalyticsService.logSignUp();

        if (mounted) {
          await _authService.signOut(); // Ensure no partial session

          // Navigate to OTP Screen
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => EmailVerificationScreen(
                    email: _emailController.text.trim(),
                  ),
            ),
          );
        }
      }
    } catch (e) {
      final rawError = e.toString();

      if (!_isLogin && rawError.toLowerCase().contains('already registered')) {
        final email = _emailController.text.trim();

        try {
          await _authService.resendVerificationCode(email);
          if (mounted) {
            ToastService.info(
              context,
              'Email already exists. Verification code sent again.',
            );
          }
        } catch (_) {
          // Ignore resend failure here; user can still proceed to OTP screen.
        }

        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => EmailVerificationScreen(email: email),
            ),
          );
        }
        return;
      }

      String userFriendlyMessage = _getUserFriendlyErrorMessage(e.toString());

      setState(() {
        _errorMessage = userFriendlyMessage;
      });

      // If login failed with invalid credentials, suggest password reset
      if (_isLogin && e.toString().contains('Invalid')) {
        _showPasswordResetSuggestion();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getUserFriendlyErrorMessage(String error) {
    // Convert technical errors to user-friendly messages
    if (error.contains('Invalid login credentials') ||
        error.contains('Invalid') ||
        error.contains('credentials')) {
      return 'Incorrect email or password. Need help? Try "Forgot Password" below.';
    }

    if (error.contains('Email not confirmed')) {
      return 'Please verify your email before logging in. Check your inbox for the verification link.';
    }

    if (error.contains('User not found')) {
      return 'No account found with this email. Please sign up first.';
    }

    if (error.contains('Network')) {
      return 'Connection issue. Please check your internet and try again.';
    }

    if (error.contains('already registered')) {
      return 'This email is already registered. Please verify your email or sign in if already verified.';
    }

    if (error.contains('Database error saving new user') ||
        error.contains('AuthRetryableFetchException') ||
        error.contains('statusCode: 500')) {
      return 'Account creation is temporarily unavailable due to a server setup issue. Please try Google Sign-In or contact support.';
    }

    // Default: clean up the error message
    return error
        .replaceAll('Sign in failed: ', '')
        .replaceAll('Sign up failed: ', '')
        .replaceAll('AuthException: ', '')
        .replaceAll('Exception: ', '');
  }

  void _showPasswordResetSuggestion() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;

      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              backgroundColor: Colors.white,
              title: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: AppColors.cFFE9EEFC,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      AppIcons.lock_reset_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Need to Reset Password?',
                      overflow: TextOverflow.visible,
                    ),
                  ),
                ],
              ),
              content: Text(
                'If you\'re an existing user, you may need to reset your password after our recent update.\n\nWould you like to reset it now?',
                style: TextStyle(color: Colors.blueGrey[600], fontSize: 14),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Not Now',
                    style: TextStyle(color: AppColors.textMedium),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _showForgotPasswordDialog();
                  },
                  child: const Text('Reset Password'),
                ),
              ],
            ),
      );
    });
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _isGoogleOAuthPending = true;
    });

    try {
      final success = await _authService.signInWithGoogle();

      if (success && mounted) {
        final user = _authService.currentUser;
        if (user == null) return;

        // Check if this is a NEW user (just created) or EXISTING user
        final createdAt = user.createdAt;
        final now = DateTime.now();
        final isNewUser =
            now.difference(DateTime.parse(createdAt)).inSeconds < 30;

        // Check if user has password set (existing users from Firebase migration don't)
        // We can check identities - if only Google identity exists, they're new OAuth user
        final identities = user.identities ?? [];
        final hasEmailIdentity = identities.any((i) => i.provider == 'email');
        final hasGoogleIdentity = identities.any((i) => i.provider == 'google');

        // Scenario 1: Existing email user signing in with Google for first time
        // They need to link accounts or reset password
        if (hasEmailIdentity && hasGoogleIdentity && !isNewUser) {
          // This is an existing user who had email/password account
          // Prompt them to reset password to complete migration
          if (mounted) {
            setState(() => _isLoading = false);
            _showMigrationDialog(user.email!);
          }
          return;
        }

        // Scenario 2: Check if email exists but user just linked Google
        // (First time Google sign-in for existing Firebase user)
        if (!isNewUser && identities.length > 1) {
          if (mounted) {
            setState(() => _isLoading = false);
            _showMigrationDialog(user.email!);
          }
          return;
        }

        // Enforce Email Verification for new users
        if (user.emailConfirmedAt == null && !user.isAnonymous) {
          await _authService.signOut();
          if (mounted) {
            setState(() {
              _isLoading = false;
              _errorMessage = null;
            });

            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) => EmailVerificationScreen(email: user.email!),
              ),
            );
          }
          return;
        }

        // New user or verified user - go to dashboard
        if (!kIsWeb) {
          AnalyticsService.logLogin();
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const SplashScreen()),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _getUserFriendlyErrorMessage(e.toString());
          _isGoogleOAuthPending = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showMigrationDialog(String email) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: Colors.white,
            title: const Text(
              'Account Migration',
              style: TextStyle(
                color: AppColors.darkBg,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.cFFE9EEFC,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    AppIcons.swap_horiz_rounded,
                    size: 28,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Welcome back! We found an existing account with $email.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.darkCard,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'To complete your account migration and secure your data, please reset your password.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: AppColors.textMedium),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  // Sign out and let them use Google directly next time
                  await _authService.signOut();
                },
                child: const Text('Later'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  Navigator.pop(context);
                  // Send password reset email
                  try {
                    await _authService.resetPassword(email);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Password reset email sent to $email'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: ${e.toString()}'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                  await _authService.signOut();
                },
                child: const Text('Reset Password'),
              ),
            ],
          ),
    );
  }

  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController(
      text: _emailController.text,
    );

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            backgroundColor: Colors.white,
            title: const Text(
              'Reset Password',
              style: TextStyle(
                color: AppColors.darkBg,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Enter your email address and we\'ll send you a link to reset your password.\n\nNote: If you\'re an existing user after our recent update, you\'ll need to check your email for the reset link.',
                  style: TextStyle(color: Colors.blueGrey[600], fontSize: 14),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: resetEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    prefixIcon: const Icon(
                      AppIcons.email_outlined,
                      color: AppColors.textMedium,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.cFFD0D9EE),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                    filled: true,
                    fillColor: AppColors.cFFF8FAFF,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: AppColors.textMedium),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () async {
                  final email = resetEmailController.text.trim();
                  if (email.isEmpty) {
                    ToastService.warning(context, 'Please enter your email');
                    return;
                  }

                  try {
                    await _authService.resetPassword(email);
                    if (mounted) {
                      Navigator.pop(context);
                      ToastService.success(
                        context,
                        'Password reset email sent to $email',
                      );
                    }
                  } catch (e) {
                    ToastService.error(context, e.toString());
                  }
                },
                child: const Text('Send Reset Link'),
              ),
            ],
          ),
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: AppColors.textMedium,
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: Icon(icon, color: AppColors.textMedium),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.cFFF8FAFF,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.cFFD0D9EE),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.errorColor),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppTheme.errorColor, width: 1.6),
      ),
    );
  }

  Widget _buildAuthModeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.cFFE9EEFC,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (!_isLogin) {
                  setState(() {
                    _isLogin = true;
                    _errorMessage = null;
                  });
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _isLogin ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Sign In',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color:
                        _isLogin
                            ? AppColors.darkBg
                            : AppColors.textMedium,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_isLogin) {
                  setState(() {
                    _isLogin = false;
                    _errorMessage = null;
                  });
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: !_isLogin ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Sign Up',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color:
                        !_isLogin
                            ? AppColors.darkBg
                            : AppColors.textMedium,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    if (_errorMessage == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.cFFFFF1F2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cFFFECACA),
      ),
      child: Row(
        children: [
          const Icon(
            AppIcons.syncError,
            color: AppTheme.errorColor,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(
                color: AppColors.cFFB91C1C,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isLoading ? null : _signInWithGoogle,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          backgroundColor: Colors.white,
          side: const BorderSide(color: AppColors.cFFD0D9EE),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: Image.network(
          'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
          height: 20,
          width: 20,
          errorBuilder:
              (context, error, stackTrace) => const Icon(
                AppIcons.g_mobiledata,
                size: 24,
                color: AppColors.primary,
              ),
        ),
        label: const Text(
          'Continue with Google',
          style: TextStyle(
            color: AppColors.darkSurface,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.darkBg,
        iconTheme: const IconThemeData(color: AppColors.darkBg),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.lightBg, AppColors.bgAlt],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 16,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 6),
                        Container(
                          width: 76,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.cFFE9EEFC,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'HOST',
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          _isLogin ? 'Welcome back' : 'Create host account',
                          style: GoogleFonts.inter(
                            fontSize: 33,
                            fontWeight: FontWeight.w800,
                            color: AppColors.darkBg,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _isLogin
                              ? 'Access your committees, payment cycles, and member activity.'
                              : 'Set up your account to start creating and managing committees.',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            height: 1.45,
                            color: AppColors.textMedium,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 22),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF0F172A,
                                ).withValues(alpha: 0.08),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildAuthModeToggle(),
                              const SizedBox(height: 16),
                              _buildErrorBanner(),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 220),
                                transitionBuilder: (child, animation) {
                                  return SizeTransition(
                                    sizeFactor: animation,
                                    axisAlignment: -1,
                                    child: FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    ),
                                  );
                                },
                                child:
                                    _isLogin
                                        ? const SizedBox.shrink()
                                        : Column(
                                          key: const ValueKey('signup-fields'),
                                          children: [
                                            TextFormField(
                                              controller: _nameController,
                                              style: const TextStyle(
                                                color: AppColors.darkBg,
                                                fontWeight: FontWeight.w600,
                                              ),
                                              cursorColor: AppColors.primary,
                                              decoration: _fieldDecoration(
                                                label: 'Full Name',
                                                icon:
                                                    Icons
                                                        .person_outline_rounded,
                                              ),
                                              validator: (value) {
                                                if (!_isLogin &&
                                                    (value == null ||
                                                        value.isEmpty)) {
                                                  return 'Please enter your name';
                                                }
                                                return null;
                                              },
                                            ),
                                            const SizedBox(height: 14),
                                          ],
                                        ),
                              ),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                style: const TextStyle(
                                  color: AppColors.darkBg,
                                  fontWeight: FontWeight.w600,
                                ),
                                cursorColor: AppColors.primary,
                                decoration: _fieldDecoration(
                                  label: 'Email',
                                  icon: AppIcons.email_outlined,
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your email';
                                  }
                                  if (!value.contains('@')) {
                                    return 'Please enter a valid email';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _submit(),
                                style: const TextStyle(
                                  color: AppColors.darkBg,
                                  fontWeight: FontWeight.w600,
                                ),
                                cursorColor: AppColors.primary,
                                decoration: _fieldDecoration(
                                  label: 'Password',
                                  icon: AppIcons.lock_outline_rounded,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? AppIcons.visibility_outlined
                                          : AppIcons.visibility_off_outlined,
                                      color: AppColors.textMedium,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your password';
                                  }
                                  if (value.length < 6) {
                                    return 'Password must be at least 6 characters';
                                  }
                                  return null;
                                },
                              ),
                              if (_isLogin) ...[
                                const SizedBox(height: 6),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: _showForgotPasswordDialog,
                                    child: const Text(
                                      'Forgot Password?',
                                      style: TextStyle(
                                        color: AppColors.textMedium,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ] else
                                const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _submit,
                                  style: ElevatedButton.styleFrom(
                                    elevation: 0,
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor: const Color(
                                      0xFF3347A8,
                                    ),
                                    disabledForegroundColor: Colors.white70,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 15,
                                    ),
                                  ),
                                  child:
                                      _isLoading
                                          ? const SizedBox(
                                            height: 18,
                                            width: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                          : Text(
                                            _isLogin
                                                ? 'Sign In'
                                                : 'Create Account',
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  const Expanded(
                                    child: Divider(color: AppColors.cFFD0D9EE),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                    child: Text(
                                      'or continue with',
                                      style: GoogleFonts.inter(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.textLight,
                                      ),
                                    ),
                                  ),
                                  const Expanded(
                                    child: Divider(color: AppColors.cFFD0D9EE),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              _buildGoogleButton(),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        Center(
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                _isLogin
                                    ? "Don't have an account? "
                                    : 'Already have an account? ',
                                style: const TextStyle(
                                  color: AppColors.textMedium,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _isLogin = !_isLogin;
                                    _errorMessage = null;
                                  });
                                },
                                child: Text(
                                  _isLogin ? 'Sign Up' : 'Sign In',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
