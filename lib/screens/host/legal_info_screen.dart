import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:kameti/ui/theme/theme.dart';

class LegalInfoScreen extends StatefulWidget {
  const LegalInfoScreen({super.key});

  @override
  State<LegalInfoScreen> createState() => _LegalInfoScreenState();
}

class _LegalInfoScreenState extends State<LegalInfoScreen> {
  static const Color _bg = AppColors.bg;
  static const Color _surface = AppColors.surface;
  static const Color _primary = AppColors.primary;
  static const Color _success = AppColors.success;
  static const Color _warning = AppColors.warning;
  static const Color _textPrimary = AppColors.textPrimary;
  static const Color _textSecondary = AppColors.textSecondary;

  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _version = info.version);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'About & Legal',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.w800,
            color: _textPrimary,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        children: [
          Container(
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
            child: Column(
              children: [
                const Icon(
                  AppIcons.policy_rounded,
                  color: Colors.white,
                  size: 40,
                ),
                const SizedBox(height: 10),
                Text(
                  'Trust & Legal Center',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Everything about your rights, data and app terms',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: _buildTopStat(
                  icon: AppIcons.verified_user_rounded,
                  label: 'Privacy',
                  value: 'Protected',
                  tone: _success,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildTopStat(
                  icon: AppIcons.rule_folder_outlined,
                  label: 'Terms',
                  value: 'Transparent',
                  tone: _warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          _buildCard(
            icon: AppIcons.info_outline,
            title: 'App Information',
            children: [
              _buildInfoRow('App Name', 'Kameti - Committee Manager'),
              _buildInfoRow(
                'Version',
                _version.isEmpty ? 'Loading...' : _version,
              ),
              _buildInfoRow('Category', 'Finance'),
              _buildInfoRow('Developer', 'Saad Khan'),
            ],
          ),
          const SizedBox(height: 16),

          _buildCard(
            icon: AppIcons.gavel,
            title: 'Legal',
            children: [
              _buildLinkTile(
                icon: AppIcons.privacy_tip_outlined,
                title: 'Privacy Policy',
                onTap:
                    () => _showLegalPage(
                      context,
                      'Privacy Policy',
                      _privacyPolicy,
                    ),
              ),
              _buildLinkTile(
                icon: AppIcons.article_outlined,
                title: 'Terms of Service',
                onTap:
                    () => _showLegalPage(
                      context,
                      'Terms of Service',
                      _termsOfService,
                    ),
              ),
              _buildLinkTile(
                icon: AppIcons.security_outlined,
                title: 'Data Safety',
                onTap:
                    () => _showLegalPage(context, 'Data Safety', _dataSafety),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildCard(
            icon: AppIcons.favorite_outline,
            title: 'Credits',
            children: [
              _buildInfoRow('Framework', 'Flutter'),
              _buildInfoRow('Backend', 'Firebase'),
              _buildInfoRow('Made with', '❤️ in Pakistan'),
            ],
          ),
          const SizedBox(height: 24),

          Center(
            child: Text(
              '© 2024 Committee App. All rights reserved.',
              style: GoogleFonts.inter(color: _textSecondary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopStat({
    required IconData icon,
    required String label,
    required String value,
    required Color tone,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.lightBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: tone.withOpacity(0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: tone),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _textPrimary,
                  ),
                ),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: _textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: _primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, color: _primary, size: 17),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: _textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderMuted),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(color: _textSecondary)),
          Text(
            value,
            style: GoogleFonts.inter(
              color: _textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: _textSecondary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  color: _textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(AppIcons.chevron_right_rounded, color: _textSecondary),
          ],
        ),
      ),
    );
  }

  void _showLegalPage(BuildContext context, String title, String content) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => Scaffold(
              backgroundColor: _bg,
              appBar: AppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                title: Text(
                  title,
                  style: GoogleFonts.inter(
                    color: _textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.lightBorder),
                  ),
                  child: Text(
                    content,
                    style: GoogleFonts.inter(
                      color: _textSecondary,
                      height: 1.65,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ),
      ),
    );
  }
}

// Legal Content
const String _privacyPolicy = '''
Privacy Policy

Last updated: February 2026

Introduction
Committee - Payment Tracker respects your privacy. This Privacy Policy explains how we collect, use, and protect your information.

Information We Collect
• Email address (for authentication)
• Display name (optional)
• Committee data you create
• Payment records

How We Use Your Information
• Provide and maintain the app
• Sync your data across devices
• Improve our service

Data Storage
Your data is stored securely in Firebase Cloud Firestore with encrypted connections.

Data Sharing
We do NOT sell, share, or use your data for advertising.

Your Rights
• Access your personal data
• Delete your account and data
• Export your committee data

Contact
For questions, contact the developer through the app store listing.
''';

const String _termsOfService = '''
Terms of Service

Last updated: February 2026

1. Acceptance of Terms
By using Committee - Payment Tracker, you agree to these terms.

2. Use of Service
• You must be 13 or older
• You are responsible for your account
• Do not misuse the service

3. User Content
• You own your committee data
• You grant us license to store and sync it
• We don't claim ownership of your data

4. Limitations
• Service provided "as is"
• We are not liable for data loss
• Backup your important data

5. Termination
• You can delete your account anytime
• We may terminate for violations

6. Changes
We may update these terms. Continued use means acceptance.
''';

const String _dataSafety = '''
Data Safety Information

Data Collection
✓ Email address - For account management
✓ Display name - For personalization
✓ Committee data - For app functionality

Data Security
✓ All data encrypted in transit (HTTPS)
✓ Secure Firebase authentication
✓ No third-party data sharing

Data Deletion
You can delete all your data:
1. Go to Profile
2. Select "Delete Account"
3. Confirm deletion

Your data will be permanently removed within 30 days.

Third-Party Services
• Supabase Auth (authentication)
• Supabase Database (PostgreSQL)
• Analytics (usage statistics)

We do NOT:
✗ Sell your personal information
✗ Share data with advertisers
✗ Track your location
''';
