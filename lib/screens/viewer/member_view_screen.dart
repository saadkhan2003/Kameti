import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../models/committee.dart';
import '../../models/member.dart';
import '../../services/database_service.dart';
import '../../services/sync_service.dart';
import '../../ui/widgets/ads/banner_ad_widget.dart';

class MemberViewScreen extends StatefulWidget {
  final Committee committee;
  final Member member;

  const MemberViewScreen({
    super.key,
    required this.committee,
    required this.member,
  });

  @override
  State<MemberViewScreen> createState() => _MemberViewScreenState();
}

class _MemberViewScreenState extends State<MemberViewScreen> {
  static const Color _bg = Color(0xFFF6F8FC);
  static const Color _surface = Colors.white;
  static const Color _primary = Color(0xFF3347A8);
  static const Color _primarySoft = Color(0xFFEAF0FF);
  static const Color _success = Color(0xFF059669);
  static const Color _warning = Color(0xFFD97706);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);

  final _dbService = DatabaseService();
  final _syncService = SyncService();

  List<DateTime> _dates = [];
  int _paidCount = 0;
  int _totalDays = 0;
  bool _isRefreshing = false;
  bool _isFirstLoad = true;

  int _selectedCycle = 1;
  int _maxCycles = 1;
  List<Member> _members = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    _refreshFromCloud();
  }

  void _loadData() {
    _members = _dbService.getMembersByCommittee(widget.committee.id);
    _maxCycles = _members.isNotEmpty ? _members.length : 1;

    if (_isFirstLoad) {
      _selectedCycle = _findOngoingCycle();
      _isFirstLoad = false;
    }

    if (_selectedCycle > _maxCycles) _selectedCycle = _maxCycles;
    if (_selectedCycle < 1) _selectedCycle = 1;

    _generateDates();
    _calculateStats();
  }

  int _findOngoingCycle() {
    final now = DateTime.now();
    final committeeStartDate = widget.committee.startDate;
    final payoutIntervalDays = widget.committee.paymentIntervalDays;

    int periodsPerPayout;
    if (widget.committee.frequency == 'monthly') {
      periodsPerPayout = (payoutIntervalDays / 30).ceil();
      if (periodsPerPayout < 1) periodsPerPayout = 1;
    } else if (widget.committee.frequency == 'weekly') {
      periodsPerPayout = (payoutIntervalDays / 7).ceil();
      if (periodsPerPayout < 1) periodsPerPayout = 1;
    } else {
      periodsPerPayout = payoutIntervalDays;
      if (periodsPerPayout < 1) periodsPerPayout = 1;
    }

    for (int cycle = 1; cycle <= _maxCycles; cycle++) {
      DateTime cycleStartDate;
      DateTime cycleEndDate;

      if (widget.committee.frequency == 'monthly') {
        cycleStartDate = _addMonths(
          committeeStartDate,
          (cycle - 1) * periodsPerPayout,
        );
        cycleEndDate = _addMonths(
          cycleStartDate,
          periodsPerPayout,
        ).subtract(const Duration(days: 1));
      } else {
        final daysOffset = (cycle - 1) * payoutIntervalDays;
        cycleStartDate = committeeStartDate.add(Duration(days: daysOffset));
        cycleEndDate = cycleStartDate.add(
          Duration(days: payoutIntervalDays - 1),
        );
      }

      if (!now.isBefore(cycleStartDate) && !now.isAfter(cycleEndDate)) {
        return cycle;
      }

      if (now.isBefore(cycleStartDate)) {
        return cycle > 1 ? cycle - 1 : 1;
      }
    }

    return _maxCycles;
  }

  DateTime _addMonths(DateTime date, int monthsToAdd) {
    var newYear = date.year;
    var newMonth = date.month + monthsToAdd;

    while (newMonth > 12) {
      newYear++;
      newMonth -= 12;
    }

    final firstDayOfNextMonth = DateTime(newYear, newMonth + 1, 1);
    final lastDayOfTargetMonth =
        firstDayOfNextMonth.subtract(const Duration(days: 1)).day;

    final newDay =
        (date.day > lastDayOfTargetMonth) ? lastDayOfTargetMonth : date.day;

    return DateTime(newYear, newMonth, newDay);
  }

  void _generateDates() {
    _dates = [];
    final committeeStartDate = widget.committee.startDate;
    final payoutIntervalDays = widget.committee.paymentIntervalDays;

    int collectionInterval = 30;
    if (widget.committee.frequency == 'daily') collectionInterval = 1;
    if (widget.committee.frequency == 'weekly') collectionInterval = 7;
    if (widget.committee.frequency == 'monthly') collectionInterval = 30;

    int periodsPerPayout;
    if (widget.committee.frequency == 'monthly') {
      periodsPerPayout = (payoutIntervalDays / 30).ceil();
      if (periodsPerPayout < 1) periodsPerPayout = 1;
    } else {
      periodsPerPayout = (payoutIntervalDays / collectionInterval).ceil();
      if (periodsPerPayout < 1) periodsPerPayout = 1;
    }

    DateTime cycleStartDate;
    if (widget.committee.frequency == 'monthly') {
      cycleStartDate = _addMonths(
        committeeStartDate,
        (_selectedCycle - 1) * periodsPerPayout,
      );
    } else {
      final daysOffset = (_selectedCycle - 1) * payoutIntervalDays;
      cycleStartDate = committeeStartDate.add(Duration(days: daysOffset));
    }

    final maxDatesToShow =
        widget.committee.frequency == 'daily' ? 35 : periodsPerPayout;
    final datesToGenerate =
        periodsPerPayout < maxDatesToShow ? periodsPerPayout : maxDatesToShow;

    DateTime current = cycleStartDate;
    for (int index = 0; index < datesToGenerate; index++) {
      _dates.add(current);
      if (widget.committee.frequency == 'monthly') {
        current = _addMonths(current, 1);
      } else {
        current = current.add(Duration(days: collectionInterval));
      }
    }
  }

  void _calculateStats() {
    _totalDays = _dates.length;
    _paidCount = 0;

    for (final date in _dates) {
      final payment = _dbService.getPayment(widget.member.id, date);
      final isPaid = payment != null && payment.isPaid;
      if (isPaid) {
        _paidCount++;
      }
    }

    setState(() {});
  }

  Future<void> _refreshFromCloud() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);

    try {
      await _syncService.refreshViewerData(widget.committee.id);
      _loadData();
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  bool _isCurrentCycleOngoing() {
    if (_dates.isEmpty) return false;
    final now = DateTime.now();
    final cycleStart = _dates.first;
    final cycleEnd = _dates.last;
    return !now.isBefore(cycleStart) &&
        !now.isAfter(cycleEnd.add(const Duration(days: 1)));
  }

  bool _isPaymentMarked(DateTime date) {
    final payment = _dbService.getPayment(widget.member.id, date);
    return payment != null && payment.isPaid;
  }

  void _changeCycle(int delta) {
    final newCycle = _selectedCycle + delta;
    if (newCycle >= 1 && newCycle <= _maxCycles) {
      setState(() {
        _selectedCycle = newCycle;
      });
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final contribution = _paidCount * widget.committee.contributionAmount;
    final pendingCount = (_totalDays - _paidCount).clamp(0, _totalDays);
    final progress = _totalDays > 0 ? (_paidCount / _totalDays) : 0.0;

    return Scaffold(
      backgroundColor: _bg,
      bottomNavigationBar: const BannerAdWidget(),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.committee.name,
              style: GoogleFonts.inter(
                color: _textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              'Welcome, ${widget.member.name}',
              style: GoogleFonts.inter(fontSize: 12, color: _textSecondary),
            ),
          ],
        ),
        actions: [
          _isRefreshing
              ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
              : IconButton(
                icon: const Icon(Icons.refresh_rounded, color: _textSecondary),
                tooltip: 'Refresh from cloud',
                onPressed: _refreshFromCloud,
              ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHero(contribution),
            const SizedBox(height: 14),
            _buildCycleSelector(),
            const SizedBox(height: 14),
            _buildProgressCard(_paidCount, pendingCount, progress),
            const SizedBox(height: 14),
            _buildPaymentHistoryGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(double contribution) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3347A8), Color(0xFF4F46E5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.24),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Member Overview',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  _selectedCycle = 1;
                  _loadData();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withOpacity(0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.restart_alt_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Reset',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildHeroStat(
                  Icons.check_circle_rounded,
                  'Paid',
                  '$_paidCount / $_totalDays',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildHeroStat(
                  Icons.payments_rounded,
                  'Contributed',
                  '${widget.committee.currency} ${contribution.toStringAsFixed(0)}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildHeroStat(
                  Icons.calendar_today_rounded,
                  'Per ${_periodLabel()}',
                  '${widget.committee.currency} ${widget.committee.contributionAmount.toStringAsFixed(0)}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStat(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white.withOpacity(0.9),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
                  _selectedCycle > 1 ? _textPrimary : const Color(0xFFB8C3D8),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.center,
                  children: [
                    Text(
                      'Cycle $_selectedCycle of $_maxCycles',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _textPrimary,
                      ),
                    ),
                    if (_isCurrentCycleOngoing())
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _warning.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: _warning.withOpacity(0.32)),
                        ),
                        child: Text(
                          'ONGOING',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: _warning,
                          ),
                        ),
                      ),
                  ],
                ),
                if (_dates.isNotEmpty)
                  Text(
                    '${DateFormat('MMM d').format(_dates.first)} - ${DateFormat('MMM d, yyyy').format(_dates.last)}',
                    style: GoogleFonts.inter(
                      color: _textSecondary,
                      fontSize: 11,
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
                      : const Color(0xFFB8C3D8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(int paid, int pending, double progress) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment Performance',
            style: GoogleFonts.inter(
              color: _textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildPillStat('Paid', '$paid', _success)),
              const SizedBox(width: 10),
              Expanded(child: _buildPillStat('Pending', '$pending', _warning)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Completion',
                style: GoogleFonts.inter(color: _textSecondary, fontSize: 12),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: GoogleFonts.inter(
                  color: _primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: const Color(0xFFE4EAF7),
              valueColor: const AlwaysStoppedAnimation<Color>(_primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPillStat(String label, String value, Color tone) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: tone.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tone.withOpacity(0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.inter(
              color: tone,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: GoogleFonts.inter(color: _textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentHistoryGrid() {
    final dateFormat =
        widget.committee.frequency == 'monthly'
            ? DateFormat('MMM')
            : DateFormat('d');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Payment History',
            style: GoogleFonts.inter(
              color: _textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
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
            itemCount: _dates.length,
            itemBuilder: (context, index) {
              final date = _dates[index];
              final isPaid = _isPaymentMarked(date);

              return Container(
                decoration: BoxDecoration(
                  color: isPaid ? _success.withOpacity(0.14) : _primarySoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color:
                        isPaid
                            ? _success.withOpacity(0.35)
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
                      size: 14,
                      color: isPaid ? _success : _warning,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      dateFormat.format(date),
                      style: GoogleFonts.inter(
                        fontSize: 10,
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
              _buildLegend(_success.withOpacity(0.15), _success, 'Paid'),
              const SizedBox(width: 16),
              _buildLegend(_primarySoft, _warning, 'Not Paid'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(Color bg, Color tone, String label) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: tone.withOpacity(0.45)),
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

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: _surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFDCE5F6)),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF0F172A).withOpacity(0.05),
          blurRadius: 12,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }

  String _periodLabel() {
    switch (widget.committee.frequency) {
      case 'daily':
        return 'Day';
      case 'weekly':
        return 'Week';
      case 'monthly':
        return 'Month';
      default:
        return 'Period';
    }
  }
}
