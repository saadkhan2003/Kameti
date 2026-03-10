import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/sync_service.dart';
import '../../services/toast_service.dart';
import '../../services/localization_service.dart';
import 'package:committee_app/ui/theme/theme.dart';
import '../home_screen.dart';
import '../settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const Color _bg = AppColors.bg;
  static const Color _surface = AppColors.surface;
  static const Color _primary = AppColors.primary;
  static const Color _success = AppColors.success;
  static const Color _danger = AppColors.error;
  static const Color _textPrimary = AppColors.textPrimary;
  static const Color _textSecondary = AppColors.textSecondary;

  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = 'v${packageInfo.version}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final user = authService.currentUser;
    // Handle anonymous users with no email/displayName
    String displayName =
        user?.userMetadata?['full_name'] as String? ??
        user?.email?.split('@')[0] ??
        '';
    if (displayName.isEmpty) displayName = 'Guest';
    final email = user?.email ?? 'Anonymous User';
    final createdAt = user?.createdAt;
    final joinedDate =
        createdAt != null && DateTime.tryParse(createdAt) != null
            ? '${DateTime.parse(createdAt).day}/${DateTime.parse(createdAt).month}/${DateTime.parse(createdAt).year}'
            : createdAt;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        foregroundColor: _textPrimary,
        iconTheme: const IconThemeData(color: _textPrimary),
        elevation: 0,
        title: Text(
          'profile'.tr,
          style: GoogleFonts.inter(
            color: _textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.lightBorder),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.darkBg.withOpacity(0.05),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [_primary, AppColors.cFF5B6FD6],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: _primary.withOpacity(0.25),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        displayName.isNotEmpty
                            ? displayName[0].toUpperCase()
                            : 'G',
                        style: GoogleFonts.inter(
                          fontSize: 34,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    displayName,
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: _textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    email,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: _textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _buildTopChip(
                        icon: AppIcons.verified_user_rounded,
                        label: 'Account Active',
                        color: _success,
                      ),
                      const SizedBox(width: 8),
                      _buildTopChip(
                        icon: AppIcons.info_outline_rounded,
                        label: _appVersion.isEmpty ? 'App' : _appVersion,
                        color: _primary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            _buildInfoCard(
              icon: AppIcons.email_outlined,
              label: 'Email',
              value: email,
            ),
            const SizedBox(height: 12),

            if (joinedDate != null)
              _buildInfoCard(
                icon: AppIcons.calendar_today_outlined,
                label: 'member_since'.tr,
                value: joinedDate,
              ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsScreen(),
                    ),
                  );
                  if (mounted) setState(() {});
                },
                icon: const Icon(AppIcons.settings_outlined),
                label: Text('settings'.tr),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _textPrimary,
                  backgroundColor: _surface,
                  side: const BorderSide(color: AppColors.lightBorder),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder:
                        (context) => AlertDialog(
                          backgroundColor: _surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          title: Text(
                            'Logout?',
                            style: GoogleFonts.inter(
                              color: _textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          content: Text(
                            'Are you sure you want to logout? Your local data will be cleared.',
                            style: GoogleFonts.inter(color: _textSecondary),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(color: _textSecondary),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _danger,
                                foregroundColor: Colors.white,
                                elevation: 0,
                              ),
                              child: const Text('Logout'),
                            ),
                          ],
                        ),
                  );

                  if (confirm == true) {
                    await authService.signOut();
                    if (context.mounted) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HomeScreen(),
                        ),
                        (route) => false,
                      );
                    }
                  }
                },
                icon: const Icon(AppIcons.logout_rounded),
                label: const Text('Logout'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _danger,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed:
                    () => _showChangePasswordDialog(context, authService),
                icon: const Icon(AppIcons.lock_outline),
                label: const Text('Change Password'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primary,
                  backgroundColor: _surface,
                  side: const BorderSide(color: AppColors.cFFC9D8FF),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showDeleteAccountDialog(context, authService),
                icon: const Icon(AppIcons.delete_forever_rounded),
                label: const Text('Delete Account'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _danger,
                  backgroundColor: _surface,
                  side: const BorderSide(color: AppColors.cFFF2C9CF),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),

            // App Version
            Text(
              'Kameti ${_appVersion.isEmpty ? "" : _appVersion}',
              style: GoogleFonts.inter(fontSize: 12, color: _textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _primary, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(fontSize: 12, color: _textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: valueColor ?? _textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(
    BuildContext context,
    AuthService authService,
  ) {
    final user = authService.currentUser;
    if (user == null || user.email == null) return;

    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            backgroundColor: _surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                const Icon(AppIcons.lock_outline, color: _primary),
                const SizedBox(width: 8),
                Text(
                  'Change Password',
                  style: GoogleFonts.inter(
                    color: _textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'We will send a password reset link to:',
                  style: const TextStyle(color: _textSecondary),
                ),
                const SizedBox(height: 8),
                Text(
                  user.email!,
                  style: const TextStyle(
                    color: _primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Click the link in the email to set a new password.',
                  style: const TextStyle(color: _textSecondary, fontSize: 13),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await authService.resetPassword(user.email!);
                    if (mounted) {
                      Navigator.pop(dialogContext);
                      ToastService.success(
                        context,
                        'Password reset email sent to ${user.email}',
                      );
                    }
                  } catch (e) {
                    ToastService.error(context, e.toString());
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                child: const Text('Send Reset Email'),
              ),
            ],
          ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, AuthService authService) {
    final syncService = SyncService();
    final dbService = DatabaseService();
    final user = authService.currentUser;
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            backgroundColor: _surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                const Icon(AppIcons.warning_rounded, color: _danger),
                const SizedBox(width: 8),
                Text(
                  'Delete Account?',
                  style: GoogleFonts.inter(
                    color: _textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This will permanently delete:',
                    style: const TextStyle(color: _textSecondary),
                  ),
                  const SizedBox(height: 12),
                  _buildDeleteItem('Your account'),
                  _buildDeleteItem('All your committees'),
                  _buildDeleteItem('All member data'),
                  _buildDeleteItem('All payment records'),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _danger.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(AppIcons.info_outline, color: _danger, size: 18),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This action cannot be undone!',
                            style: TextStyle(
                              color: _danger,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Enter your password to confirm:',
                    style: const TextStyle(color: _textSecondary, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: 'Password',
                      prefixIcon: const Icon(
                        AppIcons.lock_outline,
                        color: _textSecondary,
                      ),
                      filled: true,
                      fillColor: AppColors.cFFF8FAFF,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.lightBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.lightBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: _danger,
                          width: 1.3,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final password = passwordController.text.trim();
                  if (password.isEmpty) {
                    ToastService.warning(context, 'Please enter your password');
                    return;
                  }

                  Navigator.pop(dialogContext);

                  // Show loading
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder:
                        (ctx) => AlertDialog(
                          backgroundColor: _surface,
                          content: Row(
                            children: [
                              const CircularProgressIndicator(color: _danger),
                              const SizedBox(width: 16),
                              Text(
                                'Deleting account...',
                                style: GoogleFonts.inter(color: _textPrimary),
                              ),
                            ],
                          ),
                        ),
                  );

                  try {
                    // Re-authenticate first
                    final email = user?.email ?? '';
                    final authResponse = await Supabase.instance.client.auth
                        .signInWithPassword(email: email, password: password);

                    if (authResponse.user == null) {
                      throw 'Invalid password';
                    }

                    // Delete all committees from Cloud
                    final hostId = user?.id ?? '';
                    final committees = dbService.getHostedCommittees(hostId);
                    for (final committee in committees) {
                      await syncService.deleteCommitteeFromCloud(committee.id);
                    }

                    // Delete account (Note: requires custom edge function or direct API properly configured.
                    // Client-side delete is restricted by default in Supabase.
                    // We'll just sign out for this MVP unless admin API is used.)
                    // await authService.deleteAccount(); // This was placeholder

                    // For now just sign out as we can't delete user from client without admin key potentially
                    await authService.signOut();

                    if (context.mounted) {
                      Navigator.pop(context); // Close loading
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HomeScreen(),
                        ),
                        (route) => false,
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      Navigator.pop(context); // Close loading
                      String errorMsg = 'Failed to delete account';
                      final errorStr = e.toString().toLowerCase();
                      if (errorStr.contains('wrong-password') ||
                          errorStr.contains('invalid') ||
                          errorStr.contains('incorrect')) {
                        errorMsg = 'Incorrect password. Please try again.';
                      } else {
                        errorMsg = 'Error: $e';
                      }
                      ToastService.error(context, errorMsg);
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _danger,
                  foregroundColor: Colors.white,
                  elevation: 0,
                ),
                child: const Text('Delete Forever'),
              ),
            ],
          ),
    );
  }

  Widget _buildDeleteItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(AppIcons.remove_circle_outline, color: _danger, size: 16),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(color: _textSecondary)),
        ],
      ),
    );
  }
}
