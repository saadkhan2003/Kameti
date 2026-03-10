import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/app_theme.dart';
import 'package:committee_app/ui/theme/theme.dart';

/// A beautiful, animated empty state widget with illustration-like icons
/// and call-to-action support.
///
/// Usage:
///   EmptyStateWidget(
///     icon: AppIcons.group_off_rounded,
///     title: 'No Committees Yet',
///     subtitle: 'Create your first committee to get started',
///     actionLabel: 'Create Committee',
///     onAction: () => ...,
///   )
class EmptyStateWidget extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? actionIcon;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
    this.actionIcon,
  });

  @override
  State<EmptyStateWidget> createState() => _EmptyStateWidgetState();
}

class _EmptyStateWidgetState extends State<EmptyStateWidget>
    with TickerProviderStateMixin {
  late final AnimationController _bounceController;
  late final AnimationController _fadeController;
  late final Animation<double> _bounceAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Floating bounce animation for the icon
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _bounceAnimation = Tween<double>(begin: -8, end: 8).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.easeInOutSine),
    );

    // Entrance fade/slide animation
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _bounceController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated floating icon with decorative rings
                AnimatedBuilder(
                  animation: _bounceAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _bounceAnimation.value),
                      child: child,
                    );
                  },
                  child: _buildIconIllustration(),
                ),
                const SizedBox(height: 32),
                // Title
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkBg,
                  ),
                ),
                const SizedBox(height: 8),
                // Subtitle
                Text(
                  widget.subtitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textMedium,
                    height: 1.4,
                  ),
                ),
                // Action button
                if (widget.actionLabel != null && widget.onAction != null) ...[
                  const SizedBox(height: 28),
                  ElevatedButton.icon(
                    onPressed: widget.onAction,
                    icon: Icon(
                      widget.actionIcon ?? AppIcons.add_rounded,
                      size: 20,
                    ),
                    label: Text(
                      widget.actionLabel!,
                      style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 14,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconIllustration() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer ring
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppTheme.primaryColor.withOpacity(0.08),
              width: 2,
            ),
          ),
        ),
        // Middle ring
        Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: AppTheme.primaryColor.withOpacity(0.15),
              width: 2,
            ),
          ),
        ),
        // Icon background
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.primaryColor.withOpacity(0.15),
                AppTheme.primaryDark.withOpacity(0.1),
              ],
            ),
          ),
          child: Icon(
            widget.icon,
            size: 36,
            color: AppTheme.primaryColor.withOpacity(0.7),
          ),
        ),
        // Small decorative dots
        Positioned(
          top: 10,
          right: 15,
          child: Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.secondaryColor.withOpacity(0.4),
            ),
          ),
        ),
        Positioned(
          bottom: 15,
          left: 10,
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryColor.withOpacity(0.3),
            ),
          ),
        ),
      ],
    );
  }
}
