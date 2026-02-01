// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Committee App';

  @override
  String get myKametis => 'My Kametis';

  @override
  String get joinedAKameti => 'Joined a Kameti?';

  @override
  String get viewKametiPayments => 'View Kameti Payments';

  @override
  String get yourHostedKametis => 'Your Hosted Kametis';

  @override
  String get archivedSection => 'Archived';

  @override
  String get archivedKametis => 'Archived Kametis';

  @override
  String get newCommittee => 'New Committee';

  @override
  String get noArchivedKametis => 'No archived kametis';

  @override
  String get verifyEmail => 'Verify your email';

  @override
  String get checkInbox => 'Check your inbox for verification link';

  @override
  String get resend => 'Resend';

  @override
  String get verificationEmailSent => 'Verification email sent!';

  @override
  String get emailVerifiedSuccess => 'Email verified successfully! ✓';

  @override
  String get archive => 'Archive';

  @override
  String get undo => 'Undo';

  @override
  String get delete => 'Delete';

  @override
  String get cancel => 'Cancel';

  @override
  String get restore => 'Restore';

  @override
  String kametiArchived(String name) {
    return '$name archived';
  }

  @override
  String kametiDeleted(String name) {
    return '$name deleted';
  }

  @override
  String get archiveKametiTitle => 'Archive Kameti?';

  @override
  String archiveKametiContent(String name) {
    return 'This will move \"$name\" to the archived section. You can restore it later.';
  }

  @override
  String get deleteKametiTitle => 'Delete Kameti?';

  @override
  String deleteKametiContent(String name) {
    return 'This will permanently delete \"$name\" and all its data. This cannot be undone.';
  }

  @override
  String get profile => 'Profile';

  @override
  String get about => 'About';

  @override
  String get settings => 'Settings';

  @override
  String get termsConditions => 'Terms & Conditions';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get contactUs => 'Contact Us';

  @override
  String get logout => 'Logout';

  @override
  String get activeKametis => 'active kametis';

  @override
  String get noCommitteesYet => 'No Committees Yet';

  @override
  String get createFirstCommittee =>
      'Create your first committee to get started';

  @override
  String get hostLogin => 'Host Login';

  @override
  String get createAccount => 'Create Account';

  @override
  String get welcomeBack => 'Welcome Back!';

  @override
  String get createYourAccount => 'Create Your Account';

  @override
  String get signInToManage => 'Sign in to manage your committees';

  @override
  String get startHosting => 'Start hosting your own committees';

  @override
  String get fullName => 'Full Name';

  @override
  String get pleaseEnterName => 'Please enter your name';

  @override
  String get email => 'Email';

  @override
  String get pleaseEnterEmail => 'Please enter your email';

  @override
  String get enterValidEmail => 'Please enter a valid email';

  @override
  String get password => 'Password';

  @override
  String get pleaseEnterPassword => 'Please enter your password';

  @override
  String get passwordMinLength => 'Password must be at least 6 characters';

  @override
  String get signIn => 'Sign In';

  @override
  String get forgotPassword => 'Forgot Password?';

  @override
  String get dontHaveAccount => 'Don\'t have an account? ';

  @override
  String get alreadyHaveAccount => 'Already have an account? ';

  @override
  String get signUp => 'Sign Up';

  @override
  String get or => 'OR';

  @override
  String get signingIn => 'Signing in...';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get verificationSent =>
      'Verification email sent! Please check your inbox.';

  @override
  String get resetPassword => 'Reset Password';

  @override
  String get resetPasswordDesc =>
      'Enter your email address and we\'ll send you a link to reset your password.';

  @override
  String get sendResetLink => 'Send Reset Link';

  @override
  String passwordResetSent(String email) {
    return 'Password reset email sent to $email';
  }

  @override
  String get enterEmail => 'Please enter your email';

  @override
  String get appearance => 'Appearance';

  @override
  String get light_theme => 'Light';

  @override
  String get dark_theme => 'Dark';

  @override
  String get system_theme => 'System';

  @override
  String get app_settings => 'App Settings';

  @override
  String get security_settings => 'Security Settings';

  @override
  String get biometric_lock => 'Biometric Lock';
}
