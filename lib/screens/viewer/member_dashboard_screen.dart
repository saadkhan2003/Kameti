import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../models/committee.dart';
import '../../models/member.dart';
import '../../models/payment_proof.dart';
import '../../services/database_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/proof_status_badge.dart';
import '../member/upload_proof_screen.dart';
import 'package:committee_app/ui/theme/theme.dart';

class MemberDashboardScreen extends StatefulWidget {
  final Committee committee;
  final Member member;

  const MemberDashboardScreen({
    super.key,
    required this.committee,
    required this.member,
  });

  @override
  State<MemberDashboardScreen> createState() => _MemberDashboardScreenState();
}

class _MemberDashboardScreenState extends State<MemberDashboardScreen> {
  static const Color _bg = AppColors.bg;
  static const Color _surface = AppColors.surface;
  static const Color _primary = AppColors.primary;
  static const Color _primarySoft = AppColors.softPrimary;
  static const Color _success = AppColors.success;
  static const Color _warning = AppColors.warning;
  static const Color _danger = AppColors.error;
  static const Color _textPrimary = AppColors.textPrimary;
  static const Color _textSecondary = AppColors.textSecondary;

  final _dbService = DatabaseService();
  final _supabase = SupabaseService();

  int _totalPayments = 0;
  int _paidPayments = 0;
  int _pendingPayments = 0;
  DateTime? _payoutDate;
  int _daysUntilPayout = 0;
  DateTime? _nextPaymentDate;

  int _selectedCycle = 1;
  int _maxCycles = 1;
  List<DateTime> _cycleDates = [];
  Map<String, PaymentProof> _latestProofByPaymentId = {};
  final Set<String> _seenProofNotificationKeys = {};

  List<PaymentProof> get _memberProofNotifications {
    final items =
        _latestProofByPaymentId.values
            .where((proof) => proof.isApproved || proof.isRejected)
            .toList();
    items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return items;
  }

  int get _unreadNotificationCount {
    return _memberProofNotifications
        .where(
          (proof) =>
              !_seenProofNotificationKeys.contains(_proofNotifKey(proof)),
        )
        .length;
  }

  @override
  void initState() {
    super.initState();
    _maxCycles = _resolveTotalCycles();
    _selectedCycle = _findOngoingCycle();
    _calculateStats();
    _loadProofs();
  }

  Future<void> _loadProofs() async {
    final proofs = await _supabase.getProofsForMember(
      widget.member.id,
      widget.committee.id,
    );

    final map = <String, PaymentProof>{};
    for (final proof in proofs) {
      final existing = map[proof.paymentId];
      if (existing == null || proof.createdAt.isAfter(existing.createdAt)) {
        map[proof.paymentId] = proof;
      }
    }

    if (!mounted) return;
    setState(() => _latestProofByPaymentId = map);
  }

  DateTime? _firstUnpaidDate() {
    for (final date in _cycleDates) {
      final payment = _dbService.getPayment(widget.member.id, date);
      if (payment == null || !payment.isPaid) {
        return date;
      }
    }
    return null;
  }

  String _proofStatusForDate(DateTime date) {
    final payment = _dbService.getPayment(widget.member.id, date);
    if (payment != null && payment.isPaid) return 'approved';

    final paymentId = '${widget.member.id}_${date.toIso8601String()}';
    final proof = _latestProofByPaymentId[paymentId];
    if (proof == null) return 'none';
    return proof.status;
  }

  String _proofNotifKey(PaymentProof proof) {
    return '${proof.id}_${proof.status}_${proof.updatedAt.toIso8601String()}';
  }

  DateTime? _paymentDateFromId(String paymentId) {
    final prefix = '${widget.member.id}_';
    if (!paymentId.startsWith(prefix)) return null;
    final raw = paymentId.substring(prefix.length);
    return DateTime.tryParse(raw);
  }

  String _notifTitle(PaymentProof proof) {
    final date = _paymentDateFromId(proof.paymentId);
    final dateLabel =
        date != null
            ? DateFormat('MMM d, yyyy').format(date)
            : DateFormat('MMM d, yyyy').format(proof.createdAt);
    return proof.isApproved ? 'Approved • $dateLabel' : 'Rejected • $dateLabel';
  }

  String _notifSubtitle(PaymentProof proof) {
    if (proof.isRejected && (proof.rejectionReason?.isNotEmpty ?? false)) {
      return 'Reason: ${proof.rejectionReason}';
    }
    return proof.isApproved
        ? 'Your payment proof was approved.'
        : 'Your payment proof was rejected.';
  }

  Future<void> _openNotificationSheet() async {
    final items = _memberProofNotifications;
    if (mounted) {
      setState(() {
        for (final proof in items) {
          _seenProofNotificationKeys.add(_proofNotifKey(proof));
        }
      });
    }

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.surface,
      builder: (context) {
        if (items.isEmpty) {
          return SizedBox(
            height: 220,
            child: Center(
              child: Text(
                'No member notifications yet',
                style: GoogleFonts.inter(
                  color: _textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          );
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notifications',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final proof = items[index];
                      final tone = proof.isApproved ? _success : _danger;
                      return Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: tone.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: tone.withOpacity(0.2)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              proof.isApproved
                                  ? AppIcons.check_circle_outline_rounded
                                  : AppIcons.error_rounded,
                              size: 18,
                              color: tone,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _notifTitle(proof),
                                    style: GoogleFonts.inter(
                                      color: _textPrimary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _notifSubtitle(proof),
                                    style: GoogleFonts.inter(
                                      color: _textSecondary,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openUploadForDate(DateTime date) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => UploadProofScreen(
              committee: widget.committee,
              member: widget.member,
              paymentDate: date,
              amount: widget.committee.contributionAmount,
            ),
      ),
    );

    if (result == true) {
      await _loadProofs();
      _calculateStats();
    }
  }

  int _resolveTotalCycles() {
    final members = _dbService.getMembersByCommittee(widget.committee.id);
    final memberPayments = _dbService.getPaymentsByMember(widget.member.id);

    int periodsPerPayout;
    if (widget.committee.frequency == 'monthly') {
      periodsPerPayout = (widget.committee.paymentIntervalDays / 30).ceil();
    } else if (widget.committee.frequency == 'weekly') {
      periodsPerPayout = (widget.committee.paymentIntervalDays / 7).ceil();
    } else {
      periodsPerPayout = widget.committee.paymentIntervalDays;
    }
    if (periodsPerPayout < 1) periodsPerPayout = 1;

    final cyclesFromPayments =
        memberPayments.isEmpty
            ? 0
            : (memberPayments.length / periodsPerPayout).ceil();

    final candidates =
        <int>[
          members.length,
          widget.committee.totalMembers,
          widget.committee.totalCycles,
          cyclesFromPayments,
          widget.member.payoutOrder,
        ].where((value) => value > 0).toList();

    if (candidates.isEmpty) return 1;
    candidates.sort();
    return candidates.last;
  }

  int _findOngoingCycle() {
    final now = DateTime.now();
    final startDate = widget.committee.startDate;
    final intervalDays = widget.committee.paymentIntervalDays;

    final daysSinceStart = now.difference(startDate).inDays;
    final cycle = (daysSinceStart / intervalDays).floor() + 1;

    return cycle.clamp(1, _maxCycles);
  }

  void _calculateStats() {
    _dbService.getPaymentsByMember(widget.member.id);
    final startDate = widget.committee.startDate;
    final today = DateTime.now();
    final intervalDays = widget.committee.paymentIntervalDays;

    final cycleStartDate = startDate.add(
      Duration(days: intervalDays * (_selectedCycle - 1)),
    );
    final cycleEndDate = cycleStartDate.add(Duration(days: intervalDays - 1));

    _cycleDates = [];
    DateTime current = cycleStartDate;
    int collectionInterval =
        widget.committee.frequency == 'daily'
            ? 1
            : widget.committee.frequency == 'weekly'
            ? 7
            : 30;

    while (!current.isAfter(cycleEndDate) && _cycleDates.length < 35) {
      _cycleDates.add(current);
      current = current.add(Duration(days: collectionInterval));
    }

    _totalPayments = _cycleDates.length;
    _paidPayments = 0;
    for (final date in _cycleDates) {
      final payment = _dbService.getPayment(widget.member.id, date);
      if (payment != null && payment.isPaid) {
        _paidPayments++;
      }
    }

    _pendingPayments = _totalPayments - _paidPayments;
    if (_pendingPayments < 0) _pendingPayments = 0;

    if (widget.member.payoutOrder > 0) {
      _payoutDate = startDate.add(
        Duration(days: intervalDays * widget.member.payoutOrder),
      );
      _daysUntilPayout = _payoutDate!.difference(today).inDays;
      if (_daysUntilPayout < 0) _daysUntilPayout = 0;
    }

    if (widget.committee.frequency == 'daily') {
      _nextPaymentDate = DateTime(today.year, today.month, today.day + 1);
    } else if (widget.committee.frequency == 'weekly') {
      _nextPaymentDate = today.add(Duration(days: 7 - today.weekday % 7));
    } else {
      _nextPaymentDate = DateTime(today.year, today.month + 1, 1);
    }

    setState(() {});
  }

  void _changeCycle(int delta) {
    final newCycle = _selectedCycle + delta;
    if (newCycle >= 1 && newCycle <= _maxCycles) {
      setState(() {
        _selectedCycle = newCycle;
      });
      _calculateStats();
    }
  }

  @override
  Widget build(BuildContext context) {
    final progressPercent =
        _totalPayments > 0
            ? (_paidPayments / _totalPayments * 100).clamp(0, 100)
            : 0.0;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(AppIcons.arrow_back, color: _textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'My Dashboard',
          style: GoogleFonts.inter(
            color: _textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            onPressed: _openNotificationSheet,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(AppIcons.notifications, color: _textPrimary),
                if (_unreadNotificationCount > 0)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        _unreadNotificationCount > 99
                            ? '99+'
                            : '$_unreadNotificationCount',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          MediaQuery.of(context).padding.bottom + 18,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroHeader(),
            const SizedBox(height: 14),
            _buildCycleSelector(),
            const SizedBox(height: 14),
            _buildProofActionCard(),
            const SizedBox(height: 14),
            _buildPayoutCard(),
            const SizedBox(height: 14),
            _buildStatusCard(progressPercent.toDouble()),
            const SizedBox(height: 14),
            _buildNextPaymentCard(),
            const SizedBox(height: 14),
            _buildCommitteeInfoCard(),
            const SizedBox(height: 14),
            _buildPayoutListCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Welcome, ${widget.member.name}',
            style: GoogleFonts.inter(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.committee.name,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildHeroChip(
                AppIcons.calendar_month_rounded,
                _capitalize(widget.committee.frequency),
              ),
              _buildHeroChip(
                AppIcons.payments_rounded,
                '${widget.committee.currency} ${NumberFormat('#,###').format(widget.committee.contributionAmount.toInt())}',
              ),
              _buildHeroChip(
                AppIcons.format_list_numbered,
                'Cycle $_selectedCycle/$_maxCycles',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCycleSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          IconButton(
            onPressed: _selectedCycle > 1 ? () => _changeCycle(-1) : null,
            icon: Icon(
              AppIcons.chevron_left_rounded,
              color: _selectedCycle > 1 ? _textPrimary : AppColors.cFFB2BCD0,
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'Cycle $_selectedCycle of $_maxCycles',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _textPrimary,
                  ),
                ),
                if (_cycleDates.isNotEmpty)
                  Text(
                    '${DateFormat('MMM d').format(_cycleDates.first)} - ${DateFormat('MMM d, yyyy').format(_cycleDates.last)}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: _textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed:
                _selectedCycle < _maxCycles ? () => _changeCycle(1) : null,
            icon: Icon(
              AppIcons.chevron_right_rounded,
              color:
                  _selectedCycle < _maxCycles
                      ? _textPrimary
                      : AppColors.cFFB2BCD0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPayoutCard() {
    final hasPayout = widget.member.hasReceivedPayout;
    final highlight = hasPayout ? _success : _warning;

    return _buildInfoCard(
      icon: AppIcons.account_balance_wallet_rounded,
      title: 'Your Payout',
      content:
          hasPayout
              ? 'Already Received'
              : _payoutDate != null
              ? DateFormat('MMMM d, yyyy').format(_payoutDate!)
              : 'Not Assigned Yet',
      subtitle:
          hasPayout
              ? 'Congratulations!'
              : _daysUntilPayout > 0
              ? '$_daysUntilPayout days remaining'
              : _payoutDate != null
              ? 'Payout day!'
              : 'Waiting for assignment',
      color: highlight,
    );
  }

  Widget _buildProofActionCard() {
    final date = _firstUnpaidDate();
    if (date == null) {
      return const SizedBox.shrink();
    }

    final status = _proofStatusForDate(date);
    final paymentId = '${widget.member.id}_${date.toIso8601String()}';
    final proof = _latestProofByPaymentId[paymentId];
    final pendingDates =
        _cycleDates.where((d) => _proofStatusForDate(d) == 'pending').toList();
    final hasMultiPending = status == 'pending' && pendingDates.length > 1;
    final pendingStart = hasMultiPending ? pendingDates.first : null;
    final pendingEnd = hasMultiPending ? pendingDates.last : null;
    final pendingTotalAmount =
        widget.committee.contributionAmount * pendingDates.length;

    final canUpload = status == 'none' || status == 'rejected';
    final btnLabel =
        status == 'rejected'
            ? 'Resubmit Proof'
            : status == 'pending'
            ? hasMultiPending
                ? 'Proofs Submitted (${pendingDates.length})'
                : 'Proof Submitted'
            : status == 'approved'
            ? 'Approved'
            : 'Upload Payment Proof';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Payment Proof',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _textPrimary,
                ),
              ),
              const Spacer(),
              ProofStatusBadge(status: status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hasMultiPending
                ? '${DateFormat('MMM d, yyyy').format(pendingStart!)} → ${DateFormat('MMM d, yyyy').format(pendingEnd!)} • ${widget.committee.currency} ${pendingTotalAmount.toInt()}'
                : '${DateFormat('MMM d, yyyy').format(date)} • ${widget.committee.currency} ${widget.committee.contributionAmount.toInt()}',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: _textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (hasMultiPending) ...[
            const SizedBox(height: 4),
            Text(
              '${pendingDates.length} periods pending approval',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: _textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (status == 'rejected' &&
              (proof?.rejectionReason?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 6),
            Text(
              'Reason: ${proof!.rejectionReason}',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: _danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: canUpload ? () => _openUploadForDate(date) : null,
              child: Text(btnLabel),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(double progressPercent) {
    final progressColor =
        progressPercent >= 80
            ? _success
            : progressPercent >= 50
            ? _warning
            : _primary;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(AppIcons.analytics, color: _primary),
              const SizedBox(width: 10),
              Text(
                'Your Payment Status',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildStatPill(
                  'Paid',
                  '$_paidPayments/${_totalPayments > 0 ? _totalPayments : '-'}',
                  _success,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatPill('Pending', '$_pendingPayments', _danger),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progress',
                style: GoogleFonts.inter(color: _textSecondary, fontSize: 12),
              ),
              Text(
                '${progressPercent.toStringAsFixed(0)}%',
                style: GoogleFonts.inter(
                  color: progressColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progressPercent / 100,
              minHeight: 10,
              backgroundColor: AppColors.cFFE5EAF6,
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatPill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(fontSize: 12, color: _textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildNextPaymentCard() {
    return _buildInfoCard(
      icon: AppIcons.calendar_today_rounded,
      title: 'Next Payment',
      content:
          _nextPaymentDate != null
              ? _isToday(_nextPaymentDate!)
                  ? 'Today'
                  : _isTomorrow(_nextPaymentDate!)
                  ? 'Tomorrow'
                  : DateFormat('EEEE, MMM d').format(_nextPaymentDate!)
              : 'N/A',
      subtitle:
          'Amount: ${widget.committee.currency} ${NumberFormat('#,###').format(widget.committee.contributionAmount.toInt())}',
      color: _primary,
    );
  }

  Widget _buildCommitteeInfoCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Committee Details',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          _buildDetailRow('Committee Code', widget.committee.code),
          _buildDetailRow('Your Member Code', widget.member.memberCode),
          _buildDetailRow('Your Payout Order', '#${widget.member.payoutOrder}'),
          _buildDetailRow(
            'Collection',
            _capitalize(widget.committee.frequency),
          ),
          _buildDetailRow(
            'Contribution',
            '${widget.committee.currency} ${NumberFormat('#,###').format(widget.committee.contributionAmount.toInt())}',
          ),
        ],
      ),
    );
  }

  Widget _buildPayoutListCard() {
    final members = _dbService.getMembersByCommittee(widget.committee.id);
    members.sort((a, b) => a.payoutOrder.compareTo(b.payoutOrder));

    final intervalDays = widget.committee.paymentIntervalDays;
    final startDate = widget.committee.startDate;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(AppIcons.group_rounded, color: _primary),
              const SizedBox(width: 10),
              Text(
                'Payout Schedule',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Members and their payout sequence',
            style: GoogleFonts.inter(color: _textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: members.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final member = members[index];
              final isCurrentMember = member.id == widget.member.id;
              final payoutDate = startDate.add(
                Duration(days: intervalDays * member.payoutOrder),
              );

              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isCurrentMember ? _primarySoft : AppColors.cFFF8FAFF,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        isCurrentMember
                            ? _primary.withOpacity(0.35)
                            : AppColors.cFFE6ECF8,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: member.hasReceivedPayout ? _success : _warning,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '#${member.payoutOrder}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  member.name,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color:
                                        isCurrentMember
                                            ? _primary
                                            : _textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isCurrentMember) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _primary,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    'You',
                                    style: GoogleFonts.inter(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            DateFormat('MMM d, yyyy').format(payoutDate),
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: _textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color:
                            member.hasReceivedPayout
                                ? _success.withOpacity(0.12)
                                : _warning.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color:
                              member.hasReceivedPayout
                                  ? _success.withOpacity(0.4)
                                  : _warning.withOpacity(0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            member.hasReceivedPayout
                                ? AppIcons.paid
                                : AppIcons.schedule_rounded,
                            size: 13,
                            color:
                                member.hasReceivedPayout ? _success : _warning,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            member.hasReceivedPayout ? 'Paid' : 'Pending',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color:
                                  member.hasReceivedPayout
                                      ? _success
                                      : _warning,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String content,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(borderColor: color.withOpacity(0.25)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    color: _textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  content,
                  style: GoogleFonts.inter(
                    color: _textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(color: _textSecondary, fontSize: 12),
          ),
          Flexible(
            child: Text(
              value,
              style: GoogleFonts.inter(
                color: _textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration({Color? borderColor}) {
    return BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: borderColor ?? AppColors.cFFDDE5F5),
      boxShadow: [
        BoxShadow(
          color: AppColors.darkBg.withOpacity(0.05),
          blurRadius: 12,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  bool _isTomorrow(DateTime date) {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return date.year == tomorrow.year &&
        date.month == tomorrow.month &&
        date.day == tomorrow.day;
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }
}
