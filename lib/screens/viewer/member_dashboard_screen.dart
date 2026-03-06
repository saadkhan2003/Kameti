import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../models/committee.dart';
import '../../models/member.dart';
import '../../services/database_service.dart';

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
  static const Color _bg = Color(0xFFF6F8FC);
  static const Color _surface = Colors.white;
  static const Color _primary = Color(0xFF3347A8);
  static const Color _primarySoft = Color(0xFFEAF0FF);
  static const Color _success = Color(0xFF059669);
  static const Color _warning = Color(0xFFD97706);
  static const Color _danger = Color(0xFFDC2626);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);

  final _dbService = DatabaseService();

  int _totalPayments = 0;
  int _paidPayments = 0;
  int _pendingPayments = 0;
  DateTime? _payoutDate;
  int _daysUntilPayout = 0;
  DateTime? _nextPaymentDate;

  int _selectedCycle = 1;
  int _maxCycles = 1;
  List<DateTime> _cycleDates = [];

  @override
  void initState() {
    super.initState();
    _maxCycles = _resolveTotalCycles();
    _selectedCycle = _findOngoingCycle();
    _calculateStats();
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
          icon: const Icon(Icons.arrow_back, color: _textPrimary),
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
            _buildPaymentMatrix(),
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
          colors: [Color(0xFF3347A8), Color(0xFF4F46E5)],
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
                Icons.calendar_month_rounded,
                _capitalize(widget.committee.frequency),
              ),
              _buildHeroChip(
                Icons.payments_rounded,
                '${widget.committee.currency} ${NumberFormat('#,###').format(widget.committee.contributionAmount.toInt())}',
              ),
              _buildHeroChip(
                Icons.format_list_numbered,
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
              Icons.chevron_left_rounded,
              color:
                  _selectedCycle > 1 ? _textPrimary : const Color(0xFFB2BCD0),
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
              Icons.chevron_right_rounded,
              color:
                  _selectedCycle < _maxCycles
                      ? _textPrimary
                      : const Color(0xFFB2BCD0),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMatrix() {
    if (_cycleDates.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: _cardDecoration(),
        child: Text(
          'No payment dates available for this cycle.',
          style: GoogleFonts.inter(color: _textSecondary),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Cycle $_selectedCycle Payment Grid',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: _cycleDates.length,
            itemBuilder: (context, index) {
              final date = _cycleDates[index];
              final payment = _dbService.getPayment(widget.member.id, date);
              final isPaid = payment != null && payment.isPaid;

              return Container(
                decoration: BoxDecoration(
                  color: isPaid ? _success.withOpacity(0.14) : _primarySoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color:
                        isPaid
                            ? _success.withOpacity(0.45)
                            : const Color(0xFFD7E3FF),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isPaid
                          ? Icons.check_circle_rounded
                          : Icons.schedule_rounded,
                      color: isPaid ? _success : _warning,
                      size: 16,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('d').format(date),
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: _textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem(_success.withOpacity(0.16), _success, 'Paid'),
              const SizedBox(width: 14),
              _buildLegendItem(_primarySoft, _warning, 'Pending'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color bg, Color iconColor, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: iconColor.withOpacity(0.5)),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: _textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildPayoutCard() {
    final hasPayout = widget.member.hasReceivedPayout;
    final highlight = hasPayout ? _success : _warning;

    return _buildInfoCard(
      icon: Icons.account_balance_wallet_rounded,
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
              const Icon(Icons.analytics_rounded, color: _primary),
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
              backgroundColor: const Color(0xFFE5EAF6),
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
      icon: Icons.calendar_today_rounded,
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
              const Icon(Icons.group_rounded, color: _primary),
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
                  color:
                      isCurrentMember ? _primarySoft : const Color(0xFFF8FAFF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        isCurrentMember
                            ? _primary.withOpacity(0.35)
                            : const Color(0xFFE6ECF8),
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
                                ? Icons.check_circle_rounded
                                : Icons.schedule_rounded,
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
      border: Border.all(color: borderColor ?? const Color(0xFFDDE5F5)),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF0F172A).withOpacity(0.05),
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
