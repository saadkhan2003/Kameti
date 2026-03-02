import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        backgroundColor: AppTheme.darkCard,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
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
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryColor, AppTheme.primaryDark],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        children: [
          Icon(Icons.privacy_tip, color: Colors.white, size: 40),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Privacy Policy',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Your privacy matters to us',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withAlpha(13)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(content, style: TextStyle(color: Colors.grey[300], height: 1.6)),
        ],
      ),
    );
  }
}
