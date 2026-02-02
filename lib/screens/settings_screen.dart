import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/biometric_service.dart';
import '../../services/localization_service.dart';
import '../../services/toast_service.dart';
import '../../utils/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('app_settings'.tr),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Security Section
            Text(
              'security_settings'.tr,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            
            // Biometric Lock Toggle
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.darkCard,
                borderRadius: BorderRadius.circular(12),
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
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
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
                    onChanged: _biometricAvailable 
                        ? (value) async {
                            if (value) {
                              // Test biometric first before enabling
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
                            setState(() => _biometricEnabled = value);
                            if (mounted) {
                              ToastService.success(
                                context, 
                                value ? '$_biometricType lock enabled' : '$_biometricType lock disabled',
                              );
                            }
                          }
                        : null,
                    activeColor: AppTheme.primaryColor,
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
