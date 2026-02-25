import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';

/// Reusable stat card widget for displaying metrics
/// 
/// Example usage:
/// ```dart
/// StatCard(
///   icon: Icons.group_rounded,
///   value: '12',
///   label: 'Active',
///   backgroundColor: AppColors.pastelLavender,
///   iconColor: AppColors.primary,
/// )
/// ```
class StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color backgroundColor;
  final Color iconColor;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.backgroundColor,
    required this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: AppDecorations.borderRadiusLg,
            boxShadow: AppDecorations.shadowSm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontal stats row with multiple StatCards
class StatsRow extends StatelessWidget {
  final List<StatCardData> stats;

  const StatsRow({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: stats.asMap().entries.map((entry) {
        final index = entry.key;
        final stat = entry.value;
        return Row(
          children: [
            if (index > 0) const SizedBox(width: 12),
            StatCard(
              icon: stat.icon,
              value: stat.value,
              label: stat.label,
              backgroundColor: stat.backgroundColor,
              iconColor: stat.iconColor,
              onTap: stat.onTap,
            ),
          ].sublist(index > 0 ? 0 : 1),
        );
      }).expand((w) => [w]).toList(),
    );
  }
}

/// Data class for stat card configuration
class StatCardData {
  final IconData icon;
  final String value;
  final String label;
  final Color backgroundColor;
  final Color iconColor;
  final VoidCallback? onTap;

  const StatCardData({
    required this.icon,
    required this.value,
    required this.label,
    required this.backgroundColor,
    required this.iconColor,
    this.onTap,
  });
}
