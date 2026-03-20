import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:kameti/ui/theme/theme.dart';

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  static const Color _bg = AppColors.bg;
  static const Color _surface = AppColors.surface;
  static const Color _primary = AppColors.primary;
  static const Color _success = AppColors.success;
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
          'Contact Us',
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
                  color: _primary.withOpacity(0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                const Icon(
                  AppIcons.support_agent_rounded,
                  size: 46,
                  color: Colors.white,
                ),
                const SizedBox(height: 10),
                Text(
                  'We\'re here to help!',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Reach out anytime — we usually reply within 24 hours',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withOpacity(0.28)),
                  ),
                  child: Text(
                    'Support window: Mon - Sat',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildTopStat(
                  icon: AppIcons.bolt_rounded,
                  label: 'Fast Reply',
                  value: '< 24h',
                  tone: _success,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildTopStat(
                  icon: AppIcons.language_rounded,
                  label: 'Languages',
                  value: 'EN / UR',
                  tone: _primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          _buildContactCard(
            icon: AppIcons.email_outlined,
            title: 'Email',
            subtitle: 'msaad.official6@gmail.com',
            badge: 'Preferred',
            badgeColor: _success,
            onTap: () => _launchEmail(),
          ),
          const SizedBox(height: 12),

          _buildContactCard(
            icon: AppIcons.email_outlined,
            title: 'Email',
            subtitle: 'farhanappdev@gmail.com',
            badge: 'Alternate',
            badgeColor: _primary,
            onTap: () => _launchAlternateEmail(),
          ),
          const SizedBox(height: 12),

          _buildContactCard(
            icon: AppIcons.phone_outlined,
            title: 'Phone',
            subtitle: '+92 321 8685488',
            badge: 'Direct',
            badgeColor: _primary,
            onTap: () => _launchPhone(),
          ),
          const SizedBox(height: 12),

          _buildContactCard(
            icon: AppIcons.chat_outlined,
            title: 'WhatsApp',
            subtitle: 'Chat with us',
            badge: 'Quick Chat',
            badgeColor: _success,
            onTap: () => _launchWhatsApp(),
          ),
          const SizedBox(height: 18),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.lightBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(AppIcons.help_outline_rounded, color: _primary),
                    const SizedBox(width: 8),
                    Text(
                      'Quick Help',
                      style: GoogleFonts.inter(
                        color: _textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildFaqItem(
                  'How to create a committee?',
                  'Tap the + button on the dashboard and fill in the details.',
                ),
                _buildFaqItem(
                  'How to add members?',
                  'Open a committee and tap "Add Member" button.',
                ),
                _buildFaqItem(
                  'How to record payments?',
                  'Open payment sheet, tap a cell and select payment status.',
                ),
                _buildFaqItem(
                  'How to share with members?',
                  'Use the "Share Code" button in committee details.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Center(
            child: Text(
              'Made with ❤️ in Pakistan',
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

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String badge,
    required Color badgeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.lightBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: _primary, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: _textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: _textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badge,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: badgeColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(AppIcons.chevron_right_rounded, color: _textSecondary),
          ],
        ),
      ),
    );
  }

  Widget _buildFaqItem(String question, String answer) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: GoogleFonts.inter(
              color: _textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            answer,
            style: GoogleFonts.inter(color: _textSecondary, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Future<void> _launchEmail() async {
    final uri = Uri.parse('mailto:msaad.official6@gmail.com');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchAlternateEmail() async {
    final uri = Uri.parse('mailto:farhanappdev@gmail.com');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchPhone() async {
    final uri = Uri.parse('tel:+923218685488');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _launchWhatsApp() async {
    final uri = Uri.parse('https://wa.me/923218685488');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
