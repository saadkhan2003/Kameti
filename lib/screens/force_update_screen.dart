import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/remote_config_service.dart';
import 'package:kameti/ui/theme/theme.dart';

/// Force Update Screen - Blocks app usage until user updates
class ForceUpdateScreen extends StatelessWidget {
  final UpdateStatus updateStatus;

  static const Color _bgTop = AppColors.bg;
  static const Color _bgBottom = AppColors.bgAlt;
  static const Color _surface = AppColors.surface;
  static const Color _primary = AppColors.primary;
  static const Color _textPrimary = AppColors.textPrimary;
  static const Color _textSecondary = AppColors.textSecondary;

  const ForceUpdateScreen({super.key, required this.updateStatus});

  Future<void> _openStore() async {
    final url = updateStatus.storeUrl ?? '';
    if (url.isEmpty) {
      print('Store URL not configured');
      return;
    }

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      print('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // Prevent back button (force user to update)
      onWillPop: () async => false,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [_bgTop, _bgBottom],
            ),
          ),
          child: SafeArea(
            child: Stack(
              children: [
                Positioned(
                  top: -90,
                  right: -40,
                  child: Container(
                    width: 230,
                    height: 230,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _primary.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Center(
                    child: SingleChildScrollView(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 420),
                        padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF0F172A,
                              ).withValues(alpha: 0.08),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 64,
                              height: 30,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: AppColors.cFFE9EEFC,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const Text(
                                'UPDATE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: _primary,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              width: 92,
                              height: 92,
                              decoration: BoxDecoration(
                                color: AppColors.cFFE9EEFC,
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: const Icon(
                                AppIcons.system_update_alt_rounded,
                                size: 46,
                                color: _primary,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              updateStatus.updateTitle ?? 'Update Required',
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                color: _textPrimary,
                                height: 1.1,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              updateStatus.updateMessage ??
                                  'Please update to the latest version to continue using the app.',
                              style: const TextStyle(
                                fontSize: 14,
                                color: _textSecondary,
                                height: 1.45,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 18),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.cFFF8FAFF,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppColors.cFFD0D9EE,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        AppIcons.phone_android_rounded,
                                        size: 16,
                                        color: AppColors.textMedium,
                                      ),
                                      const SizedBox(width: 8),
                                      const Expanded(
                                        child: Text(
                                          'Current Version',
                                          style: TextStyle(
                                            color: _textSecondary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        updateStatus.currentVersion,
                                        style: const TextStyle(
                                          color: _textPrimary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      const Icon(
                                        AppIcons.new_releases_rounded,
                                        size: 16,
                                        color: _primary,
                                      ),
                                      const SizedBox(width: 8),
                                      const Expanded(
                                        child: Text(
                                          'Required Version',
                                          style: TextStyle(
                                            color: _textSecondary,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        updateStatus.minimumVersion ?? 'N/A',
                                        style: const TextStyle(
                                          color: _primary,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
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
                                ),
                                onPressed: _openStore,
                                icon: const Icon(
                                  AppIcons.download_rounded,
                                  size: 20,
                                ),
                                label: const Text(
                                  'Update Now',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'A critical update is required before continuing.',
                              style: TextStyle(
                                fontSize: 12,
                                color: _textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
