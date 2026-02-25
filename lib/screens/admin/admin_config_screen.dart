import 'package:flutter/material.dart';
import '../../services/remote_config_service.dart';
import '../../services/toast_service.dart';
import '../../utils/app_theme.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Admin Panel for Remote Config Management
/// Allows updating force update settings without SQL
class AdminConfigScreen extends StatefulWidget {
  const AdminConfigScreen({super.key});

  @override
  State<AdminConfigScreen> createState() => _AdminConfigScreenState();
}

class _AdminConfigScreenState extends State<AdminConfigScreen> {
  final _supabase = Supabase.instance.client;
  final _minVersionController = TextEditingController();
  final _updateTitleController = TextEditingController();
  final _updateMessageController = TextEditingController();
  final _playStoreUrlController = TextEditingController();
  
  // PIN change controllers
  final _currentPinController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  
  bool _forceUpdateEnabled = false;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isChangingPin = false;

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
    _currentPinController.dispose();
    _newPinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentConfig() async {
    setState(() => _isLoading = true);
    
    try {
      final response = await _supabase
          .from('app_config')
          .select('config_key, config_value');

      final config = {
        for (var item in response as List)
          item['config_key'] as String: item['config_value'] as String
      };

      setState(() {
        _minVersionController.text = config['min_android_version'] ?? '1.0.0';
        _updateTitleController.text = config['update_message_title'] ?? 'Update Required';
        _updateMessageController.text = config['update_message_body'] ?? 
            'Please update to the latest version to continue using the app.';
        _playStoreUrlController.text = config['playstore_url'] ?? '';
        _forceUpdateEnabled = config['force_update_enabled']?.toLowerCase() == 'true';
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ToastService.error(context, 'Failed to load config: $e');
      }
    }
  }

  Future<void> _saveConfig() async {
    // Show confirmation dialog first
    final confirmed = await _showConfirmationDialog();
    if (!confirmed) return;

    setState(() => _isSaving = true);

    try {
      // Update all config values
      await _updateConfigValue('min_android_version', _minVersionController.text);
      await _updateConfigValue('force_update_enabled', _forceUpdateEnabled.toString());
      await _updateConfigValue('update_message_title', _updateTitleController.text);
      await _updateConfigValue('update_message_body', _updateMessageController.text);
      await _updateConfigValue('playstore_url', _playStoreUrlController.text);

      setState(() => _isSaving = false);
      
      if (mounted) {
        ToastService.success(context, '✅ Config saved successfully!');
        
        // Refresh remote config
        await RemoteConfigService().refresh();
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ToastService.error(context, 'Failed to save: $e');
      }
    }
  }

  Future<void> _updateConfigValue(String key, String value) async {
    await _supabase
        .from('app_config')
        .update({'config_value': value, 'updated_at': DateTime.now().toIso8601String()})
        .eq('config_key', key);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: AppTheme.darkCard,
        title: const Text('Admin: Remote Config'),
        actions: _isLoading
            ? null
            : [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadCurrentConfig,
                  tooltip: 'Refresh',
                ),
              ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Warning Banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.orange[300]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Changes take effect immediately for all users on next app launch.',
                            style: TextStyle(color: Colors.orange[200]),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Force Update Toggle
                  _buildSectionTitle('Force Update Control'),
                  Card(
                    color: AppTheme.darkCard,
                    child: SwitchListTile(
                      title: const Text('Enable Force Update'),
                      subtitle: Text(
                        _forceUpdateEnabled 
                            ? 'Blocking old versions from running' 
                            : 'All versions allowed',
                        style: TextStyle(
                          color: _forceUpdateEnabled ? Colors.red[300] : Colors.green[300],
                        ),
                      ),
                      value: _forceUpdateEnabled,
                      activeColor: Colors.red,
                      onChanged: (value) {
                        setState(() => _forceUpdateEnabled = value);
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Minimum Version
                  _buildSectionTitle('Version Requirement'),
                  _buildTextField(
                    controller: _minVersionController,
                    label: 'Minimum Android Version',
                    hint: 'e.g., 2.0.0',
                    icon: Icons.phone_android,
                    helperText: 'Users below this version will be blocked',
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Update Message
                  _buildSectionTitle('Update Prompt Message'),
                  _buildTextField(
                    controller: _updateTitleController,
                    label: 'Dialog Title',
                    hint: 'Update Required',
                    icon: Icons.title,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    controller: _updateMessageController,
                    label: 'Dialog Message',
                    hint: 'Please update to the latest version...',
                    icon: Icons.message,
                    maxLines: 3,
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Play Store URL
                  _buildSectionTitle('Store Links'),
                  _buildTextField(
                    controller: _playStoreUrlController,
                    label: 'Play Store URL',
                    hint: 'https://play.google.com/store/apps/details?id=...',
                    icon: Icons.store,
                  ),
                  const SizedBox(height: 24),
                  const Divider(color: Colors.white10),
                  const SizedBox(height: 24),
                  
                  // Security Settings - PIN Change Button
                  _buildSectionTitle('Security Settings'),
                  Card(
                    color: AppTheme.darkCard,
                    child: ListTile(
                      leading: Icon(Icons.lock_outline, color: AppTheme.primaryColor),
                      title: const Text(
                        'Change Admin PIN',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'Update your 4-digit admin access PIN',
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                      trailing: Icon(Icons.arrow_forward_ios, color: Colors.grey[600], size: 16),
                      onTap: _showChangePinDialog,
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isSaving ? null : _saveConfig,
                      child: _isSaving
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Save Configuration',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Info Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.darkCard,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[800]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue[300], size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'How It Works',
                              style: TextStyle(
                                color: Colors.blue[300],
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildInfoPoint('Enable toggle → Old versions get blocked immediately'),
                        _buildInfoPoint('Set minimum version → e.g., 2.0.0 blocks all v1.x users'),
                        _buildInfoPoint('Disable toggle → Allow all versions (emergency rollback)'),
                        _buildInfoPoint('Changes sync instantly → No app update needed'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
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
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helperText,
        prefixIcon: Icon(icon, color: AppTheme.primaryColor),
        filled: true,
        fillColor: AppTheme.darkCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[700]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[700]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
      ),
    );
  }

  Widget _buildInfoPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(color: Colors.grey[400])),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinField({
    required TextEditingController controller,
    required String label,
    required String hint,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      obscureText: true,
      maxLength: 4,
      style: const TextStyle(color: Colors.white, letterSpacing: 8, fontSize: 18),
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        counterText: '',
        prefixIcon: const Icon(Icons.pin, color: Colors.orange),
        filled: true,
        fillColor: AppTheme.darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[700]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[700]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.orange, width: 2),
        ),
      ),
    );
  }

  void _showChangePinDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => _ChangePinDialog(
        supabase: _supabase,
        onPinChanged: () async {
          // Use the screen context, not the dialog context
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
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkCard,
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.orange[300]),
            const SizedBox(width: 12),
            const Text('Confirm Changes'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to save these changes?',
              style: TextStyle(color: Colors.grey[300], fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (_forceUpdateEnabled) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.block, color: Colors.red[300], size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Force Update: ENABLED',
                          style: TextStyle(
                            color: Colors.red[300],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '⚠️ Users below v${_minVersionController.text} will be blocked immediately',
                      style: TextStyle(color: Colors.red[200], fontSize: 12),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green[300], size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Force Update: DISABLED',
                      style: TextStyle(
                        color: Colors.green[300],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Changes will apply to all users on their next app launch.',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _forceUpdateEnabled ? Colors.red : AppTheme.primaryColor,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm & Save'),
          ),
        ],
      ),
    ) ?? false;
  }
}

// Separate dialog widget for changing PIN
class _ChangePinDialog extends StatefulWidget {
  final SupabaseClient supabase;
  final Future<void> Function() onPinChanged;

  const _ChangePinDialog({
    required this.supabase,
    required this.onPinChanged,
  });

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
    // Validate inputs
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
      // Verify current PIN
      final response = await widget.supabase
          .from('app_config')
          .select('config_value')
          .eq('config_key', 'admin_pin')
          .single();

      final currentPin = response['config_value'] as String;

      if (currentPin != _currentPinController.text) {
        setState(() => _isChanging = false);
        ToastService.error(context, '❌ Current PIN is incorrect');
        _currentPinController.clear();
        return;
      }

      // Update to new PIN
      await widget.supabase
          .from('app_config')
          .update({'config_value': _newPinController.text, 'updated_at': DateTime.now().toIso8601String()})
          .eq('config_key', 'admin_pin');

      setState(() => _isChanging = false);

      if (mounted) {
        // Close dialog first
        Navigator.pop(context);
        // Then trigger callback (which will show toast in parent screen)
        await widget.onPinChanged();
      }
    } catch (e) {
      setState(() => _isChanging = false);
      if (mounted) {
        ToastService.error(context, 'Failed to change PIN: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppTheme.darkCard,
      title: Row(
        children: [
          Icon(Icons.lock_reset, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          const Text('Change Admin PIN'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter your current PIN and choose a new one',
              style: TextStyle(color: Colors.grey[400], fontSize: 13),
            ),
            const SizedBox(height: 20),
            _buildPinField(
              controller: _currentPinController,
              label: 'Current PIN',
              icon: Icons.lock_outline,
            ),
            const SizedBox(height: 16),
            _buildPinField(
              controller: _newPinController,
              label: 'New PIN',
              icon: Icons.lock_open,
            ),
            const SizedBox(height: 16),
            _buildPinField(
              controller: _confirmPinController,
              label: 'Confirm New PIN',
              icon: Icons.check_circle_outline,
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
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
          ),
          onPressed: _isChanging ? null : _changePin,
          child: _isChanging
              ? const SizedBox(
                  height: 20,
                  width: 20,
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
      style: const TextStyle(color: Colors.white, letterSpacing: 8, fontSize: 18),
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        labelText: label,
        hintText: '••••',
        counterText: '',
        prefixIcon: Icon(icon, color: Colors.orange),
        filled: true,
        fillColor: AppTheme.darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.orange, width: 2),
        ),
      ),
    );
  }
}
