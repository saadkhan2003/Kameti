import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/payment_proof.dart';
import 'proof_status_badge.dart';
import 'package:committee_app/ui/theme/theme.dart';

class PaymentProofCard extends StatelessWidget {
  final PaymentProof proof;
  final String memberName;
  final String committeeName;
  final String periodLabel;
  final String dueDateLabel;
  final String amountLabel;
  final VoidCallback? onTap;

  const PaymentProofCard({
    super.key,
    required this.proof,
    required this.memberName,
    required this.committeeName,
    required this.periodLabel,
    required this.dueDateLabel,
    required this.amountLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surface,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.lightBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      memberName,
                      style: GoogleFonts.inter(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  ProofStatusBadge(status: proof.status),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '$committeeName • $periodLabel',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Due: $dueDateLabel',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    AppIcons.payout,
                    size: 14,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    amountLabel,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Uploaded ${_formatDate(proof.createdAt)}',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
