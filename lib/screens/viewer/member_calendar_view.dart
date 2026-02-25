import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/committee.dart';
import '../../models/member.dart';
import '../../utils/app_theme.dart';
import 'member_dashboard_screen.dart';

/// A calendar view widget for viewing member payments by cycle.
/// Shows payment dates with tick marks and allows cycle navigation.
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
    // Recalculate when widget properties change
    if (oldWidget.members.length != widget.members.length ||
        oldWidget.dates.length != widget.dates.length) {
      _initializeCycleData();
    }
  }

  void _initializeCycleData() {
    _maxCycles = widget.members.isNotEmpty ? widget.members.length : 1;
    _selectedCycle = _findOngoingCycle();
    _calculateCycleDates();
    // Set selected month to today's month if it's within the cycle, otherwise use cycle start
    final now = DateTime.now();
    if (_cycleDates.isNotEmpty) {
      // Check if today is within the cycle range
      final cycleStart = _cycleDates.first;
      final cycleEnd = _cycleDates.last;
      if (!now.isBefore(cycleStart) && !now.isAfter(cycleEnd.add(const Duration(days: 1)))) {
        // Today is within this cycle, show current month
        _selectedMonth = DateTime(now.year, now.month);
      } else {
        // Today is not in this cycle, show cycle's first month
        _selectedMonth = DateTime(cycleStart.year, cycleStart.month);
      }
    }
  }

  int _findOngoingCycle() {
    final startDate = widget.committee.startDate;
    final now = DateTime.now();
    final daysSinceStart = now.difference(startDate).inDays;
    final intervalDays = widget.committee.paymentIntervalDays;
    
    // Calculate which cycle we're in
    final cycle = (daysSinceStart / intervalDays).floor() + 1;
    
    // Ensure it's within valid range
    return cycle.clamp(1, _maxCycles);
  }

  void _calculateCycleDates() {
    _cycleDates = [];
    if (_selectedCycle < 1 || _selectedCycle > _maxCycles) return;

    final startDate = widget.committee.startDate;
    final intervalDays = widget.committee.paymentIntervalDays;
    final frequency = widget.committee.frequency;
    
    // Calculate the start and end date for this cycle
    final cycleStartDate = startDate.add(Duration(days: (intervalDays * (_selectedCycle - 1))));
    final cycleEndDate = startDate.add(Duration(days: (intervalDays * _selectedCycle) - 1));

    // Generate all payment dates for this cycle based on frequency
    int collectionInterval = 1; // daily
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
        // If today is within the new cycle, show today's month
        // Otherwise show the first month of the cycle
        final now = DateTime.now();
        if (_cycleDates.isNotEmpty) {
          final cycleStart = _cycleDates.first;
          final cycleEnd = _cycleDates.last;
          if (!now.isBefore(cycleStart) && !now.isAfter(cycleEnd.add(const Duration(days: 1)))) {
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
    for (var date in _cycleDates) {
      if (widget.isPaymentMarked(widget.member.id, date)) {
        paidCount++;
      }
    }
    return paidCount;
  }

  double _calculateCycleTotalContribution() {
    int paidCount = _calculateCyclePaidCount();
    return paidCount * widget.committee.contributionAmount;
  }

  List<DateTime> _getDaysInMonth(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);

    List<DateTime> days = [];
    int startingWeekday = firstDay.weekday % 7; // Sunday = 0

    // Days from prev month
    for (int i = 0; i < startingWeekday; i++) {
      days.add(DateTime(month.year, month.month, 1 - (startingWeekday - i)));
    }

    // Days of current month
    for (int i = 1; i <= lastDay.day; i++) {
      days.add(DateTime(month.year, month.month, i));
    }

    // Days of next month
    int remainingDays = 42 - days.length;
    for (int i = 1; i <= remainingDays; i++) {
      days.add(DateTime(month.year, month.month + 1, i));
    }

    return days;
  }

  bool _isPaymentDateForMember(DateTime date) {
    final frequency = widget.committee.frequency;
    // Check against cycle-filtered dates instead of all dates
    for (var paymentDate in _cycleDates) {
      if (frequency == 'monthly') {
        if (paymentDate.year == date.year &&
            paymentDate.month == date.month &&
            paymentDate.day == date.day) {
          return true;
        }
      } else if (frequency == 'weekly') {
        if (_isSameDay(paymentDate, date)) {
          return true;
        }
      } else {
        if (_isSameDay(paymentDate, date)) {
          return true;
        }
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
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: AppTheme.darkSurface,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.committee.name, style: const TextStyle(fontSize: 18)),
            Text(
              'Welcome, ${widget.member.name}',
              style: TextStyle(fontSize: 14, color: Colors.grey[400]),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: widget.onRefresh,
          ),
        ],
      ),
      body: Column(
        children: [
          // Stats Card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryColor.withOpacity(0.8),
                  AppTheme.secondaryColor.withOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Flexible(
                      child: _buildStatItem(
                        'Paid',
                        '${_calculateCyclePaidCount()} / ${_cycleDates.length}',
                        Icons.check_circle,
                      ),
                    ),
                    Container(width: 1, height: 40, color: Colors.white24),
                    Flexible(
                      child: _buildStatItem(
                        'Contributed',
                        'PKR ${_calculateCycleTotalContribution().toStringAsFixed(0)}',
                        Icons.account_balance_wallet,
                      ),
                    ),
                    Container(width: 1, height: 40, color: Colors.white24),
                    Flexible(
                      child: _buildStatItem(
                        _getFrequencyLabel(),
                        'PKR ${widget.committee.contributionAmount.toStringAsFixed(0)}',
                        Icons.calendar_today,
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
                      color: Colors.blue.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.5)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.star, color: Colors.white, size: 18),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '${widget.advanceCount} advance payment${widget.advanceCount > 1 ? 's' : ''} • +PKR ${widget.advanceAmount.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
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

          // Cycle Selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.darkSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primaryColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.chevron_left,
                    color: _selectedCycle > 1 ? Colors.white : Colors.grey[700],
                  ),
                  onPressed: _selectedCycle > 1 ? () => _changeCycle(-1) : null,
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        'Cycle $_selectedCycle of $_maxCycles',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (_cycleDates.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${DateFormat('dd/MM/yyyy').format(_cycleDates.first)} - ${DateFormat('dd/MM/yyyy').format(_cycleDates.last)}',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 11,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.chevron_right,
                    color: _selectedCycle < _maxCycles ? Colors.white : Colors.grey[700],
                  ),
                  onPressed: _selectedCycle < _maxCycles ? () => _changeCycle(1) : null,
                ),
              ],
            ),
          ),

          // Month Navigator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left, color: Colors.white),
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right, color: Colors.white),
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
          ),

          // Week days header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children:
                  weekDays
                      .map(
                        (day) => Expanded(
                          child: Center(
                            child: Text(
                              day,
                              style: TextStyle(
                                color: Colors.grey[500],
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

          // Calendar Grid
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
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
                        setState(() {
                          _selectedDate = date;
                        });
                        _showPaymentDetails(date, isPaid, isAdvancePaid);
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color:
                            isSelected
                                ? AppTheme.primaryColor.withOpacity(0.3)
                                : (isAdvancePaid && isCurrentMonth)
                                ? Colors.blue.withOpacity(0.3)
                                : (isPaid && isCurrentMonth)
                                ? Colors.green.withOpacity(0.2)
                                : (isPaymentDate && isCurrentMonth && !isPaid)
                                ? Colors.orange.withOpacity(0.1)
                                : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border:
                            isToday
                                ? Border.all(
                                  color: AppTheme.primaryColor,
                                  width: 2,
                                )
                                : isAdvancePaid
                                ? Border.all(color: Colors.blue, width: 1)
                                : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${date.day}',
                            style: TextStyle(
                              color:
                                  isCurrentMonth
                                      ? Colors.white
                                      : Colors.grey[700],
                              fontWeight:
                                  isToday ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          if (isPaymentDate && isCurrentMonth) ...[
                            const SizedBox(height: 2),
                            Icon(
                              isPaid
                                  ? Icons.check_circle
                                  : Icons.circle_outlined,
                              size: 14,
                              color: isPaid ? Colors.green : Colors.orange,
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

          // Legend
          Container(
            padding: const EdgeInsets.all(16),
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

          // More Details Button
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MemberDashboardScreen(
                        committee: widget.committee,
                        member: widget.member,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.dashboard_rounded),
                label: const Text('More Details'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
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

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
        ),
      ],
    );
  }

  // Paid: Green check in rounded square
  Widget _buildLegendPaid() {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.3),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.green),
          ),
          child: const Icon(Icons.check, size: 12, color: Colors.green),
        ),
        const SizedBox(width: 8),
        Text('Paid', style: TextStyle(color: Colors.grey[400])),
      ],
    );
  }

  // Advance: Blue check in rounded square
  Widget _buildLegendAdvance() {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.3),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.blue),
          ),
          child: const Icon(Icons.check, size: 12, color: Colors.blue),
        ),
        const SizedBox(width: 8),
        Text('Advance', style: TextStyle(color: Colors.grey[400])),
      ],
    );
  }

  // Pending: Orange circle outline
  Widget _buildLegendPending() {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          alignment: Alignment.center,
          child: const Icon(Icons.circle_outlined, size: 14, color: Colors.orange),
        ),
        const SizedBox(width: 8),
        Text('Pending', style: TextStyle(color: Colors.grey[400])),
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
      backgroundColor: AppTheme.darkSurface,
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
                                ? Colors.blue.withOpacity(0.2)
                                : isPaid
                                ? Colors.green.withOpacity(0.2)
                                : Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        isAdvancePaid
                            ? Icons.star
                            : isPaid
                            ? Icons.check_circle
                            : Icons.schedule,
                        color:
                            isAdvancePaid
                                ? Colors.blue
                                : isPaid
                                ? Colors.green
                                : Colors.orange,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${date.day} ${_getMonthName(date.month)} ${date.year}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          isAdvancePaid
                              ? 'Paid in Advance ⭐'
                              : isPaid
                              ? 'Payment Completed'
                              : 'Payment Pending',
                          style: TextStyle(
                            color:
                                isAdvancePaid
                                    ? Colors.blue
                                    : isPaid
                                    ? Colors.green
                                    : Colors.orange,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _buildDetailRow(
                  'Amount',
                  'PKR ${widget.committee.contributionAmount.toStringAsFixed(0)}',
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
                const SizedBox(height: 16),
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
          Text(label, style: TextStyle(color: Colors.grey[400])),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
