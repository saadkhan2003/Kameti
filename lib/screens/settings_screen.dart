import 'package:committee_app/core/providers/theme_provider.dart';
import 'package:committee_app/core/theme/app_theme.dart';
import 'package:committee_app/services/biometric_service.dart';
import 'package:committee_app/services/localization_service.dart';
import 'package:committee_app/services/toast_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  String _biometricType = 'Biometric';
  String _appVersion = '';
  bool _isCheckingUpdate = false;

  @override
  void initState() {
    super.initState();
    _loadBiometricSettings();
    _loadAppVersion();
  }

  Future<void> _loadBiometricSettings() async {
    final isAvailable = await BiometricService.canCheckBiometrics();
    final isEnabled = await BiometricService.isBiometricLockEnabled();
    final types = await BiometricService.getAvailableBiometrics();

    if (mounted) {
      setState(() {
        _biometricAvailable = isAvailable;
        _biometricEnabled = isEnabled;
        _biometricType = BiometricService.getBiometricTypeName(types);
      });
    }
  }

  Future<void> _loadAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = packageInfo.version;
      });
    }
  }

  Future<void> _checkForUpdate() async {
    setState(() => _isCheckingUpdate = true);
    try {
      final info = await InAppUpdate.checkForUpdate();
      setState(() => _isCheckingUpdate = false);

      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        await InAppUpdate.performImmediateUpdate();
      } else {
        if (mounted) {
          ToastService.success(context, 'Your app is up to date');
        }
      }
    } catch (e) {
      setState(() => _isCheckingUpdate = false);
      if (mounted) {
        ToastService.warning(context, 'Could not check for updates');
      }
    }
  }

  Widget _buildThemeOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required ThemeMode themeMode,
  }) {
    final currentTheme = ref.watch(themeModeProvider);
    final isSelected = currentTheme == themeMode;

    return InkWell(
      onTap: () {
        ref.read(themeModeProvider.notifier).setThemeMode(themeMode);
        ToastService.success(context, 'Theme changed to $title');
      },
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primaryColor
                    : AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : AppTheme.primaryColor,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppTheme.primaryColor,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          'app_settings'.tr,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Theme Settings Section
            Text(
              'appearance'.tr,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildThemeOption(
                    icon: Icons.light_mode_rounded,
                    title: 'light_theme'.tr,
                    subtitle: 'Use light color scheme',
                    themeMode: ThemeMode.light,
                  ),
                  const Divider(height: 24),
                  _buildThemeOption(
                    icon: Icons.dark_mode_rounded,
                    title: 'dark_theme'.tr,
                    subtitle: 'Use dark color scheme',
                    themeMode: ThemeMode.dark,
                  ),
                  const Divider(height: 24),
                  _buildThemeOption(
                    icon: Icons.brightness_auto_rounded,
                    title: 'system_theme'.tr,
                    subtitle: 'Follow system settings',
                    themeMode: ThemeMode.system,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            Text(
              'security_settings'.tr,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _biometricType == 'Face ID'
                          ? Icons.face_rounded
                          : Icons.fingerprint_rounded,
                      color: AppTheme.primaryColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'biometric_lock'.tr,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _biometricAvailable
                              ? 'Require $_biometricType to unlock app'
                              : 'Not available on this device',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _biometricEnabled,
                    onChanged:
                        _biometricAvailable
                            ? (value) async {
                              if (value) {
                                final success =
                                    await BiometricService.authenticate(
                                      reason:
                                          'Confirm $_biometricType to enable lock',
                                    );
                                if (!success) {
                                  if (mounted) {
                                    ToastService.warning(
                                      context,
                                      'Authentication failed',
                                    );
                                  }
                                  return;
                                }
                              }
                              await BiometricService.setBiometricLockEnabled(
                                value,
                              );
                              setState(() => _biometricEnabled = value);
                              if (mounted) {
                                ToastService.success(
                                  context,
                                  value
                                      ? '$_biometricType lock enabled'
                                      : '$_biometricType lock disabled',
                                );
                              }
                            }
                            : null,
                    activeColor: AppTheme.primaryColor,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            Text(
              'App Update',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.system_update_rounded,
                      color: AppTheme.primaryColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Current Version: $_appVersion',
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Check for latest updates',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _isCheckingUpdate
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppTheme.primaryColor,
                          ),
                        ),
                      )
                      : TextButton(
                        onPressed: _checkForUpdate,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          backgroundColor: AppTheme.primaryColor.withOpacity(
                            0.1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Check',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
