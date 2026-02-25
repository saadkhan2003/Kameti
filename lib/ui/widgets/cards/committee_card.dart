import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_decorations.dart';

/// Reusable committee card widget
/// 
/// Example usage:
/// ```dart
/// CommitteeCard(
///   name: 'Monthly Savings',
///   amount: 5000,
///   frequency: 'Monthly',
///   memberCount: 12,
///   memberNames: ['Ali', 'Ahmed', 'Sara'],
///   code: 'ABC123',
///   onTap: () => navigateToDetail(),
///   onArchive: () => archiveCommittee(),
///   onDelete: () => deleteCommittee(),
/// )
/// ```
class CommitteeCard extends StatelessWidget {
  final String name;
  final double amount;
  final String frequency;
  final int memberCount;
  final List<String> memberNames;
  final String code;
  final VoidCallback? onTap;
  final VoidCallback? onArchive;
  final VoidCallback? onDelete;

  const CommitteeCard({
    super.key,
    required this.name,
    required this.amount,
    required this.frequency,
    required this.memberCount,
    this.memberNames = const [],
    required this.code,
    this.onTap,
    this.onArchive,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.darkCard,
        borderRadius: AppDecorations.borderRadiusLg,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppDecorations.borderRadiusLg,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Icon container
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.group_rounded,
                        color: AppColors.primary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Title and subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                '₹${amount.toStringAsFixed(0)}/month',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '• $frequency',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  color: Colors.grey[400],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Menu button
                    if (onArchive != null || onDelete != null)
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, color: Colors.grey[400]),
                        onSelected: (value) {
                          if (value == 'archive') onArchive?.call();
                          else if (value == 'delete') onDelete?.call();
                        },
                        itemBuilder: (context) => [
                          if (onArchive != null)
                            const PopupMenuItem(
                              value: 'archive',
                              child: Row(
                                children: [
                                  Icon(Icons.archive_outlined, size: 20),
                                  SizedBox(width: 8),
                                  Text('Archive'),
                                ],
                              ),
                            ),
                          if (onDelete != null)
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Delete', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    if (memberNames.isNotEmpty)
                      AvatarStack(names: memberNames),
                    if (memberNames.isNotEmpty)
                      const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '$memberCount members',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: Colors.grey[400],
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Code: $code',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.secondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Avatar stack showing member initials
class AvatarStack extends StatelessWidget {
  final List<String> names;
  final int maxDisplay;
  final double size;
  final double overlap;

  const AvatarStack({
    super.key,
    required this.names,
    this.maxDisplay = 4,
    this.size = 28.0,
    this.overlap = 10.0,
  });

  static const List<Color> _colors = [
    AppColors.primary,
    AppColors.secondary,
    AppColors.accent,
    AppColors.info,
  ];

  @override
  Widget build(BuildContext context) {
    final displayCount = names.length > maxDisplay ? maxDisplay : names.length;
    final remaining = names.length - displayCount;

    return SizedBox(
      width: (displayCount * (size - overlap)) + overlap + (remaining > 0 ? size - overlap : 0),
      height: size,
      child: Stack(
        children: [
          for (int i = 0; i < displayCount; i++)
            Positioned(
              left: i * (size - overlap),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: _colors[i % _colors.length],
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.darkCard, width: 2),
                ),
                child: Center(
                  child: Text(
                    names[i].isNotEmpty ? names[i][0].toUpperCase() : '?',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          if (remaining > 0)
            Positioned(
              left: displayCount * (size - overlap),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: Colors.grey,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.darkCard, width: 2),
                ),
                child: Center(
                  child: Text(
                    '+$remaining',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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
