import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:committee_app/ui/theme/theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const Color _bg = AppColors.bg;
  static const Color _surface = AppColors.surface;
  static const Color _primary = AppColors.primary;
  static const Color _success = AppColors.success;
  static const Color _warning = AppColors.warning;
  static const Color _textPrimary = AppColors.textPrimary;
  static const Color _textSecondary = AppColors.textSecondary;

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
          'Privacy Policy',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            color: _textPrimary,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          _buildHeader(),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildMetaChip(
                icon: AppIcons.lock_outline_rounded,
                label: 'Secure by default',
                color: _success,
              ),
              const SizedBox(width: 8),
              _buildMetaChip(
                icon: AppIcons.update_rounded,
                label: 'Updated Feb 2026',
                color: _primary,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildSection(
            'Introduction',
            'Kameti - Committee Manager ("we", "our", or "us") respects your privacy. '
                'This Privacy Policy explains how we collect, use, and protect your information '
                'when you use our mobile application.',
          ),
          _buildSection(
            'Information We Collect',
            '• Email address (for authentication)\n'
                '• Display name (optional)\n'
                '• Committee data you create\n'
                '• Member names and payment records\n'
                '• Payment dates and amounts\n'
                '• Device type and app version\n'
                '• Advertising ID (for personalized ads)',
          ),
          _buildSection(
            'How We Use Your Information',
            '• Provide and maintain the app service\n'
                '• Sync your data across devices\n'
                '• Send important notifications\n'
                '• Improve our app and user experience\n'
                '• Serve relevant advertisements through Google AdMob',
          ),
          _buildSection(
            'Data Storage',
            'Your data is stored securely using Supabase (an open-source Firebase alternative) '
                'and local device storage for offline access. All data transmission uses encrypted HTTPS connections.',
          ),
          _buildSection(
            'Advertising',
            'Kameti is a free app supported by advertising. We use Google AdMob to display ads, which may include:\n\n'
                '• App Open Ads — shown when you launch or resume the app\n'
                '• Native Ads — shown within the committee list\n\n'
                'Google AdMob may use your Advertising ID and device information to show you personalised ads based '
                'on your interests. You can opt out of personalised advertising in your device settings:\n'
                '• Android: Settings → Google → Ads → Opt out of Ads Personalisation\n'
                '• iOS: Settings → Privacy → Apple Advertising\n\n'
                'Google\'s privacy policy applies to ads shown by AdMob. Visit policies.google.com/privacy for details.',
          ),
          _buildSection(
            'Data Sharing',
            'We do NOT:\n'
                '• Sell your personal information\n'
                '• Share your committee data with third parties\n'
                '• Track your location\n\n'
                'We DO share limited, non-personal data with:\n'
                '• Google AdMob — Advertising ID and device info for ad delivery\n'
                '• Supabase — Your account and committee data for storage and sync',
          ),
          _buildSection(
            'Your Rights',
            'You have the right to:\n'
                '• Access your personal data\n'
                '• Delete your account and all data\n'
                '• Export your committee data\n'
                '• Opt out of personalised ads\n'
                '• Opt out of notifications',
          ),
          _buildSection(
            'Data Deletion',
            'To delete your data:\n'
                '1. Go to Profile in the app\n'
                '2. Select "Delete Account"\n'
                '3. Confirm deletion\n\n'
                'All your data will be permanently removed within 30 days.',
          ),
          _buildSection(
            'Third-Party Services',
            'We use the following third-party services:\n\n'
                '• Supabase — Authentication and database storage\n'
                '  supabase.com/privacy\n\n'
                '• Google Sign-In — Account authentication\n'
                '  policies.google.com/privacy\n\n'
                '• Google AdMob — In-app advertising\n'
                '  policies.google.com/privacy\n\n'
                'Each service operates under its own privacy policy.',
          ),
          _buildSection(
            'Children\'s Privacy',
            'Our app is not intended for children under 13. We do not knowingly collect data from children. '
                'Ads served through Google AdMob are configured for a general audience.',
          ),
          _buildSection(
            'Contact Us',
            'If you have questions about this Privacy Policy, contact us at:\n\n'
                'Email: msaad.official6@gmail.com',
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Last updated: February 2026',
              style: GoogleFonts.inter(color: _textSecondary, fontSize: 12),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildMetaChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.lightBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(icon, color: color, size: 14),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: _textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primary, AppColors.cFF5B6FD6],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.24),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              AppIcons.privacy_tip_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Privacy Policy',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Your privacy matters to us',
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13,
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

  Widget _buildSection(String title, String content) {
    final tone = _toneForSection(title);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: tone.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_iconForSection(title), color: tone, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    color: _textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: GoogleFonts.inter(
              color: _textSecondary,
              height: 1.65,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Color _toneForSection(String title) {
    if (title.contains('Data') || title.contains('Storage')) return _success;
    if (title.contains('Advertising') || title.contains('Third-Party'))
      return _warning;
    return _primary;
  }

  IconData _iconForSection(String title) {
    if (title.contains('Introduction')) return AppIcons.info_outline_rounded;
    if (title.contains('Information')) return AppIcons.badge_outlined;
    if (title.contains('Use')) return AppIcons.settings_suggest_rounded;
    if (title.contains('Storage')) return AppIcons.storage_rounded;
    if (title.contains('Advertising')) return AppIcons.campaign_outlined;
    if (title.contains('Sharing')) return AppIcons.share_outlined;
    if (title.contains('Rights')) return AppIcons.verified_user_outlined;
    if (title.contains('Deletion')) return AppIcons.delete_outline_rounded;
    if (title.contains('Third-Party')) return AppIcons.hub_outlined;
    if (title.contains('Children')) return AppIcons.child_care_outlined;
    if (title.contains('Contact')) return AppIcons.mail_outline_rounded;
    return AppIcons.article_outlined;
  }
}
