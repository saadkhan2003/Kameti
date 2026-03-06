import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/remote_config_service.dart';
import '../../services/toast_service.dart';
import '../../utils/app_theme.dart';

class AdminConfigScreen extends StatefulWidget {
  const AdminConfigScreen({super.key});

  @override
  State<AdminConfigScreen> createState() => _AdminConfigScreenState();
}

class _AdminConfigScreenState extends State<AdminConfigScreen> {
  static const Color _bg = Color(0xFFF5F8FF);
  static const Color _surface = Colors.white;
  static const Color _primary = Color(0xFF3347A8);
  static const Color _primaryDark = Color(0xFF25348A);
  static const Color _danger = Color(0xFFDC2626);
  static const Color _success = Color(0xFF059669);
  static const Color _warning = Color(0xFFD97706);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);

  final _supabase = Supabase.instance.client;
  final _minVersionController = TextEditingController();
  final _updateTitleController = TextEditingController();
  final _updateMessageController = TextEditingController();
  final _playStoreUrlController = TextEditingController();

  bool _forceUpdateEnabled = false;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  @override
  void dispose() {
    _minVersionController.dispose();
    _updateTitleController.dispose();
    _updateMessageController.dispose();
    _playStoreUrlController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentConfig() async {
    setState(() => _isLoading = true);

    try {
      final response = await _supabase
          .from('app_config')
          .select('config_key, config_value');

      final config = {
        for (final item in response as List)
          item['config_key'] as String: item['config_value'] as String,
      };

      setState(() {
        _minVersionController.text = config['min_android_version'] ?? '1.0.0';
        _updateTitleController.text =
            config['update_message_title'] ?? 'Update Required';
        _updateMessageController.text =
            config['update_message_body'] ??
            'Please update to the latest version to continue using the app.';
        _playStoreUrlController.text = config['playstore_url'] ?? '';
        _forceUpdateEnabled =
            config['force_update_enabled']?.toLowerCase() == 'true';
        _isLoading = false;
      });
    } catch (error) {
      setState(() => _isLoading = false);
      if (mounted) {
        ToastService.error(context, 'Failed to load config: $error');
      }
    }
  }

  Future<void> _saveConfig() async {
    final confirmed = await _showConfirmationDialog();
    if (!confirmed) return;

    setState(() => _isSaving = true);

    try {
      await _updateConfigValue(
        'min_android_version',
        _minVersionController.text,
      );
      await _updateConfigValue(
        'force_update_enabled',
        _forceUpdateEnabled.toString(),
      );
      await _updateConfigValue(
        'update_message_title',
        _updateTitleController.text,
      );
      await _updateConfigValue(
        'update_message_body',
        _updateMessageController.text,
      );
      await _updateConfigValue('playstore_url', _playStoreUrlController.text);

      if (mounted) {
        ToastService.success(context, '✅ Config saved successfully!');
        await RemoteConfigService().refresh();
      }
    } catch (error) {
      if (mounted) {
        ToastService.error(context, 'Failed to save: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _updateConfigValue(String key, String value) async {
    await _supabase
        .from('app_config')
        .update({
          'config_value': value,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('config_key', key);
  }

  @override
  Widget build(BuildContext context) {
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
          'Remote Config Admin',
          style: GoogleFonts.inter(
            color: _textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: _textSecondary),
              onPressed: _loadCurrentConfig,
              tooltip: 'Refresh',
            ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeroCard(),
                    const SizedBox(height: 14),
                    _buildWarningBanner(),
                    const SizedBox(height: 14),
                    _buildSectionCard(
                      title: 'Force Update Control',
                      subtitle: 'Enable or disable mandatory app updates.',
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7FAFF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFDCE5F6)),
                        ),
                        child: SwitchListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 2,
                          ),
                          title: Text(
                            'Enable Force Update',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              color: _textPrimary,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            _forceUpdateEnabled
                                ? 'Blocking old versions from running'
                                : 'All versions allowed',
                            style: GoogleFonts.inter(
                              color: _forceUpdateEnabled ? _danger : _success,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          value: _forceUpdateEnabled,
                          activeColor: _danger,
                          onChanged: (value) {
                            setState(() => _forceUpdateEnabled = value);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildSectionCard(
                      title: 'Version Requirement',
                      subtitle: 'Set minimum supported Android app version.',
                      child: _buildTextField(
                        controller: _minVersionController,
                        label: 'Minimum Android Version',
                        hint: 'e.g., 2.0.0',
                        icon: Icons.phone_android_rounded,
                        helperText: 'Users below this version will be blocked.',
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildSectionCard(
                      title: 'Update Prompt Message',
                      subtitle:
                          'Customize the title and body shown to blocked users.',
                      child: Column(
                        children: [
                          _buildTextField(
                            controller: _updateTitleController,
                            label: 'Dialog Title',
                            hint: 'Update Required',
                            icon: Icons.title_rounded,
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            controller: _updateMessageController,
                            label: 'Dialog Message',
                            hint: 'Please update to the latest version...',
                            icon: Icons.message_rounded,
                            maxLines: 3,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildSectionCard(
                      title: 'Store Links',
                      subtitle: 'Where users are redirected to update the app.',
                      child: _buildTextField(
                        controller: _playStoreUrlController,
                        label: 'Play Store URL',
                        hint:
                            'https://play.google.com/store/apps/details?id=...',
                        icon: Icons.storefront_rounded,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildSectionCard(
                      title: 'Security Settings',
                      subtitle: 'Manage admin access credentials.',
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _showChangePinDialog,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF7FAFF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFDCE5F6)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: _primary.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(
                                  Icons.lock_reset_rounded,
                                  color: _primary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Change Admin PIN',
                                      style: GoogleFonts.inter(
                                        color: _textPrimary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      'Update your 4-digit admin access PIN',
                                      style: GoogleFonts.inter(
                                        color: _textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 14,
                                color: _textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                        onPressed: _isSaving ? null : _saveConfig,
                        icon:
                            _isSaving
                                ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                                : const Icon(Icons.save_rounded),
                        label: Text(
                          _isSaving ? 'Saving...' : 'Save Configuration',
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildInfoCard(),
                  ],
                ),
              ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3347A8), Color(0xFF4F46E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.24),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.tune_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Remote Config Control',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Manage force update policy, app version rules, and message content for all users in real time.',
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.92),
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _warning.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _warning.withOpacity(0.28)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: _warning, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Changes apply on next app launch for all users.',
              style: GoogleFonts.inter(
                color: _warning,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDE6F7)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              color: _textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(color: _textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? helperText,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: GoogleFonts.inter(color: _textPrimary),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helperText,
        prefixIcon: Icon(icon, color: _primary),
        labelStyle: GoogleFonts.inter(color: _textSecondary),
        hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
        helperStyle: GoogleFonts.inter(color: _textSecondary, fontSize: 11),
        filled: true,
        fillColor: const Color(0xFFF8FAFF),
        border: _inputBorder(),
        enabledBorder: _inputBorder(),
        focusedBorder: _inputBorder(color: _primary, width: 2),
      ),
    );
  }

  OutlineInputBorder _inputBorder({Color? color, double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(
        color: color ?? const Color(0xFFD7E1F5),
        width: width,
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFDDE6F7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, color: _primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'How It Works',
                style: GoogleFonts.inter(
                  color: _primaryDark,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildInfoPoint(
            'Enable toggle → old versions get blocked immediately.',
          ),
          _buildInfoPoint(
            'Set minimum version → e.g., 2.0.0 blocks all 1.x users.',
          ),
          _buildInfoPoint(
            'Disable toggle → allow all versions as emergency rollback.',
          ),
          _buildInfoPoint('Changes sync instantly, no app update needed.'),
        ],
      ),
    );
  }

  Widget _buildInfoPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.circle, size: 6, color: _textSecondary),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(color: _textSecondary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  void _showChangePinDialog() {
    showDialog(
      context: context,
      builder:
          (_) => _ChangePinDialog(
            supabase: _supabase,
            onPinChanged: () async {
              if (mounted) {
                await RemoteConfigService().refresh();
                ToastService.success(context, '✅ PIN changed successfully!');
              }
            },
          ),
    );
  }

  Future<bool> _showConfirmationDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              backgroundColor: _surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(
                    _forceUpdateEnabled
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle_rounded,
                    color: _forceUpdateEnabled ? _danger : _success,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Confirm Changes',
                    style: GoogleFonts.inter(
                      color: _textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Are you sure you want to save these changes?',
                    style: GoogleFonts.inter(
                      color: _textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (_forceUpdateEnabled ? _danger : _success)
                          .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: (_forceUpdateEnabled ? _danger : _success)
                            .withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      _forceUpdateEnabled
                          ? '⚠️ Force update enabled: users below v${_minVersionController.text} will be blocked.'
                          : '✅ Force update disabled: all versions are allowed.',
                      style: GoogleFonts.inter(
                        color: _forceUpdateEnabled ? _danger : _success,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.inter(color: _textSecondary),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _forceUpdateEnabled ? _danger : _primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Confirm & Save'),
                ),
              ],
            );
          },
        ) ??
        false;
  }
}

class _ChangePinDialog extends StatefulWidget {
  final SupabaseClient supabase;
  final Future<void> Function() onPinChanged;

  const _ChangePinDialog({required this.supabase, required this.onPinChanged});

  @override
  State<_ChangePinDialog> createState() => _ChangePinDialogState();
}

class _ChangePinDialogState extends State<_ChangePinDialog> {
  final _currentPinController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  bool _isChanging = false;

  @override
  void dispose() {
    _currentPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _changePin() async {
    if (_currentPinController.text.isEmpty ||
        _newPinController.text.isEmpty ||
        _confirmPinController.text.isEmpty) {
      ToastService.error(context, 'Please fill all PIN fields');
      return;
    }

    if (_currentPinController.text.length != 4 ||
        _newPinController.text.length != 4 ||
        _confirmPinController.text.length != 4) {
      ToastService.error(context, 'PIN must be exactly 4 digits');
      return;
    }

    if (_newPinController.text != _confirmPinController.text) {
      ToastService.error(context, 'New PIN and confirmation do not match');
      return;
    }

    if (_currentPinController.text == _newPinController.text) {
      ToastService.error(context, 'New PIN must be different from current PIN');
      return;
    }

    setState(() => _isChanging = true);

    try {
      final response =
          await widget.supabase
              .from('app_config')
              .select('config_value')
              .eq('config_key', 'admin_pin')
              .single();

      final currentPin = response['config_value'] as String;

      if (currentPin != _currentPinController.text) {
        if (mounted) {
          setState(() => _isChanging = false);
          ToastService.error(context, '❌ Current PIN is incorrect');
          _currentPinController.clear();
        }
        return;
      }

      await widget.supabase
          .from('app_config')
          .update({
            'config_value': _newPinController.text,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('config_key', 'admin_pin');

      if (mounted) {
        setState(() => _isChanging = false);
        Navigator.pop(context);
        await widget.onPinChanged();
      }
    } catch (error) {
      if (mounted) {
        setState(() => _isChanging = false);
        ToastService.error(context, 'Failed to change PIN: $error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.darkCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          const Icon(Icons.lock_reset_rounded, color: Colors.orange),
          const SizedBox(width: 10),
          Text(
            'Change Admin PIN',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter your current PIN and choose a new one.',
              style: GoogleFonts.inter(color: Colors.grey[400], fontSize: 13),
            ),
            const SizedBox(height: 18),
            _buildPinField(
              controller: _currentPinController,
              label: 'Current PIN',
              icon: Icons.lock_outline_rounded,
            ),
            const SizedBox(height: 14),
            _buildPinField(
              controller: _newPinController,
              label: 'New PIN',
              icon: Icons.lock_open_rounded,
            ),
            const SizedBox(height: 14),
            _buildPinField(
              controller: _confirmPinController,
              label: 'Confirm New PIN',
              icon: Icons.check_circle_outline_rounded,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isChanging ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
          onPressed: _isChanging ? null : _changePin,
          child:
              _isChanging
                  ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                  : const Text('Change PIN'),
        ),
      ],
    );
  }

  Widget _buildPinField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      obscureText: true,
      maxLength: 4,
      style: const TextStyle(
        color: Colors.white,
        letterSpacing: 8,
        fontSize: 18,
      ),
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        labelText: label,
        hintText: '••••',
        counterText: '',
        prefixIcon: Icon(icon, color: Colors.orange),
        filled: true,
        fillColor: AppTheme.darkSurface,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.orange, width: 2),
        ),
      ),
    );
  }
}
