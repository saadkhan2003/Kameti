import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:committee_app/ui/theme/theme.dart';

class ProofStatusBadge extends StatelessWidget {
  final String status;

  const ProofStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();

    Color bg;
    Color fg;
    String label;

    switch (normalized) {
      case 'approved':
        bg = AppColors.success.withOpacity(0.14);
        fg = AppColors.success;
        label = 'Approved';
        break;
      case 'pending':
        bg = AppColors.warning.withOpacity(0.14);
        fg = AppColors.warning;
        label = 'Pending Approval';
        break;
      case 'rejected':
        bg = AppColors.error.withOpacity(0.14);
        fg = AppColors.error;
        label = 'Rejected';
        break;
      default:
        bg = AppColors.error.withOpacity(0.14);
        fg = AppColors.error;
        label = 'Unpaid';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}
