import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import '../../services/auth_service.dart';
import '../../services/analytics_service.dart';
import '../../services/toast_service.dart';
import '../../utils/app_theme.dart';
import '../host/host_dashboard_screen.dart';
import 'email_verification_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _isLogin = !widget.startInSignupMode;
  }

  @override
  void dispose() {
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
            MaterialPageRoute(
              builder: (context) => const HostDashboardScreen(),
            ),
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
               builder: (context) => EmailVerificationScreen(email: _emailController.text.trim()),
            ),
          );
        }
      }
    } catch (e) {
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
      return 'This email is already registered. Please log in instead.';
    }
    
    // Default: clean up the error message
    return error.replaceAll('Sign in failed: ', '')
               .replaceAll('Sign up failed: ', '')
               .replaceAll('AuthException: ', '')
               .replaceAll('Exception: ', '');
  }

  void _showPasswordResetSuggestion() {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppTheme.darkCard,
          title: Row(
            children: [
              Icon(Icons.lock_reset, color: AppTheme.primaryColor),
              const SizedBox(width: 12),
              const Text('Need to Reset Password?'),
            ],
          ),
          content: Text(
            'If you\'re an existing user, you may need to reset your password after our recent update.\n\nWould you like to reset it now?',
            style: TextStyle(color: Colors.grey[300]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Not Now'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
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
    });
    
    try {
      final success = await _authService.signInWithGoogle();
      
      if (success && mounted) {
        final user = _authService.currentUser;
        if (user == null) return;
        
        // Check if this is a NEW user (just created) or EXISTING user
        final createdAt = user.createdAt;
        final now = DateTime.now();
        final isNewUser = now.difference(DateTime.parse(createdAt)).inSeconds < 30;
        
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
                builder: (context) => EmailVerificationScreen(email: user.email!),
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
               MaterialPageRoute(
                 builder: (context) => const HostDashboardScreen(),
               ),
             );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _getUserFriendlyErrorMessage(e.toString());
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
      builder: (context) => AlertDialog(
        title: const Text('Account Migration'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, size: 48, color: Colors.blue),
            const SizedBox(height: 16),
            Text(
              'Welcome back! We found an existing account with $email.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'To complete your account migration and secure your data, please reset your password.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
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
    final resetEmailController = TextEditingController(text: _emailController.text);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: const Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter your email address and we\'ll send you a link to reset your password.\n\nNote: If you\'re an existing user after our recent update, you\'ll need to check your email for the reset link.',
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: resetEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email',
                prefixIcon: const Icon(Icons.email_outlined),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[600]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                ),
                filled: true,
                fillColor: AppTheme.darkSurface,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
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
                  ToastService.success(context, 'Password reset email sent to $email');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isLogin ? 'Host Login' : 'Create Account'),
        backgroundColor: Colors.transparent,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.darkBg,
              AppTheme.darkSurface,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),
                  // Header Icon
                  Container(
                    width: 80,
                    height: 80,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_rounded,
                      size: 40,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  Text(
                    _isLogin ? 'Welcome Back!' : 'Create Your Account',
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isLogin
                        ? 'Sign in to manage your committees'
                        : 'Start hosting your own committees',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Error Message
                  if (_errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppTheme.errorColor.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: AppTheme.errorColor,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: AppTheme.errorColor,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Name Field (only for signup)
                  if (!_isLogin) ...[
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Email Field
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email_outlined),
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
                  const SizedBox(height: 16),

                  // Password Field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
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
                  const SizedBox(height: 32),

                  // Submit Button
                  ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(_isLogin ? 'Sign In' : 'Create Account'),
                  ),
                  
                  // Forgot Password (only in login mode)
                  if (_isLogin) ...[
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => _showForgotPasswordDialog(),
                      child: Text(
                        'Forgot Password?',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Toggle Login/Signup
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _isLogin
                            ? "Don't have an account? "
                            : 'Already have an account? ',
                        style: TextStyle(color: Colors.grey[400]),
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
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // OR Divider
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(child: Divider(color: Colors.grey[700])),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'OR',
                          style: TextStyle(color: Colors.grey[500]),
                        ),
                      ),
                      Expanded(child: Divider(color: Colors.grey[700])),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Google Sign-In Button
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _signInWithGoogle,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: BorderSide(color: Colors.grey[700]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: Image.network(
                      'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
                      height: 24,
                      width: 24,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.g_mobiledata,
                        size: 24,
                        color: Colors.white,
                      ),
                    ),
                    label: const Text(
                      'Continue with Google',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
