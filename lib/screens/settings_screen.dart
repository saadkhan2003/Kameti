import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/biometric_service.dart';
import '../../services/localization_service.dart';
import '../../services/toast_service.dart';
import '../../services/currency_service.dart';
import '../../services/haptic_service.dart';
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
  String _defaultCurrency = CurrencyService.defaultCurrency;

  @override
  void initState() {
    super.initState();
    _loadBiometricSettings();
    _loadCurrencySettings();
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

  Future<void> _loadCurrencySettings() async {
    await CurrencyService().initialize();
    if (mounted) {
      setState(() {
        _defaultCurrency = CurrencyService().appDefaultCurrency;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyInfo = CurrencyService.getCurrencyInfo(_defaultCurrency);
    
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
                            HapticService.selectionTick();
                            if (mounted) {
                              ToastService.success(
                                context, 
                                value ? '$_biometricType lock enabled' : '$_biometricType lock disabled',
                              );
                            }
                          }
                        : null,
                    activeThumbColor: AppTheme.primaryColor,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Currency Section
            Text(
              'Default Currency',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Set the default currency for new committees',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
            const SizedBox(height: 16),

            InkWell(
              onTap: () => _showCurrencyPicker(),
              borderRadius: BorderRadius.circular(12),
              child: Container(
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
                      child: Text(
                        currencyInfo.flag,
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${currencyInfo.code} — ${currencyInfo.name}',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Symbol: ${currencyInfo.symbol}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCurrencyPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.85,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  const Icon(Icons.currency_exchange, color: AppTheme.primaryColor),
                  const SizedBox(width: 12),
                  Text(
                    'Select Default Currency',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Colors.white10, height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: CurrencyService.supportedCurrencies.length,
                itemBuilder: (context, index) {
                  final currency = CurrencyService.supportedCurrencies[index];
                  final isSelected = currency.code == _defaultCurrency;
                  return ListTile(
                    leading: Text(currency.flag, style: const TextStyle(fontSize: 24)),
                    title: Text(
                      '${currency.code} — ${currency.name}',
                      style: TextStyle(
                        color: isSelected ? AppTheme.primaryColor : Colors.white,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      'Symbol: ${currency.symbol}',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: AppTheme.primaryColor)
                        : null,
                    onTap: () async {
                      HapticService.selectionTick();
                      await CurrencyService().setAppDefaultCurrency(currency.code);
                      setState(() => _defaultCurrency = currency.code);
                      Navigator.pop(context);
                      if (mounted) {
                        ToastService.success(context, 'Default currency set to ${currency.code}');
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
