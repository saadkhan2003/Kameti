import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../utils/app_theme.dart';
import 'package:kameti/ui/theme/theme.dart';

/// Represents a data conflict between local and cloud versions
class SyncConflict {
  final String entityType; // "committee", "member", "payment"
  final String entityName;
  final String fieldName;
  final String localValue;
  final String cloudValue;
  final DateTime? localTimestamp;
  final DateTime? cloudTimestamp;
  final VoidCallback onKeepLocal;
  final VoidCallback onKeepCloud;

  SyncConflict({
    required this.entityType,
    required this.entityName,
    required this.fieldName,
    required this.localValue,
    required this.cloudValue,
    this.localTimestamp,
    this.cloudTimestamp,
    required this.onKeepLocal,
    required this.onKeepCloud,
  });
}

/// Shows a conflict resolution bottom sheet to the user.
class ConflictResolutionDialog {
  static Future<void> show(BuildContext context, SyncConflict conflict) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ConflictSheet(conflict: conflict),
    );
  }

  /// Show multiple conflicts in sequence
  static Future<void> showAll(
      BuildContext context, List<SyncConflict> conflicts) async {
    for (final conflict in conflicts) {
      if (!context.mounted) return;
      await show(context, conflict);
    }
  }
}

class _ConflictSheet extends StatelessWidget {
  final SyncConflict conflict;

  const _ConflictSheet({required this.conflict});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.darkCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: Colors.grey[700],
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.cFFFFB74D.withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.cFFFFB74D.withAlpha(60),
                        ),
                      ),
                      child: const Icon(
                        AppIcons.compare_arrows_rounded,
                        color: AppColors.cFFFFB74D,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sync Conflict',
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '${conflict.entityType} • ${conflict.entityName}',
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: Colors.grey[400],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Description
                Text(
                  'The "${conflict.fieldName}" was changed on both this device and another. Choose which version to keep:',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Colors.grey[300],
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 20),

                // Comparison cards
                Row(
                  children: [
                    Expanded(
                      child: _buildVersionCard(
                        title: 'This Device',
                        icon: AppIcons.phone_android_rounded,
                        value: conflict.localValue,
                        timestamp: conflict.localTimestamp,
                        color: AppColors.cFF448AFF,
                        onTap: () {
                          conflict.onKeepLocal();
                          Navigator.pop(context);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildVersionCard(
                        title: 'Cloud',
                        icon: AppIcons.cloud_rounded,
                        value: conflict.cloudValue,
                        timestamp: conflict.cloudTimestamp,
                        color: AppColors.cFF00C853,
                        onTap: () {
                          conflict.onKeepCloud();
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Or divider
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey[700])),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'or',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ),
                    Expanded(child: Divider(color: Colors.grey[700])),
                  ],
                ),

                const SizedBox(height: 16),

                // Keep latest button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // Auto-resolve: keep the most recent one
                      final localTime = conflict.localTimestamp ?? DateTime(2000);
                      final cloudTime = conflict.cloudTimestamp ?? DateTime(2000);
                      if (localTime.isAfter(cloudTime)) {
                        conflict.onKeepLocal();
                      } else {
                        conflict.onKeepCloud();
                      }
                      Navigator.pop(context);
                    },
                    icon: const Icon(AppIcons.auto_fix_high_rounded, size: 18),
                    label: const Text('Keep Most Recent'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[300],
                      side: BorderSide(color: Colors.grey[700]!),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                // Safe area padding
                SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVersionCard({
    required String title,
    required IconData icon,
    required String value,
    DateTime? timestamp,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withAlpha(15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withAlpha(50), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (timestamp != null) ...[
              const SizedBox(height: 8),
              Text(
                _formatTimestamp(timestamp),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: Colors.grey[500],
                ),
              ),
            ],
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Keep This',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
