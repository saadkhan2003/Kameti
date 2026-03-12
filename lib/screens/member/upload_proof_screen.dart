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
  bool _loadingPeriods = true;
  List<DateTime> _eligiblePeriods = [];
  int _selectedPeriods = 1;

  String get _paymentId =>
      '${widget.member.id}_${widget.paymentDate.toIso8601String()}';

  List<DateTime> get _selectedPeriodDates {
    if (_eligiblePeriods.isEmpty) return [widget.paymentDate];
    final max = _selectedPeriods.clamp(1, _eligiblePeriods.length);
    return _eligiblePeriods.take(max).toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    await Future.wait([_loadLatestProof(), _prepareEligiblePeriods()]);
  }

  Future<void> _loadLatestProof() async {
    final proof = await _supabase.getLatestProofForPayment(_paymentId);
    if (!mounted) return;
    setState(() => _latestProof = proof);
  }

  Future<void> _prepareEligiblePeriods() async {
    if (mounted) setState(() => _loadingPeriods = true);

    final dates = _getCycleDatesForSelectedPayment();
    final filtered = dates
        .where((date) => !_isBeforeDay(date, widget.paymentDate))
        .where((date) {
          final payment = _dbService.getPayment(widget.member.id, date);
          return payment?.isPaid != true;
        })
        .toList(growable: false);

    if (!mounted) return;
    setState(() {
      _eligiblePeriods = filtered.isEmpty ? [widget.paymentDate] : filtered;
      _selectedPeriods = 1;
      _loadingPeriods = false;
    });
  }

  List<DateTime> _getCycleDatesForSelectedPayment() {
    final startDate = widget.committee.startDate;
    final payoutIntervalDays = widget.committee.paymentIntervalDays;

    final daysSinceStart = widget.paymentDate.difference(startDate).inDays;
    final cycleIndex = (daysSinceStart ~/ payoutIntervalDays).clamp(0, 1000000);

    final cycleStart = startDate.add(
      Duration(days: cycleIndex * payoutIntervalDays),
    );
    final cycleEnd = cycleStart.add(Duration(days: payoutIntervalDays - 1));

    int collectionInterval = 30;
    if (widget.committee.frequency == 'daily') collectionInterval = 1;
    if (widget.committee.frequency == 'weekly') collectionInterval = 7;
    if (widget.committee.frequency == 'monthly') collectionInterval = 30;

    final dates = <DateTime>[];
    DateTime current = cycleStart;
    while (!current.isAfter(cycleEnd) && dates.length < 60) {
      dates.add(current);
      current = current.add(Duration(days: collectionInterval));
    }

    return dates;
  }

  bool _isBeforeDay(DateTime a, DateTime b) {
    final ax = DateTime(a.year, a.month, a.day);
    final bx = DateTime(b.year, b.month, b.day);
    return ax.isBefore(bx);
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

    final selectedDates = _selectedPeriodDates;
    final blockedDates = <DateTime>[];

    for (final date in selectedDates) {
      final paymentId = '${widget.member.id}_${date.toIso8601String()}';
      final hasPending = await _supabase.hasPendingProof(
        paymentId,
        widget.member.id,
      );
      if (hasPending) {
        blockedDates.add(date);
      }
    }

    if (blockedDates.isNotEmpty) {
      if (!mounted) return;
      ToastService.error(
        context,
        'Some selected periods already have pending proofs. Please reduce periods and try again.',
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final upload = await _cloudinary.uploadPaymentProof(
        bytes: _imageBytes!,
        fileName: _fileName ?? 'payment-proof.jpg',
      );

      int submittedCount = 0;

      for (final date in selectedDates) {
        final paymentId = '${widget.member.id}_${date.toIso8601String()}';

        final localPayment = _dbService.getPayment(widget.member.id, date);
        final payment =
            localPayment ??
            Payment(
              id: paymentId,
              memberId: widget.member.id,
              committeeId: widget.committee.id,
              date: date,
              isPaid: false,
              markedBy: widget.committee.hostId,
              markedAt: null,
            );

        await _dbService.savePayment(payment);
        await _supabase.upsertPayment(payment);

        final inserted = await _supabase.submitPaymentProof(
          PaymentProof(
            id: '',
            paymentId: paymentId,
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

        if (inserted != null) {
          submittedCount++;
        }
      }

      if (submittedCount == 0) {
        throw Exception('Could not save payment proof requests');
      }

      if (!mounted) return;
      ToastService.success(
        context,
        submittedCount == 1
            ? 'Payment proof submitted successfully! Waiting for host approval.'
            : 'Proof submitted for $submittedCount periods successfully! Waiting for host approval.',
      );
      Navigator.pop(context, true);
    } catch (e) {
    if (!mounted) return;
    ToastService.error(
      context,
      e.toString(),
    );
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }

    // Fire-and-forget — notification failures must never block proof submission
    _notifications
        .notifyNewProof(
          hostId: widget.committee.hostId,
          memberName: widget.member.name,
          monthLabel: _monthLabel(widget.paymentDate),
          amountLabel:
              '${widget.committee.currency} ${(widget.amount * _selectedPeriods).toInt()}',
        )
        .ignore();
  }

  @override
  Widget build(BuildContext context) {
    final rejectedReason =
        _latestProof?.isRejected == true ? _latestProof?.rejectionReason : null;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBarStyles.standard(title: 'Upload Payment Proof'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSummaryCard(),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  'Status:',
                  style: GoogleFonts.inter(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                ProofStatusBadge(status: _latestProof?.status ?? 'none'),
              ],
            ),
            if (rejectedReason != null && rejectedReason.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: AppColors.error.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.error.withOpacity(0.25)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Icon(
                        AppIcons.error_rounded,
                        size: 15,
                        color: AppColors.error,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Rejection reason: $rejectedReason',
                        style: GoogleFonts.inter(
                          color: AppColors.error,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            _buildPeriodSelector(),
            const SizedBox(height: 12),
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
                    (_imageBytes == null || _latestProof?.isApproved == true)
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
            '${_monthLabel(widget.paymentDate)} • ${widget.committee.currency} ${widget.amount.toInt()} / period',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Due date: ${_fullDateLabel(widget.paymentDate)}',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    if (_loadingPeriods) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.lightBorder),
        ),
        child: const Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('Checking available periods...'),
          ],
        ),
      );
    }

    final maxPeriods = _eligiblePeriods.length;
    final selectedDates = _selectedPeriodDates;
    final start = selectedDates.first;
    final end = selectedDates.last;

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
            'Periods in this proof',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              IconButton(
                onPressed:
                    _isUploading || _selectedPeriods <= 1
                        ? null
                        : () => setState(() => _selectedPeriods--),
                style: IconButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  disabledForegroundColor: AppColors.cFFB0B8C9,
                ),
                icon: const Icon(AppIcons.remove_circle_outline, size: 24),
              ),
              Text(
                '$_selectedPeriods',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              IconButton(
                onPressed:
                    _isUploading || _selectedPeriods >= maxPeriods
                        ? null
                        : () => setState(() => _selectedPeriods++),
                style: IconButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  disabledForegroundColor: AppColors.cFFB0B8C9,
                ),
                icon: const Icon(AppIcons.add_circle_outline_rounded, size: 24),
              ),
              const Spacer(),
              Text(
                'Max $maxPeriods',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          Text(
            _selectedPeriods == 1
                ? 'Selected due date: ${_fullDateLabel(start)}'
                : 'Selected range: ${_fullDateLabel(start)} → ${_fullDateLabel(end)}',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
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

  String _fullDateLabel(DateTime date) {
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    return '$dd/$mm/${date.year}';
  }
}
