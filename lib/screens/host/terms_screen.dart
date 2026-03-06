import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  static const Color _bg = Color(0xFFF7F8FC);
  static const Color _surface = Colors.white;
  static const Color _primary = Color(0xFF3347A8);
  static const Color _success = Color(0xFF059669);
  static const Color _warning = Color(0xFFD97706);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);

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
          'Terms & Conditions',
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
                icon: Icons.rule_rounded,
                label: 'Binding Terms',
                color: _warning,
              ),
              const SizedBox(width: 8),
              _buildMetaChip(
                icon: Icons.update_rounded,
                label: 'Updated Dec 2025',
                color: _primary,
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildSection(
            '1. Acceptance of Terms',
            'By downloading, installing, or using Kameti - Committee Manager ("the App"), '
                'you agree to be bound by these Terms and Conditions. If you do not agree to these terms, '
                'please do not use the App.',
          ),
          _buildSection(
            '2. Description of Service',
            'Kameti is a mobile application designed to help users manage rotating savings committees (ROSCA). '
                'The app allows hosts to create committees, add members, track payments, and share committee information.',
          ),
          _buildSection(
            '3. User Accounts',
            '• You must be at least 13 years old to use this App\n'
                '• You are responsible for maintaining the security of your account\n'
                '• You must provide accurate information during registration\n'
                '• You are responsible for all activities under your account',
          ),
          _buildSection(
            '4. User Responsibilities',
            '• Use the App only for lawful purposes\n'
                '• Do not attempt to gain unauthorized access\n'
                '• Do not upload harmful or malicious content\n'
                '• Respect the privacy of other users\n'
                '• Keep your login credentials secure',
          ),
          _buildSection(
            '5. Data and Privacy',
            '• You own your committee data\n'
                '• We store your data securely in the cloud\n'
                '• We do not sell or share your data with third parties\n'
                '• Please review our Privacy Policy for more details',
          ),
          _buildSection(
            '6. Intellectual Property',
            'The App, including its design, features, and content, is the intellectual property of the developer. '
                'You may not copy, modify, distribute, or create derivative works without permission.',
          ),
          _buildSection(
            '7. Disclaimer of Warranties',
            'The App is provided "AS IS" without warranties of any kind. We do not guarantee:\n'
                '• Uninterrupted or error-free service\n'
                '• Accuracy of calculations or data\n'
                '• Security against all possible threats\n\n'
                'You use the App at your own risk.',
          ),
          _buildSection(
            '8. Limitation of Liability',
            'We are not liable for:\n'
                '• Loss of data or information\n'
                '• Financial losses from using the App\n'
                '• Disputes between committee members\n'
                '• Any indirect or consequential damages',
          ),
          _buildSection(
            '9. Termination',
            '• You may stop using the App at any time\n'
                '• You may delete your account from the Profile section\n'
                '• We may terminate accounts for violations of these terms\n'
                '• Upon termination, your data will be deleted within 30 days',
          ),
          _buildSection(
            '10. Changes to Terms',
            'We may update these Terms and Conditions from time to time. Continued use of the App '
                'after changes constitutes acceptance of the new terms. We will notify users of significant changes.',
          ),
          _buildSection(
            '11. Governing Law',
            'These Terms shall be governed by and construed in accordance with the laws of Pakistan. '
                'Any disputes shall be resolved through appropriate legal channels.',
          ),
          _buildSection(
            '12. Contact Information',
            'For questions about these Terms, contact us at:\n\n'
                'Email: msaad.official6@gmail.com\n'
                'Phone: +92 321 8685488',
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Last updated: December 2025',
              style: GoogleFonts.inter(color: _textSecondary, fontSize: 12),
            ),
          ),
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
          border: Border.all(color: const Color(0xFFDCE4F7)),
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
          colors: [_primary, Color(0xFF5B6FD6)],
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
              Icons.article_rounded,
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
                  'Terms & Conditions',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Please read carefully',
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
        border: Border.all(color: const Color(0xFFDCE4F7)),
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
    if (title.startsWith('7') || title.startsWith('8')) return _warning;
    if (title.startsWith('5') || title.startsWith('9')) return _success;
    return _primary;
  }

  IconData _iconForSection(String title) {
    if (title.startsWith('1')) return Icons.how_to_reg_outlined;
    if (title.startsWith('2')) return Icons.description_outlined;
    if (title.startsWith('3')) return Icons.person_outline_rounded;
    if (title.startsWith('4')) return Icons.rule_outlined;
    if (title.startsWith('5')) return Icons.privacy_tip_outlined;
    if (title.startsWith('6')) return Icons.copyright_outlined;
    if (title.startsWith('7')) return Icons.warning_amber_rounded;
    if (title.startsWith('8')) return Icons.gavel_rounded;
    if (title.startsWith('9')) return Icons.block_rounded;
    if (title.startsWith('10')) return Icons.update_rounded;
    if (title.startsWith('11')) return Icons.balance_rounded;
    if (title.startsWith('12')) return Icons.contact_mail_outlined;
    return Icons.article_outlined;
  }
}
