import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'database_service.dart';

class AuthService {
  final GoTrueClient _auth = Supabase.instance.client.auth;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Check if user is logged in
  bool get isLoggedIn => currentUser != null;

  // Auth state stream
  Stream<AuthState> get authStateChanges => _auth.onAuthStateChange;

  // Sign up with email and password
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final response = await _auth.signUp(
        email: email,
        password: password,
        data: displayName != null ? {'full_name': displayName} : null,
      );
      return response;
    } catch (e) {
      throw 'Sign up failed: ${e.toString()}';
    }
  }

  // Sign in with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithPassword(
        email: email,
        password: password,
      );
    } catch (e) {
       throw 'Sign in failed: ${e.toString()}';
    }
  }

  // Note: signInAnonymously removed - not needed with Supabase RLS

  // Sign in with Google
  Future<bool> signInWithGoogle() async {
    try {
      // PROPER WAY for Flutter (Mobile & Web)
      if (kIsWeb) {
        // Web: Redirect flow with account picker
        // Use the main app URL, NOT the password reset URL
        await _auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: 'https://kameti.netlify.app/', // Main app URL, not reset page
          queryParams: {
            'prompt': 'select_account', // Shows account picker with existing accounts
          },
        );
        return true; // Web flow redirects, so this might not be reached immediately
      } else {
        // Mobile: Native Google Sign In (Better UX)
        // 1. Sign in with Google
        final webClientId = dotenv.env['GOOGLE_WEB_CLIENT_ID'];
        final GoogleSignInAccount? googleUser = await GoogleSignIn(
          serverClientId: webClientId,
        ).signIn();
        if (googleUser == null) return false; // User canceled

        final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
        final accessToken = googleAuth.accessToken;
        final idToken = googleAuth.idToken;

        if (accessToken == null) throw 'No Access Token found.';
        if (idToken == null) throw 'No ID Token found.';

        // 2. Sign in to Supabase with ID Token
        await _auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: idToken,
          accessToken: accessToken,
        );
        return true;
      }
    } catch (e) {
      print('Google sign in error: $e');
      throw 'Google sign-in failed: ${e.toString()}';
    }
  }

  // Sign out
  Future<void> signOut() async {
    // Clear local data to ensure user separation
    await DatabaseService.clearAllData();
    await _auth.signOut();
  }

  // Delete account and all data
  Future<void> deleteAccount() async {
    final user = currentUser;
    if (user == null) return;

    // Clear local data
    await DatabaseService.clearAllData();
    
    // Delete Supabase user account (requires Admin API or Edge Function usually, 
    // but users can delete themselves if configured in Supabase settings)
    // For now, we'll just sign out as client SDK cannot easily delete users without configuration
    await _auth.signOut(); 
    // Note: To implement true delete, you'd call a Supabase Edge Function
  }

  // Reset password
  Future<void> resetPassword(String email) async {
    try {
      await _auth.resetPasswordForEmail(email);
    } catch (e) {
      throw 'Reset password failed: ${e.toString()}';
    }
  }

  // Check if email is verified (Supabase handles this differently, checking metadata)
  bool get isEmailVerified => currentUser?.emailConfirmedAt != null;

  // Send email verification - Supabase sends this automatically on signup usually
  Future<void> sendEmailVerification() async {
    // Supabase handles this via email templates
  }

  // Reload doesn't exist explicitly in Supabase SDK, fetch user again
  Future<void> reloadUser() async {
    await _auth.refreshSession();
  }

  // Update password (for reset flow)
  Future<void> updatePassword(String newPassword) async {
    try {
      await _auth.updateUser(UserAttributes(password: newPassword));
    } catch (e) {
      throw 'Update password failed: ${e.toString()}';
    }
  }

  // Verify Email OTP (6-digit code)
  Future<void> verifyEmailOtp({required String email, required String token}) async {
    try {
      // Try both 'signup' and 'email' types as context varies
      try {
        await _auth.verifyOTP(
          token: token,
          type: OtpType.signup,
          email: email,
        );
      } catch (_) {
        // Fallback if not a new signup
        await _auth.verifyOTP(
          token: token,
          type: OtpType.email,
          email: email,
        );
      }
    } catch (e) {
      throw 'Invalid code. Please check and try again.';
    }
  }

  // Resend OTP
  Future<void> resendVerificationCode(String email) async {
    try {
       await _auth.resend(type: OtpType.signup, email: email);
    } catch (e) {
      throw 'Failed to resend code: ${e.toString()}';
    }
  }
}
