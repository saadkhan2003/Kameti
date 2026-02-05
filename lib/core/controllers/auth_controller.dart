import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

/// Controller for authentication business logic
class AuthController extends ChangeNotifier {
  final _authService = AuthService();

  bool _isLoading = false;
  String? _errorMessage;
  bool _isLogin = true;

  // Getters
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLogin => _isLogin;
  bool get isLoggedIn => _authService.currentUser != null;
  String? get userId => _authService.currentUser?.id;
  String? get email => _authService.currentUser?.email;
  String? get displayName => _authService.currentUser?.userMetadata?['full_name'];
  bool get isEmailVerified => _authService.currentUser?.emailConfirmedAt != null;

  void toggleLoginMode() {
    _isLogin = !_isLogin;
    _errorMessage = null;
    notifyListeners();
  }

  void setLoginMode(bool isLogin) {
    _isLogin = isLogin;
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Sign in with email and password
  Future<bool> signIn({required String email, required String password}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.signIn(email: email, password: password);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Sign up with email and password
  Future<bool> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _authService.signUp(
        email: email,
        password: password,
        displayName: displayName,
      );
      await _authService.sendEmailVerification();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Sign in with Google
  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final credential = await _authService.signInWithGoogle();
      _isLoading = false;
      notifyListeners();
      return credential != null;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Reset password
  Future<bool> resetPassword(String email) async {
    try {
      await _authService.resetPassword(email);
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await _authService.signOut();
    notifyListeners();
  }

  /// Resend email verification
  Future<bool> resendEmailVerification() async {
    try {
      await _authService.sendEmailVerification();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  /// Reload user to check email verification
  Future<void> reloadUser() async {
    await _authService.reloadUser();
    notifyListeners();
  }
}
