import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/database_service.dart';
import 'package:kameti/ui/theme/theme.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const Color _bg = AppColors.bg;
  static const Color _surface = AppColors.surface;
  static const Color _primary = AppColors.primary;
  static const Color _primaryDark = AppColors.primaryDark;
  static const Color _textPrimary = AppColors.textPrimary;
  static const Color _textSecondary = AppColors.textSecondary;

  final PageController _pageController = PageController();
  int _currentIndex = 0;

  final List<_OnboardingStep> _steps = const [
    _OnboardingStep(
      title: 'Welcome to Kameti',
      description:
          'Run your committee smoothly with one place for members, collections, and payout tracking.',
      icon: AppIcons.groups_rounded,
      accent: AppColors.primary,
      label: 'Overview',
      points: ['Structured committee flow', 'Smart status visibility'],
    ),
    _OnboardingStep(
      title: 'Create in Minutes',
      description:
          'Set amount, cycle, and member count, then share the join code with your group instantly.',
      icon: AppIcons.add_task_rounded,
      accent: AppColors.secondary,
      label: 'Setup',
      points: ['Fast configuration', 'Instant join-code sharing'],
    ),
    _OnboardingStep(
      title: 'Track Every Payment',
      description:
          'Mark paid and pending contributions quickly, and always know each cycle status clearly.',
      icon: AppIcons.payments_rounded,
      accent: AppColors.success,
      label: 'Payments',
      points: ['Daily/weekly/monthly support', 'Member-level transparency'],
    ),
    _OnboardingStep(
      title: 'Clear Payout Visibility',
      description:
          'Keep payout order transparent for everyone, with updates your members can trust.',
      icon: AppIcons.emoji_events_rounded,
      accent: AppColors.cFFF59E0B,
      label: 'Payouts',
      points: ['Predictable payout timeline', 'Trust through clarity'],
    ),
  ];

  bool get _isLastPage => _currentIndex == _steps.length - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _nextPage() async {
    if (_isLastPage) {
      _completeOnboarding(context);
      return;
    }

    await _pageController.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  Future<void> _previousPage() async {
    if (_currentIndex == 0) return;

    await _pageController.previousPage(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.cFFE9EEFC,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.cFFD8E2F8),
          ),
          child: Text(
            '${_currentIndex + 1}/${_steps.length}',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _primary,
            ),
          ),
        ),
        const Spacer(),
        TextButton(
          onPressed: () => _completeOnboarding(context),
          child: Text(
            'Skip',
            style: GoogleFonts.inter(
              color: _textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar() {
    return Row(
      children: List.generate(_steps.length, (index) {
        final bool active = index == _currentIndex;
        final bool passed = index < _currentIndex;
        final Color tone = _steps[_currentIndex].accent;

        return Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            margin: EdgeInsets.only(right: index == _steps.length - 1 ? 0 : 8),
            height: 6,
            decoration: BoxDecoration(
              color: active || passed ? tone : AppColors.cFFD7DEEE,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.24),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              AppIcons.auto_awesome_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome to Kameti',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Set up, track, and manage committee cycles with confidence.',
                  style: GoogleFonts.inter(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
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

  Widget _buildStepCard(_OnboardingStep step) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.cFFDDE6F7),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkBg.withOpacity(0.06),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: step.accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                step.label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: step.accent,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: step.accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(step.icon, size: 38, color: step.accent),
            ),
            const SizedBox(height: 20),
            Text(
              step.title,
              style: GoogleFonts.inter(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: _textPrimary,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              step.description,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: _textSecondary,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 14),
            ...step.points.map(
              (point) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      AppIcons.paid,
                      size: 14,
                      color: step.accent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        point,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.cFF475569,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            Row(
              children: [
                _buildMiniPoint(
                  icon: AppIcons.security_rounded,
                  text: 'Secure',
                  color: step.accent,
                ),
                const SizedBox(width: 10),
                _buildMiniPoint(
                  icon: AppIcons.sync,
                  text: 'Synced',
                  color: step.accent,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniPoint({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 6),
            Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _currentIndex == 0 ? null : _previousPage,
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.cFFC9D4EE),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              'Back',
              style: GoogleFonts.inter(
                color: AppColors.cFF475569,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _nextPage,
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: _isLastPage ? _primaryDark : _primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(
              _isLastPage ? 'Get Started' : 'Continue',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Column(
            children: [
              _buildTopBar(),
              const SizedBox(height: 8),
              _buildProgressBar(),
              const SizedBox(height: 12),
              _buildHero(),
              const SizedBox(height: 12),
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _steps.length,
                  onPageChanged: (index) {
                    setState(() => _currentIndex = index);
                  },
                  itemBuilder: (context, index) {
                    return _buildStepCard(_steps[index]);
                  },
                ),
              ),
              const SizedBox(height: 12),
              _buildBottomActions(),
            ],
          ),
        ),
      ),
    );
  }

  void _completeOnboarding(BuildContext context) {
    DatabaseService().setFirstLaunchComplete();
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
  }
}

class _OnboardingStep {
  final String title;
  final String description;
  final IconData icon;
  final Color accent;
  final String label;
  final List<String> points;

  const _OnboardingStep({
    required this.title,
    required this.description,
    required this.icon,
    required this.accent,
    required this.label,
    required this.points,
  });
}
