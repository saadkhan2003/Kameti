import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/payment_proof.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../services/supabase_service.dart';
import '../../services/toast_service.dart';
import '../../widgets/proof_status_badge.dart';
import 'package:kameti/ui/theme/theme.dart';

class ProofReviewScreen extends StatefulWidget {
  final String proofId;

  const ProofReviewScreen({super.key, required this.proofId});

  @override
  State<ProofReviewScreen> createState() => _ProofReviewScreenState();
}

class _ProofReviewScreenState extends State<ProofReviewScreen> {
  final _supabase = SupabaseService();
  final _auth = AuthService();
  final _notifications = NotificationService();
  final _reasonController = TextEditingController();

  PaymentProof? _proof;
  bool _loading = true;
  bool _isProcessing = false;
  bool _showRejectReason = false;

  @override
  void initState() {
    super.initState();
    _loadProof();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadProof() async {
    if (!mounted) return;
    setState(() => _loading = true);
    final proof = await _supabase.getPaymentProofById(widget.proofId);
    if (!mounted) return;
    setState(() {
      _proof = proof;
      _loading = false;
    });
  }

  Future<void> _approveNow() async {
    if (_proof == null || _isProcessing) return;
    setState(() => _isProcessing = true);
    final proof = _proof;
    if (proof == null) return;

    final ok = await _supabase.updatePaymentProofStatus(
      proof.id,
      'approved',
      reviewedBy: _auth.currentUser?.id,
      paymentId: proof.paymentId,
    );

    if (!mounted) return;

    if (ok) {
      await _notifications.notifyProofApproved(
        memberId: proof.memberId,
        monthLabel: _monthLabel(proof.createdAt),
      );
      ToastService.success(
        context,
        'Payment approved. Member has been notified.',
      );
      Navigator.pop(context, true);
    } else {
      setState(() => _isProcessing = false);
      ToastService.error(context, 'Failed to approve proof. Please try again.');
    }
  }

  Future<void> _reject() async {
    final proof = _proof;
    if (proof == null || _isProcessing) return;

    final reason = _reasonController.text.trim();
    if (reason.isEmpty) {
      ToastService.warning(context, 'Please enter rejection reason.');
      return;
    }

    setState(() => _isProcessing = true);

    final ok = await _supabase.updatePaymentProofStatus(
      proof.id,
      'rejected',
      rejectionReason: reason,
      reviewedBy: _auth.currentUser?.id,
      paymentId: proof.paymentId,
    );

    if (!mounted) return;

    if (ok) {
      await _notifications.notifyProofRejected(
        memberId: proof.memberId,
        reason: reason,
      );
      ToastService.warning(
        context,
        'Payment proof rejected. Member has been notified.',
      );
      Navigator.pop(context, true);
    } else {
      setState(() => _isProcessing = false);
      ToastService.error(context, 'Failed to reject proof. Please try again.');
    }
  }

  Future<void> _moveToPending() async {
    final proof = _proof;
    if (proof == null || _isProcessing) return;

    setState(() => _isProcessing = true);

    final ok = await _supabase.updatePaymentProofStatus(
      proof.id,
      'pending',
      rejectionReason: null,
      reviewedBy: _auth.currentUser?.id,
      paymentId: proof.paymentId,
    );

    if (!mounted) return;

    if (ok) {
      ToastService.success(context, 'Proof moved back to pending.');
      Navigator.pop(context, true);
    } else {
      setState(() => _isProcessing = false);
      ToastService.error(context, 'Failed to move proof to pending.');
    }
  }

  Future<void> _deleteRequest() async {
    final proof = _proof;
    if (proof == null || _isProcessing) return;

    final shouldDelete =
        await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Delete proof request?'),
                content: const Text(
                  'This will remove the request from the list. Continue?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Delete'),
                  ),
                ],
              ),
        ) ??
        false;

    if (!shouldDelete) return;

    setState(() => _isProcessing = true);

    final ok = await _supabase.deletePaymentProof(
      proof.id,
      paymentId: proof.paymentId,
      hostId: _auth.currentUser?.id,
      resetPaymentAsUnpaid: proof.isApproved,
    );

    if (!mounted) return;

    if (ok) {
      ToastService.success(context, 'Proof request deleted.');
      Navigator.pop(context, true);
    } else {
      setState(() => _isProcessing = false);
      ToastService.error(context, 'Failed to delete proof request.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final proof = _proof;
    if (proof == null) {
      return const Scaffold(body: Center(child: Text('Proof not found')));
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBarStyles.standard(
        title: 'Proof Review',
        actions: [
          IconButton(
            tooltip: 'Delete request',
            onPressed: _isProcessing ? null : _deleteRequest,
            icon: const Icon(AppIcons.delete_outline),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Submitted ${_formatDateTime(proof.createdAt)}',
                  style: GoogleFonts.inter(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                ProofStatusBadge(status: proof.status),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                color: AppColors.surface,
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 5,
                  child: Image.network(
                    proof.cloudinaryUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) {
                        return child;
                      }

                      final expectedBytes = loadingProgress.expectedTotalBytes;
                      final loadedBytes = loadingProgress.cumulativeBytesLoaded;
                      final progress =
                          expectedBytes != null && expectedBytes > 0
                              ? loadedBytes / expectedBytes
                              : null;

                      return SizedBox(
                        height: 260,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(value: progress),
                              const SizedBox(height: 10),
                              Text(
                                'Loading proof...',
                                style: GoogleFonts.inter(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    errorBuilder:
                        (_, __, ___) => const SizedBox(
                          height: 260,
                          child: Center(child: Text('Could not load image')),
                        ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (proof.isPending) ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isProcessing ? null : _approveNow,
                  style: AppButtonStyles.elevatedSuccess(),
                  child: const Text('Approve'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed:
                      _isProcessing
                          ? null
                          : () {
                            setState(
                              () => _showRejectReason = !_showRejectReason,
                            );
                          },
                  style: AppButtonStyles.outlinedError(),
                  child: const Text('Reject'),
                ),
              ),
            ] else if (proof.isApproved) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _isProcessing ? null : _moveToPending,
                  style: AppButtonStyles.outlinedPrimary(),
                  child: const Text('Move to Pending'),
                ),
              ),
            ],
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child:
                  _showRejectReason
                      ? Column(
                        key: const ValueKey('reject-reason'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 10),
                          TextField(
                            controller: _reasonController,
                            minLines: 2,
                            maxLines: 4,
                            decoration: InputDecoration(
                              labelText: 'Rejection reason',
                              hintText: 'Write clear reason for member',
                              filled: true,
                              fillColor: AppColors.surface,
                              labelStyle: GoogleFonts.inter(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                              floatingLabelStyle: GoogleFonts.inter(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                              hintStyle: GoogleFonts.inter(
                                color: AppColors.cFFB0B8C9,
                                fontSize: 12,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: AppColors.lightBorder,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: AppColors.primary,
                                  width: 1.6,
                                ),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isProcessing ? null : _reject,
                              style: AppButtonStyles.elevatedWarning(),
                              child: const Text('Confirm Rejection'),
                            ),
                          ),
                        ],
                      )
                      : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _monthLabel(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dt.month - 1]} ${dt.year}';
  }
}
