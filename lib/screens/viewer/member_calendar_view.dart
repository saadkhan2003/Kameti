import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../models/committee.dart';
import '../../models/member.dart';
import '../../services/database_service.dart';
import '../../services/supabase_service.dart';
import 'package:kameti/ui/theme/theme.dart';
import 'member_dashboard_screen.dart';

class MemberCalendarView extends StatefulWidget {
  final Committee committee;
  final Member member;
  final List<Member> members;
  final List<DateTime> dates;
  final int paidCount;
  final int totalDue;
  final double totalContribution;
  final int advanceCount;
  final double advanceAmount;
  final bool Function(String, DateTime) isPaymentMarked;
  final VoidCallback onRefresh;

  const MemberCalendarView({
    super.key,
    required this.committee,
    required this.member,
    required this.members,
    required this.dates,
    required this.paidCount,
    required this.totalDue,
    required this.totalContribution,
    required this.advanceCount,
    required this.advanceAmount,
    required this.isPaymentMarked,
    required this.onRefresh,
  });

  @override
  State<MemberCalendarView> createState() => _MemberCalendarViewState();
}

class _MemberCalendarViewState extends State<MemberCalendarView> {
  static const Color _bg = AppColors.bg;
  static const Color _surface = AppColors.surface;
  static const Color _primary = AppColors.primary;
  static const Color _success = AppColors.success;
  static const Color _warning = AppColors.warning;
  static const Color _info = AppColors.info;
  static const Color _textPrimary = AppColors.textPrimary;
  static const Color _textSecondary = AppColors.textSecondary;
  final _dbService = DatabaseService();

  late DateTime _selectedMonth;
  DateTime? _selectedDate;
  int _selectedCycle = 1;
  int _maxCycles = 1;
  List<DateTime> _cycleDates = [];

  @override
  void initState() {
    super.initState();
    _selectedMonth = DateTime.now();
    _initializeCycleData();
  }

  @override
  void didUpdateWidget(covariant MemberCalendarView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.members.length != widget.members.length ||
        oldWidget.dates.length != widget.dates.length) {
      _initializeCycleData();
    }
  }

  void _initializeCycleData() {
    _maxCycles = _resolveTotalCycles();
    _selectedCycle = _findOngoingCycle();
    _calculateCycleDates();

    final now = DateTime.now();
    if (_cycleDates.isNotEmpty) {
      final cycleStart = _cycleDates.first;
      final cycleEnd = _cycleDates.last;
      if (!now.isBefore(cycleStart) &&
          !now.isAfter(cycleEnd.add(const Duration(days: 1)))) {
        _selectedMonth = DateTime(now.year, now.month);
      } else {
        _selectedMonth = DateTime(cycleStart.year, cycleStart.month);
      }
    }

    // Fire off async fetch to get true member count from cloud (for viewers who
    // only have 1 member synced locally). Total members = Total cycles.
    _fetchTrueCycleCountFromCloud();
  }

  Future<void> _fetchTrueCycleCountFromCloud() async {
    try {
      final supabaseService =
          SupabaseService(); // Make sure SupabaseService is imported
      final members = await supabaseService.getMembers(widget.committee.id);
      if (members.isNotEmpty && members.length > _maxCycles) {
        if (mounted) {
          setState(() {
            _maxCycles = members.length;
            // Re-calculate dates if selected cycle was out of bounds
            if (_selectedCycle > _maxCycles) {
              _selectedCycle = _maxCycles;
              _calculateCycleDates();
            }
          });
        }
      }
    } catch (e) {
      // Ignore if offline
      print('Failed to fetch true cycle count: $e');
    }
  }

  int _resolveTotalCycles() {
    final memberPayments = _dbService.getPaymentsByMember(widget.member.id);

    // Calculate the number of collection periods per payout cycle.
    // For DAILY: 1 collection per day, so periodsPerPayout = 1 (not paymentIntervalDays).
    // For WEEKLY: 1 collection per week.
    // For MONTHLY: 1 collection per month.
    int periodsPerPayout;
    if (widget.committee.frequency == 'daily') {
      periodsPerPayout = 1;
    } else if (widget.committee.frequency == 'weekly') {
      periodsPerPayout = 1;
    } else {
      // monthly
      periodsPerPayout = 1;
    }
    // Each payout cycle spans paymentIntervalDays / collectionInterval collections.
    // However since we are counting PAYOUT CYCLES (not individual collections),
    // cyclesFromPayments = total payments / collections-per-cycle.
    final int collectionInterval =
        widget.committee.frequency == 'daily'
            ? 1
            : widget.committee.frequency == 'weekly'
            ? 7
            : 30;
    final int collectionsPerCycle =
        widget.committee.paymentIntervalDays > 0
            ? (widget.committee.paymentIntervalDays / collectionInterval).ceil()
            : 1;

    final cyclesFromPayments =
        memberPayments.isEmpty
            ? 0
            : (memberPayments.length / collectionsPerCycle).ceil();

    // Calendar-based estimate: how many full payout cycles have elapsed since start?
    final daysSinceStart =
        DateTime.now().difference(widget.committee.startDate).inDays;
    final cyclesElapsed =
        widget.committee.paymentIntervalDays > 0
            ? (daysSinceStart / widget.committee.paymentIntervalDays).ceil()
            : 0;

    // Total payout cycles in a kameti = total members (each member gets one payout).
    // Collect all credible candidate values and take the maximum.
    final candidates =
        <int>[
          widget.members.length,          // members synced locally
          widget.committee.totalMembers,  // stored on the committee record
          widget.committee.totalCycles,   // stored total cycles
          cyclesFromPayments,             // inferred from payment history
          cyclesElapsed,                  // inferred from calendar
          widget.member.payoutOrder,      // member's own slot (lower bound)
        ].where((value) => value > 0).toList();

    if (candidates.isEmpty) return 1;
    candidates.sort();
    return candidates.last;
  }

  int _findOngoingCycle() {
    final startDate = widget.committee.startDate;
    final now = DateTime.now();
    final daysSinceStart = now.difference(startDate).inDays;
    final intervalDays = widget.committee.paymentIntervalDays;
    final cycle = (daysSinceStart / intervalDays).floor() + 1;
    return cycle.clamp(1, _maxCycles);
  }

  void _calculateCycleDates() {
    _cycleDates = [];
    if (_selectedCycle < 1 || _selectedCycle > _maxCycles) return;

    final startDate = widget.committee.startDate;
    final intervalDays = widget.committee.paymentIntervalDays;
    final frequency = widget.committee.frequency;

    final cycleStartDate = startDate.add(
      Duration(days: (intervalDays * (_selectedCycle - 1))),
    );
    final cycleEndDate = startDate.add(
      Duration(days: (intervalDays * _selectedCycle) - 1),
    );

    int collectionInterval = 1;
    if (frequency == 'weekly') collectionInterval = 7;
    if (frequency == 'monthly') collectionInterval = 30;

    DateTime current = cycleStartDate;
    while (!current.isAfter(cycleEndDate)) {
      _cycleDates.add(current);
      current = current.add(Duration(days: collectionInterval));
    }
  }

  void _changeCycle(int delta) {
    setState(() {
      final newCycle = _selectedCycle + delta;
      if (newCycle >= 1 && newCycle <= _maxCycles) {
        _selectedCycle = newCycle;
        _calculateCycleDates();
        final now = DateTime.now();
        if (_cycleDates.isNotEmpty) {
          final cycleStart = _cycleDates.first;
          final cycleEnd = _cycleDates.last;
          if (!now.isBefore(cycleStart) &&
              !now.isAfter(cycleEnd.add(const Duration(days: 1)))) {
            _selectedMonth = DateTime(now.year, now.month);
          } else {
            _selectedMonth = DateTime(cycleStart.year, cycleStart.month);
          }
        }
      }
    });
  }

  int _calculateCyclePaidCount() {
    if (_cycleDates.isEmpty) return 0;
    int paidCount = 0;
    for (final date in _cycleDates) {
      if (widget.isPaymentMarked(widget.member.id, date)) {
        paidCount++;
      }
    }
    return paidCount;
  }

  double _calculateCycleTotalContribution() {
    return _calculateCyclePaidCount() * widget.committee.contributionAmount;
  }

  List<DateTime> _getDaysInMonth(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);

    List<DateTime> days = [];
    int startingWeekday = firstDay.weekday % 7;

    for (int i = 0; i < startingWeekday; i++) {
      days.add(DateTime(month.year, month.month, 1 - (startingWeekday - i)));
    }

    for (int i = 1; i <= lastDay.day; i++) {
      days.add(DateTime(month.year, month.month, i));
    }

    int remainingDays = 42 - days.length;
    for (int i = 1; i <= remainingDays; i++) {
      days.add(DateTime(month.year, month.month + 1, i));
    }

    return days;
  }

  bool _isPaymentDateForMember(DateTime date) {
    final frequency = widget.committee.frequency;
    for (final paymentDate in _cycleDates) {
      if (frequency == 'monthly') {
        if (paymentDate.year == date.year &&
            paymentDate.month == date.month &&
            paymentDate.day == date.day) {
          return true;
        }
      } else if (_isSameDay(paymentDate, date)) {
        return true;
      }
    }
    return false;
  }

  bool _isInCurrentMonth(DateTime date) {
    return date.month == _selectedMonth.month &&
        date.year == _selectedMonth.year;
  }

  @override
  Widget build(BuildContext context) {
    final days = _getDaysInMonth(_selectedMonth);
    final weekDays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(AppIcons.arrow_back, color: _textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.committee.name,
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: _textPrimary,
              ),
            ),
            Text(
              'Welcome, ${widget.member.name}',
              style: GoogleFonts.inter(fontSize: 12, color: _textSecondary),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(AppIcons.refresh, color: _textSecondary),
            onPressed: widget.onRefresh,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.lightBorder),
              boxShadow: [
                BoxShadow(
                  color: AppColors.darkBg.withOpacity(0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Flexible(
                      child: _buildStatItem(
                        'Paid',
                        '${_calculateCyclePaidCount()} / ${_cycleDates.length}',
                        AppIcons.check_circle,
                        _success,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 34,
                      color: AppColors.borderMuted,
                    ),
                    Flexible(
                      child: _buildStatItem(
                        'Contributed',
                        '${widget.committee.currency} ${_calculateCycleTotalContribution().toStringAsFixed(0)}',
                        AppIcons.account_balance_wallet,
                        _primary,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 34,
                      color: AppColors.borderMuted,
                    ),
                    Flexible(
                      child: _buildStatItem(
                        _getFrequencyLabel(),
                        '${widget.committee.currency} ${widget.committee.contributionAmount.toStringAsFixed(0)}',
                        AppIcons.calendar_today,
                        _warning,
                      ),
                    ),
                  ],
                ),
                if (widget.advanceCount > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _info.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _info.withOpacity(0.25)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          AppIcons.star_rounded,
                          color: _info,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '${widget.advanceCount} advance payment${widget.advanceCount > 1 ? 's' : ''} • +${widget.committee.currency} ${widget.advanceAmount.toStringAsFixed(0)}',
                            style: GoogleFonts.inter(
                              color: _info,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          _buildCycleSelector(),
          _buildMonthSelector(),

          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children:
                  weekDays
                      .map(
                        (day) => Expanded(
                          child: Center(
                            child: Text(
                              day,
                              style: GoogleFonts.inter(
                                color: _textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
            ),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.lightBorder),
              ),
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: 1,
                ),
                itemCount: days.length,
                itemBuilder: (context, index) {
                  final date = days[index];
                  final now = DateTime.now();
                  final isFutureDate = date.isAfter(now);
                  final isPaymentDate = _isPaymentDateForMember(date);
                  final isPaid =
                      isPaymentDate &&
                      widget.isPaymentMarked(widget.member.id, date);
                  final isAdvancePaid = isPaid && isFutureDate;
                  final isCurrentMonth = _isInCurrentMonth(date);
                  final isToday = _isSameDay(date, DateTime.now());
                  final isSelected =
                      _selectedDate != null && _isSameDay(date, _selectedDate!);

                  return GestureDetector(
                    onTap: () {
                      if (isCurrentMonth && isPaymentDate) {
                        setState(() => _selectedDate = date);
                        _showPaymentDetails(date, isPaid, isAdvancePaid);
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? _primary.withOpacity(0.2)
                                : (isAdvancePaid && isCurrentMonth)
                                ? _info.withOpacity(0.18)
                                : (isPaid && isCurrentMonth)
                                ? _success.withOpacity(0.15)
                                : (isPaymentDate && isCurrentMonth && !isPaid)
                                ? _warning.withOpacity(0.12)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border:
                            isToday
                                ? Border.all(color: _primary, width: 1.8)
                                : isAdvancePaid
                                ? Border.all(color: _info, width: 1)
                                : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${date.day}',
                            style: GoogleFonts.inter(
                              color:
                                  isCurrentMonth
                                      ? _textPrimary
                                      : AppColors.cFFA2ADBF,
                              fontWeight:
                                  isToday ? FontWeight.w700 : FontWeight.w500,
                              fontSize: 12,
                            ),
                          ),
                          if (isPaymentDate && isCurrentMonth) ...[
                            const SizedBox(height: 2),
                            Icon(
                              isPaid ? AppIcons.paid : AppIcons.circle_outlined,
                              size: 13,
                              color: isPaid ? _success : _warning,
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendPaid(),
                const SizedBox(width: 16),
                _buildLegendAdvance(),
                const SizedBox(width: 16),
                _buildLegendPending(),
              ],
            ),
          ),

          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              MediaQuery.of(context).padding.bottom + 16,
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => MemberDashboardScreen(
                            committee: widget.committee,
                            member: widget.member,
                          ),
                    ),
                  );
                },
                icon: const Icon(AppIcons.dashboard_rounded),
                label: const Text('More Details'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCycleSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightBorder, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: Icon(
              AppIcons.chevron_left,
              color: _selectedCycle > 1 ? _textPrimary : AppColors.cFFB0B8C9,
              size: 20,
            ),
            onPressed: _selectedCycle > 1 ? () => _changeCycle(-1) : null,
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'Cycle $_selectedCycle of $_maxCycles',
                  style: GoogleFonts.inter(
                    color: _textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (_cycleDates.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${DateFormat('dd/MM/yyyy').format(_cycleDates.first)} - ${DateFormat('dd/MM/yyyy').format(_cycleDates.last)}',
                    style: GoogleFonts.inter(
                      color: _textSecondary,
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: Icon(
              AppIcons.chevron_right,
              color:
                  _selectedCycle < _maxCycles
                      ? _textPrimary
                      : AppColors.cFFB0B8C9,
              size: 20,
            ),
            onPressed:
                _selectedCycle < _maxCycles ? () => _changeCycle(1) : null,
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: const Icon(
              AppIcons.chevron_left,
              color: _textPrimary,
              size: 20,
            ),
            onPressed: () {
              setState(() {
                _selectedMonth = DateTime(
                  _selectedMonth.year,
                  _selectedMonth.month - 1,
                );
              });
            },
          ),
          Text(
            '${_getMonthName(_selectedMonth.month)} ${_selectedMonth.year}',
            style: GoogleFonts.inter(
              color: _textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: const Icon(
              AppIcons.chevron_right,
              color: _textPrimary,
              size: 20,
            ),
            onPressed: () {
              setState(() {
                _selectedMonth = DateTime(
                  _selectedMonth.year,
                  _selectedMonth.month + 1,
                );
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color tone) {
    return Column(
      children: [
        Icon(icon, color: tone, size: 17),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.inter(
            color: _textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          textAlign: TextAlign.center,
        ),
        Text(
          label,
          style: GoogleFonts.inter(color: _textSecondary, fontSize: 10),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLegendPaid() {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: _success.withOpacity(0.15),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: _success),
          ),
          child: const Icon(AppIcons.check, size: 12, color: _success),
        ),
        const SizedBox(width: 8),
        Text(
          'Paid',
          style: GoogleFonts.inter(color: _textSecondary, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildLegendAdvance() {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: _info.withOpacity(0.15),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: _info),
          ),
          child: const Icon(AppIcons.check, size: 12, color: _info),
        ),
        const SizedBox(width: 8),
        Text(
          'Advance',
          style: GoogleFonts.inter(color: _textSecondary, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildLegendPending() {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          alignment: Alignment.center,
          child: const Icon(
            AppIcons.circle_outlined,
            size: 14,
            color: _warning,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'Pending',
          style: GoogleFonts.inter(color: _textSecondary, fontSize: 11),
        ),
      ],
    );
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  String _getFrequencyLabel() {
    switch (widget.committee.frequency) {
      case 'daily':
        return 'Per Day';
      case 'weekly':
        return 'Per Week';
      case 'monthly':
        return 'Per Month';
      default:
        return 'Per Period';
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _showPaymentDetails(DateTime date, bool isPaid, bool isAdvancePaid) {
    int dayNumber = 0;
    for (int i = 0; i < widget.dates.length; i++) {
      if (_isSameDay(widget.dates[i], date)) {
        dayNumber = i + 1;
        break;
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            isAdvancePaid
                                ? _info.withOpacity(0.15)
                                : isPaid
                                ? _success.withOpacity(0.15)
                                : _warning.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isAdvancePaid
                            ? AppIcons.star_rounded
                            : isPaid
                            ? AppIcons.paid
                            : AppIcons.schedule,
                        color:
                            isAdvancePaid
                                ? _info
                                : isPaid
                                ? _success
                                : _warning,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${date.day} ${_getMonthName(date.month)} ${date.year}',
                            style: GoogleFonts.inter(
                              color: _textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            isAdvancePaid
                                ? 'Paid in Advance ⭐'
                                : isPaid
                                ? 'Payment Completed'
                                : 'Payment Pending',
                            style: GoogleFonts.inter(
                              color:
                                  isAdvancePaid
                                      ? _info
                                      : isPaid
                                      ? _success
                                      : _warning,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _buildDetailRow(
                  'Amount',
                  '${widget.committee.currency} ${widget.committee.contributionAmount.toStringAsFixed(0)}',
                ),
                _buildDetailRow(
                  _getPeriodLabel(),
                  '$_getPeriodPrefix $dayNumber',
                ),
                _buildDetailRow(
                  'Status',
                  isAdvancePaid
                      ? 'Advance ⭐'
                      : isPaid
                      ? 'Paid ✓'
                      : 'Pending',
                ),
              ],
            ),
          ),
    );
  }

  String get _getPeriodPrefix {
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

  String _getPeriodLabel() {
    switch (widget.committee.frequency) {
      case 'daily':
        return 'Day Number';
      case 'weekly':
        return 'Week Number';
      case 'monthly':
        return 'Month Number';
      default:
        return 'Period Number';
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(color: _textSecondary, fontSize: 13),
          ),
          Text(
            value,
            style: GoogleFonts.inter(
              color: _textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
