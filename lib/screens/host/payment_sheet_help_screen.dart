import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kameti/ui/theme/theme.dart';

class PaymentSheetHelpScreen extends StatefulWidget {
  final bool isFirstTime;

  const PaymentSheetHelpScreen({super.key, this.isFirstTime = false});

  @override
  State<PaymentSheetHelpScreen> createState() => _PaymentSheetHelpScreenState();
}

class _PaymentSheetHelpScreenState extends State<PaymentSheetHelpScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  static const Color _bg = AppColors.bg;
  static const Color _surface = AppColors.surface;
  static const Color _primary = AppColors.primary;
  static const Color _success = AppColors.success;
  static const Color _warning = AppColors.warning;
  static const Color _info = AppColors.info;
  static const Color _textPrimary = AppColors.textPrimary;
  static const Color _textSecondary = AppColors.textSecondary;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _sections.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    if (widget.isFirstTime) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('payment_sheet_help_seen', true);
    }
    if (mounted) Navigator.pop(context);
  }

  static final List<_HelpSection> _sections = [
    _HelpSection(
      icon: AppIcons.table_chart,
      iconColor: _primary,
      title: 'Payment Matrix',
      description:
          'The Payment Matrix is the main table that shows all members and their payment status for each date in the current cycle.',
      details: [
        _HelpDetail(
          icon: AppIcons.person_outline,
          text: 'Each row represents one member in your committee',
        ),
        _HelpDetail(
          icon: AppIcons.calendar_today_outlined,
          text: 'Each column represents a collection date (dd/MM format)',
        ),
        _HelpDetail(
          icon: AppIcons.paid,
          text: 'Cells show payment status: paid or unpaid',
        ),
      ],
    ),
    _HelpSection(
      icon: AppIcons.check_circle,
      iconColor: _success,
      title: 'Marking Payments',
      description:
          'Tap any cell in the matrix to toggle payment status for that member on that date.',
      details: [
        _HelpDetail(
          icon: AppIcons.check_circle,
          text: 'Green check = Payment marked as paid',
        ),
        _HelpDetail(
          icon: AppIcons.schedule_rounded,
          text: 'Empty cell = Payment not yet marked',
        ),
        _HelpDetail(
          icon: AppIcons.star_outline_rounded,
          text: 'Star icon = Payout day (member receives the collection)',
        ),
      ],
    ),
    _HelpSection(
      icon: AppIcons.star_rounded,
      iconColor: _warning,
      title: 'Payout Days',
      description:
          'Payout days are highlighted with a star. On these days, the collected money is given to the member whose turn it is.',
      details: [
        _HelpDetail(
          icon: AppIcons.star_rounded,
          text: 'The star appears on the member who receives the payout',
        ),
        _HelpDetail(
          icon: AppIcons.warning,
          text: 'Payout cells have an orange border to stand out',
        ),
        _HelpDetail(
          icon: AppIcons.person_outline,
          text: 'Payout order is based on each member\'s assigned slot (#)',
        ),
      ],
    ),
    _HelpSection(
      icon: AppIcons.check_circle_outline_rounded,
      iconColor: _success,
      title: 'Mark All Paid — All Members',
      description:
          'Use the "Mark All Paid for This Cycle" button below the cycle selector to mark all unpaid periods for every member at once.',
      details: [
        _HelpDetail(
          icon: AppIcons.check_circle_outline_rounded,
          text: 'Only marks unpaid, non-skipped cells in the current cycle',
        ),
        _HelpDetail(
          icon: AppIcons.info_outline,
          text: 'A confirmation dialog appears before marking',
        ),
        _HelpDetail(
          icon: AppIcons.check_circle,
          text: 'Skipped dates are never affected by bulk actions',
        ),
      ],
    ),
    _HelpSection(
      icon: AppIcons.person_outline,
      iconColor: _primary,
      title: 'Mark All Paid — Single Member',
      description:
          'Long-press (hold) on any member\'s name to mark all their unpaid periods as paid for the current cycle.',
      details: [
        _HelpDetail(
          icon: AppIcons.person_outline,
          text: 'Hold your finger on a member row to open the action sheet',
        ),
        _HelpDetail(
          icon: AppIcons.check_circle_outline_rounded,
          text: 'Tap "Mark All Paid for This Cycle" in the bottom sheet',
        ),
        _HelpDetail(
          icon: AppIcons.info_outline,
          text: 'Shows how many unpaid periods will be marked',
        ),
      ],
    ),
    _HelpSection(
      icon: AppIcons.block_rounded,
      iconColor: _warning,
      title: 'Skipping Dates',
      description:
          'If a collection date is skipped (e.g., holiday), long-press the date header to toggle it as skipped.',
      details: [
        _HelpDetail(
          icon: AppIcons.block_rounded,
          text: 'The block icon appears on skipped date headers',
        ),
        _HelpDetail(
          icon: AppIcons.warning,
          text: 'Skipped dates show in orange and are excluded from calculations',
        ),
        _HelpDetail(
          icon: AppIcons.info_outline,
          text: 'Long-press the date header again to unskip it',
        ),
      ],
    ),
    _HelpSection(
      icon: AppIcons.payout,
      iconColor: _primary,
      title: 'Cycle Overview',
      description:
          'The card at the top shows a quick summary of the current cycle: total paid, unpaid, and collected amount.',
      details: [
        _HelpDetail(
          icon: AppIcons.check_circle,
          text: 'Paid — Total number of marked payments across all members',
        ),
        _HelpDetail(
          icon: AppIcons.cancel,
          text: 'Unpaid — Remaining payments yet to be marked',
        ),
        _HelpDetail(
          icon: AppIcons.payout,
          text: 'Cycle Amt — Total amount collected in the current cycle',
        ),
      ],
    ),
    _HelpSection(
      icon: AppIcons.keyboard_arrow_down_rounded,
      iconColor: _info,
      title: 'Switching Cycles',
      description:
          'Use the cycle dropdown to view and manage payments for different payout cycles.',
      details: [
        _HelpDetail(
          icon: AppIcons.keyboard_arrow_down_rounded,
          text: 'Tap the dropdown to select any cycle',
        ),
        _HelpDetail(
          icon: AppIcons.calendar_today_outlined,
          text: 'Each cycle shows the date range it covers',
        ),
        _HelpDetail(
          icon: AppIcons.info_outline,
          text: 'Changes to one cycle do not affect other cycles',
        ),
      ],
    ),
    _HelpSection(
      icon: AppIcons.reminder,
      iconColor: _info,
      title: 'Send Reminders',
      description:
          'Send payment reminders to members who haven\'t paid yet. Tap "Show Details" then "Send Reminders".',
      details: [
        _HelpDetail(
          icon: AppIcons.reminder,
          text: 'Reminders are sent to members with unpaid periods',
        ),
        _HelpDetail(
          icon: AppIcons.info_outline,
          text: 'Use "Show Details" in the Cycle Overview card to access this',
        ),
      ],
    ),
    _HelpSection(
      icon: AppIcons.download_rounded,
      iconColor: _primary,
      title: 'Export & Sync',
      description:
          'Export your payment data or sync with the cloud from the top app bar.',
      details: [
        _HelpDetail(
          icon: AppIcons.download_rounded,
          text: 'Export — Download payment data as a file',
        ),
        _HelpDetail(
          icon: AppIcons.refresh,
          text: 'Refresh — Sync latest data from the cloud',
        ),
        _HelpDetail(
          icon: AppIcons.verified_user_rounded,
          text: 'Proofs — View and manage payment proof submissions',
        ),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(AppIcons.close, color: _textPrimary),
          onPressed: _finish,
        ),
        title: Text(
          widget.isFirstTime ? 'Welcome Guide' : 'Payment Sheet Help',
          style: GoogleFonts.inter(
            color: _textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Page indicator
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _sections.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: _currentPage == i ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == i
                        ? _primary
                        : AppColors.cFFD7E0F2,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
          ),

          // Page view
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: _sections.length,
              onPageChanged: (i) => setState(() => _currentPage = i),
              itemBuilder: (context, index) {
                final section = _sections[index];
                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Column(
                    children: [
                      // Icon circle
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: section.iconColor.withOpacity(0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: section.iconColor.withOpacity(0.25),
                          ),
                        ),
                        child: Icon(
                          section.icon,
                          size: 36,
                          color: section.iconColor,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Title
                      Text(
                        section.title,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: _textPrimary,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Description
                      Text(
                        section.description,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: _textSecondary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Details cards
                      ...section.details.map(
                        (detail) => Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.lightBorder),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.darkBg.withOpacity(0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: section.iconColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  detail.icon,
                                  size: 18,
                                  color: section.iconColor,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  detail.text,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    color: _textPrimary,
                                    fontWeight: FontWeight.w500,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          // Bottom button
          Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              12,
              24,
              MediaQuery.of(context).padding.bottom + 16,
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _nextPage,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _currentPage == _sections.length - 1
                      ? (widget.isFirstTime ? 'Get Started' : 'Done')
                      : 'Next',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HelpSection {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final List<_HelpDetail> details;

  const _HelpSection({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.details,
  });
}

class _HelpDetail {
  final IconData icon;
  final String text;

  const _HelpDetail({required this.icon, required this.text});
}
