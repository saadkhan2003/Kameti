import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/biometric_service.dart';
import '../services/localization_service.dart';
import '../services/toast_service.dart';
import 'package:kameti/ui/theme/theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const Color _bg = AppColors.bg;
  static const Color _surface = AppColors.surface;
  static const Color _primary = AppColors.primary;
  static const Color _primaryDark = AppColors.primaryDark;
  static const Color _textPrimary = AppColors.textPrimary;
  static const Color _textSecondary = AppColors.textSecondary;
  static const Color _success = AppColors.success;
  static const Color _muted = AppColors.mutedSurface;

  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  String _biometricType = 'Biometric';

  @override
  void initState() {
    super.initState();
    _loadBiometricSettings();
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

  Future<void> _onBiometricToggle(bool value) async {
    if (!_biometricAvailable) return;

    if (value) {
      final success = await BiometricService.authenticate(
        reason: 'Confirm $_biometricType to enable lock',
      );
      if (!success) {
        if (mounted) {
          ToastService.warning(context, 'Authentication failed');
        }
        return;
      }
    }

    await BiometricService.setBiometricLockEnabled(value);
    if (!mounted) return;

    setState(() => _biometricEnabled = value);
    ToastService.success(
      context,
      value ? '$_biometricType lock enabled' : '$_biometricType lock disabled',
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool faceMode = _biometricType == 'Face ID';

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopBar(context),
              const SizedBox(height: 14),
              _buildHero(faceMode),
              const SizedBox(height: 14),
              _buildSectionLabel('security_settings'.tr),
              const SizedBox(height: 10),
              _buildBiometricCard(faceMode),
              const SizedBox(height: 12),
              _buildInfoCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cFFDDE5F6),
          ),
          child: IconButton(
            icon: const Icon(
              AppIcons.arrow_back_ios_new_rounded,
              size: 18,
              color: _textPrimary,
            ),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'app_settings'.tr,
            style: GoogleFonts.inter(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: _textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHero(bool faceMode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.24),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              faceMode
                  ? AppIcons.face_retouching_natural_rounded
                  : AppIcons.fingerprint_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _biometricAvailable
                      ? '$_biometricType protection available'
                      : 'Biometric lock unavailable',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  _biometricAvailable
                      ? 'Use your $_biometricType to protect app access and secure sensitive actions.'
                      : 'Your device currently does not support biometric authentication.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    height: 1.45,
                    color: Colors.white.withOpacity(0.92),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: _textSecondary,
        letterSpacing: 0.3,
      ),
    );
  }

  Widget _buildBiometricCard(bool faceMode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.cFFD9E3F6),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkBg.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.cFFE9EEFC,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              faceMode ? AppIcons.face_rounded : AppIcons.fingerprint_rounded,
              size: 20,
              color: _primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'biometric_lock'.tr,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _biometricAvailable
                      ? 'Require $_biometricType to unlock app'
                      : 'Not available on this device',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: _textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _biometricEnabled ? AppColors.cFFECFDF3 : _muted,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color:
                          _biometricEnabled
                              ? _success.withOpacity(0.25)
                              : AppColors.cFFD7DFEE,
                    ),
                  ),
                  child: Text(
                    _biometricEnabled ? 'Enabled' : 'Disabled',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _biometricEnabled ? _success : _textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _biometricEnabled,
            onChanged: _biometricAvailable ? _onBiometricToggle : null,
            activeColor: _primaryDark,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cFFF8FAFF,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.lightBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              AppIcons.info_outline_rounded,
              size: 16,
              color: _textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Biometric settings are applied immediately on app lock and resume.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: _textSecondary,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
