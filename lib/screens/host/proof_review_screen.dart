import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/payment_proof.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../services/supabase_service.dart';
import '../../services/toast_service.dart';
import '../../widgets/proof_status_badge.dart';
import 'package:committee_app/ui/theme/theme.dart';

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

  Timer? _approveTimer;
  bool _approveQueued = false;

  @override
  void initState() {
    super.initState();
    _loadProof();
  }

  @override
  void dispose() {
    _approveTimer?.cancel();
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

  Future<void> _queueApproveWithUndo() async {
    if (_proof == null || _isProcessing) return;

    setState(() {
      _approveQueued = true;
      _isProcessing = true;
    });

    _approveTimer?.cancel();
    _approveTimer = Timer(const Duration(seconds: 5), () async {
      if (!_approveQueued) return;
      await _applyApprove();
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Approval queued. Undo within 5 seconds.'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            _approveTimer?.cancel();
            if (!mounted) return;
            setState(() {
              _approveQueued = false;
              _isProcessing = false;
            });
          },
        ),
      ),
    );
  }

  Future<void> _applyApprove() async {
    final proof = _proof;
    if (proof == null) return;

    final ok = await _supabase.updatePaymentProofStatus(
      proof.id,
      'approved',
      reviewedBy: _auth.currentUser?.id,
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
      setState(() {
        _isProcessing = false;
        _approveQueued = false;
      });
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
      appBar: AppBar(
        title: Text(
          'Proof Review',
          style: GoogleFonts.inter(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.textPrimary,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
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
                  onPressed: _isProcessing ? null : _queueApproveWithUndo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                  ),
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
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                  ),
                  child: const Text(
                    'Reject',
                    style: TextStyle(color: AppColors.error),
                  ),
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
                            decoration: const InputDecoration(
                              labelText: 'Rejection reason',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _isProcessing ? null : _reject,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.warning,
                                foregroundColor: Colors.white,
                              ),
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
