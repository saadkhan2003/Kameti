import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../models/committee.dart';
import '../../models/member.dart';
import '../../models/payment.dart';
import '../../models/payment_proof.dart';
import '../../services/cloudinary_service.dart';
import '../../services/database_service.dart';
import '../../services/notification_service.dart';
import '../../services/supabase_service.dart';
import '../../services/toast_service.dart';
import '../../widgets/proof_status_badge.dart';
import 'package:committee_app/ui/theme/theme.dart';

class UploadProofScreen extends StatefulWidget {
  final Committee committee;
  final Member member;
  final DateTime paymentDate;
  final double amount;

  const UploadProofScreen({
    super.key,
    required this.committee,
    required this.member,
    required this.paymentDate,
    required this.amount,
  });

  @override
  State<UploadProofScreen> createState() => _UploadProofScreenState();
}

class _UploadProofScreenState extends State<UploadProofScreen> {
  final _picker = ImagePicker();
  final _cloudinary = CloudinaryService();
  final _supabase = SupabaseService();
  final _dbService = DatabaseService();
  final _notifications = NotificationService();

  Uint8List? _imageBytes;
  bool _isUploading = false;
  String? _fileName;
  PaymentProof? _latestProof;

  String get _paymentId =>
      '${widget.member.id}_${widget.paymentDate.toIso8601String()}';

  @override
  void initState() {
    super.initState();
    _loadLatestProof();
  }

  Future<void> _loadLatestProof() async {
    final proof = await _supabase.getLatestProofForPayment(_paymentId);
    if (!mounted) return;
    setState(() => _latestProof = proof);
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await _picker.pickImage(source: source, imageQuality: 90);
      if (file == null) return;

      final originalBytes = await file.readAsBytes();
      const max5Mb = 5 * 1024 * 1024;
      if (originalBytes.length > max5Mb) {
        if (!mounted) return;
        ToastService.error(
          context,
          'Image is too large. Please select an image under 5 MB.',
        );
        return;
      }

      final compressed = await _compressForUpload(originalBytes);

      if (!mounted) return;
      setState(() {
        _imageBytes = compressed;
        _fileName = file.name;
      });
    } catch (e) {
      if (!mounted) return;
      ToastService.error(context, 'Failed to pick image. Please try again.');
    }
  }

  Future<Uint8List> _compressForUpload(Uint8List bytes) async {
    if (kIsWeb) return bytes;

    var quality = 85;
    var current = bytes;
    const target = 800 * 1024;

    while (current.length > target && quality >= 40) {
      final compressed = await FlutterImageCompress.compressWithList(
        current,
        quality: quality,
        keepExif: false,
      );
      current = Uint8List.fromList(compressed);
      quality -= 10;
    }

    return current;
  }

  Future<void> _submit() async {
    if (_imageBytes == null || _isUploading) return;

    if (_latestProof?.isApproved == true) {
      ToastService.warning(
        context,
        'Payment already approved. Upload is disabled.',
      );
      return;
    }

    final hasPending = await _supabase.hasPendingProof(
      _paymentId,
      widget.member.id,
    );
    if (hasPending) {
      if (!mounted) return;
      ToastService.error(
        context,
        'You already have a pending proof for this payment.',
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final upload = await _cloudinary.uploadPaymentProof(
        bytes: _imageBytes!,
        fileName: _fileName ?? 'payment-proof.jpg',
      );

      final localPayment = _dbService.getPayment(
        widget.member.id,
        widget.paymentDate,
      );
      final payment =
          localPayment ??
          Payment(
            id: _paymentId,
            memberId: widget.member.id,
            committeeId: widget.committee.id,
            date: widget.paymentDate,
            isPaid: false,
            markedBy: widget.committee.hostId,
            markedAt: null,
          );

      await _dbService.savePayment(payment);
      await _supabase.upsertPayment(payment);

      final inserted = await _supabase.submitPaymentProof(
        PaymentProof(
          id: '',
          paymentId: _paymentId,
          committeeId: widget.committee.id,
          memberId: widget.member.id,
          hostId: widget.committee.hostId,
          cloudinaryUrl: upload.secureUrl,
          cloudinaryPublicId: upload.publicId,
          status: 'pending',
          rejectionReason: null,
          reviewedBy: null,
          reviewedAt: null,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      if (inserted == null) {
        throw Exception('Could not save payment proof');
      }

      await _notifications.notifyNewProof(
        hostId: widget.committee.hostId,
        memberName: widget.member.name,
        monthLabel: _monthLabel(widget.paymentDate),
        amountLabel: '${widget.committee.currency} ${widget.amount.toInt()}',
      );

      if (!mounted) return;
      ToastService.success(
        context,
        'Payment proof submitted successfully! Waiting for host approval.',
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ToastService.error(
        context,
        'Upload failed. Please check your internet and try again.',
      );
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rejectedReason =
        _latestProof?.isRejected == true ? _latestProof?.rejectionReason : null;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Upload Payment Proof'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryCard(),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('Status: '),
                ProofStatusBadge(status: _latestProof?.status ?? 'none'),
              ],
            ),
            if (rejectedReason != null && rejectedReason.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Reason: $rejectedReason',
                style: GoogleFonts.inter(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 14),
            _buildImagePicker(),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        _isUploading
                            ? null
                            : () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_rounded),
                    label: const Text('Camera'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        _isUploading
                            ? null
                            : () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Gallery'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Accepted: JPG, PNG. Max size: 5 MB',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    (_imageBytes == null ||
                            _latestProof?.isApproved == true)
                        ? null
                        : (_isUploading ? null : _submit),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.primary.withOpacity(0.55),
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white70,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child:
                    _isUploading
                        ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 10),
                            Text('Uploading...'),
                          ],
                        )
                        : Text(
                          _latestProof?.isRejected == true
                              ? 'Resubmit Proof'
                              : 'Submit Proof',
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.committee.name,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_monthLabel(widget.paymentDate)} • ${widget.committee.currency} ${widget.amount.toInt()}',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _isUploading ? null : () => _pickImage(ImageSource.gallery),
      child: Container(
        width: double.infinity,
        height: 260,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppColors.cFFD0D9EE,
            style: BorderStyle.solid,
          ),
        ),
        child:
            _imageBytes == null
                ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.camera_alt_rounded,
                      size: 34,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap to select image',
                      style: GoogleFonts.inter(color: AppColors.textSecondary),
                    ),
                  ],
                )
                : ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.memory(_imageBytes!, fit: BoxFit.cover),
                ),
      ),
    );
  }

  String _monthLabel(DateTime date) {
    const monthNames = [
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
    return '${monthNames[date.month - 1]} ${date.year}';
  }
}
