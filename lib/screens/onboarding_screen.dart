import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:committee_app/core/theme/app_theme.dart';
import 'package:committee_app/services/database_service.dart';
import 'package:committee_app/screens/home_screen.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return IntroductionScreen(
      globalBackgroundColor: Colors.white,
      pages: [
        _buildPage(
          title: 'Welcome to Kameti',
          body:
              'Manage your committee payments with ease. Track collections, payouts, and member contributions all in one place.',
          icon: Icons.group_rounded,
          color: AppTheme.primaryColor,
        ),
        _buildPage(
          title: 'Create Kametis',
          body:
              'Set up daily, weekly, or monthly committees. Invite members with a simple code and start tracking.',
          icon: Icons.add_circle_outline_rounded,
          color: AppTheme.secondaryColor,
        ),
        _buildPage(
          title: 'Track Payments',
          body:
              'Mark payments with a single tap. See who paid, who owes, and export reports as PDF or CSV.',
          icon: Icons.payments_rounded,
          color: Colors.blue,
        ),
        _buildPage(
          title: 'Get Payout Updates',
          body:
              'Know exactly when each member receives their payout. Everything is organized and transparent.',
          icon: Icons.celebration_rounded,
          color: Colors.orange,
        ),
      ],
      showSkipButton: true,
      skip: Text(
        'Skip',
        style: GoogleFonts.inter(
          color: Colors.grey[600],
          fontWeight: FontWeight.w500,
        ),
      ),
      next: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.arrow_forward_rounded,
          color: AppTheme.primaryColor,
        ),
      ),
      done: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.primaryColor, AppTheme.primaryDark],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          'Get Started',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      onDone: () => _completeOnboarding(context),
      onSkip: () => _completeOnboarding(context),
      dotsDecorator: DotsDecorator(
        size: const Size(10, 10),
        activeSize: const Size(22, 10),
        activeColor: AppTheme.primaryColor,
        color: Colors.grey[300]!,
        activeShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(5),
        ),
      ),
      curve: Curves.easeInOut,
    );
  }

  PageViewModel _buildPage({
    required String title,
    required String body,
    required IconData icon,
    required Color color,
  }) {
    return PageViewModel(
      titleWidget: Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
          textAlign: TextAlign.center,
        ),
      ),
      bodyWidget: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Text(
          body,
          style: GoogleFonts.inter(
            fontSize: 16,
            color: Colors.grey[600],
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ),
      image: Center(
        child: Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.2), width: 1),
          ),
          child: Icon(icon, size: 80, color: color),
        ),
      ),
      decoration: const PageDecoration(
        pageColor: Colors.white,
        imagePadding: EdgeInsets.only(top: 80),
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
