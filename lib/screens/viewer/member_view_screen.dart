import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../services/database_service.dart';
import '../../services/sync_service.dart';
import '../../models/committee.dart';
import '../../models/member.dart';
import '../../models/payment.dart';
import '../../utils/app_theme.dart';

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
  final _dbService = DatabaseService();
  final _syncService = SyncService();
  List<DateTime> _dates = [];
  int _paidCount = 0;
  int _totalDays = 0;
  bool _isRefreshing = false;
  bool _isFirstLoad = true; // Track if this is initial load
  
  // Cycle support
  int _selectedCycle = 1;
  int _maxCycles = 1;
  List<Member> _members = [];

  @override
  void initState() {
    super.initState();
    _loadData();
    // Auto-sync on first load
    _refreshFromCloud();
  }

  void _loadData() {
    // Load members to calculate max cycles
    _members = _dbService.getMembersByCommittee(widget.committee.id);
    _maxCycles = _members.isNotEmpty ? _members.length : 1;
    
    debugPrint('');
    debugPrint('╔════════════════════════════════════════════════════════════╗');
    debugPrint('║             MEMBER VIEW DATA LOAD                          ║');
    debugPrint('╠════════════════════════════════════════════════════════════╣');
    debugPrint('║ Committee: ${widget.committee.name}');
    debugPrint('║ Committee ID: ${widget.committee.id}');
    debugPrint('║ START DATE: ${widget.committee.startDate}');
    debugPrint('║ Frequency: ${widget.committee.frequency}');
    debugPrint('║ Payout Interval: ${widget.committee.paymentIntervalDays} days');
    debugPrint('║ Members: ${_members.length} → MaxCycles: $_maxCycles');
    debugPrint('╚════════════════════════════════════════════════════════════╝');
    
    // Default to ongoing cycle on first load only
    if (_isFirstLoad) {
      final ongoingCycle = _findOngoingCycle();
      debugPrint('🎯 First load - Setting to ongoing cycle: $ongoingCycle');
      _selectedCycle = ongoingCycle;
      _isFirstLoad = false;
    }
    
    // Keep selected cycle in valid range
    if (_selectedCycle > _maxCycles) _selectedCycle = _maxCycles;
    if (_selectedCycle < 1) _selectedCycle = 1;
    
    debugPrint('🎯 Current selected cycle: $_selectedCycle / $_maxCycles');
    
    _generateDates();
    _calculateStats();
    debugPrint('');
  }

  /// Find which cycle is currently ongoing based on today's date
  int _findOngoingCycle() {
    final now = DateTime.now();
    final committeeStartDate = widget.committee.startDate;
    final payoutIntervalDays = widget.committee.paymentIntervalDays;

    debugPrint('🔍 Finding ongoing cycle...');
    debugPrint('🔍 Now: $now');
    debugPrint('🔍 Committee Start: $committeeStartDate');
    debugPrint('🔍 Payout Interval: $payoutIntervalDays days');

    // Calculate periods per payout based on frequency
    int periodsPerPayout;
    if (widget.committee.frequency == 'monthly') {
      periodsPerPayout = (payoutIntervalDays / 30).ceil();
      if (periodsPerPayout < 1) periodsPerPayout = 1;
    } else if (widget.committee.frequency == 'weekly') {
      periodsPerPayout = (payoutIntervalDays / 7).ceil();
      if (periodsPerPayout < 1) periodsPerPayout = 1;
    } else {
      // Daily frequency
      periodsPerPayout = payoutIntervalDays;
      if (periodsPerPayout < 1) periodsPerPayout = 1;
    }

    debugPrint('🔍 Periods per payout: $periodsPerPayout');

    // Check each cycle to find the one that contains today
    for (int cycle = 1; cycle <= _maxCycles; cycle++) {
      DateTime cycleStartDate;
      DateTime cycleEndDate;

      if (widget.committee.frequency == 'monthly') {
        cycleStartDate = _addMonths(committeeStartDate, (cycle - 1) * periodsPerPayout);
        cycleEndDate = _addMonths(cycleStartDate, periodsPerPayout);
        cycleEndDate = cycleEndDate.subtract(const Duration(days: 1));
      } else {
        final daysOffset = (cycle - 1) * payoutIntervalDays;
        cycleStartDate = committeeStartDate.add(Duration(days: daysOffset));
        cycleEndDate = cycleStartDate.add(Duration(days: payoutIntervalDays - 1));
      }

      debugPrint('🔍 Cycle $cycle: ${DateFormat('yyyy-MM-dd').format(cycleStartDate)} to ${DateFormat('yyyy-MM-dd').format(cycleEndDate)}');

      // Check if today is within this cycle
      if (!now.isBefore(cycleStartDate) && !now.isAfter(cycleEndDate)) {
        debugPrint('🔍 ✅ Cycle $cycle is ONGOING');
        return cycle;
      }
      
      // If today is before this cycle starts, return the previous cycle (or 1)
      if (now.isBefore(cycleStartDate)) {
        final result = cycle > 1 ? cycle - 1 : 1;
        debugPrint('🔍 Today is before cycle $cycle, returning cycle $result');
        return result;
      }
    }

    // If we've passed all cycles, return the last one
    debugPrint('🔍 Passed all cycles, returning $_maxCycles');
    return _maxCycles;
  }

  // Helper to safely add months without skipping (e.g., Jan 31 -> Feb 28)
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

    debugPrint('📅 Generating dates - Start: $committeeStartDate, Interval: $payoutIntervalDays, Frequency: ${widget.committee.frequency}');

    // Use collection frequency to determine interval between collection dates
    int collectionInterval = 30;
    if (widget.committee.frequency == 'daily') collectionInterval = 1;
    if (widget.committee.frequency == 'weekly') collectionInterval = 7;
    if (widget.committee.frequency == 'monthly') collectionInterval = 30;

    // Calculate how many collection periods fit in one payout cycle
    int periodsPerPayout;
    if (widget.committee.frequency == 'monthly') {
      periodsPerPayout = (payoutIntervalDays / 30).ceil();
      if (periodsPerPayout < 1) periodsPerPayout = 1;
    } else {
      periodsPerPayout = (payoutIntervalDays / collectionInterval).ceil();
      if (periodsPerPayout < 1) periodsPerPayout = 1;
    }

    debugPrint('📅 Collection interval: $collectionInterval, Periods per payout: $periodsPerPayout');

    // Calculate start date for the selected payout cycle
    DateTime cycleStartDate;
    if (widget.committee.frequency == 'monthly') {
      cycleStartDate = _addMonths(committeeStartDate, (_selectedCycle - 1) * periodsPerPayout);
    } else {
      final daysOffset = (_selectedCycle - 1) * payoutIntervalDays;
      cycleStartDate = committeeStartDate.add(Duration(days: daysOffset));
    }

    debugPrint('📅 Cycle $_selectedCycle start date: $cycleStartDate');

    // Generate exactly periodsPerPayout dates for this payout cycle
    // LIMIT to 35 days (5 weeks) for daily committees to avoid calendar overflow
    final maxDatesToShow = widget.committee.frequency == 'daily' ? 35 : periodsPerPayout;
    final datesToGenerate = periodsPerPayout < maxDatesToShow ? periodsPerPayout : maxDatesToShow;
    
    DateTime current = cycleStartDate;
    for (int i = 0; i < datesToGenerate; i++) {
      _dates.add(current);
      if (widget.committee.frequency == 'monthly') {
        current = _addMonths(current, 1);
      } else {
        current = current.add(Duration(days: collectionInterval));
      }
    }
    
    debugPrint('📅 Generated ${_dates.length} dates (limit: $maxDatesToShow) for cycle $_selectedCycle');
  }

  void _calculateStats() {
    _totalDays = _dates.length;
    _paidCount = 0;

    debugPrint('💰 Calculating stats for CYCLE $_selectedCycle (${_dates.length} dates)');
    
    for (final date in _dates) {
      final payment = _dbService.getPayment(widget.member.id, date);
      final isPaid = payment != null && payment.isPaid;
      if (isPaid) {
        _paidCount++;
      }
    }
    
    debugPrint('💰 Cycle $_selectedCycle stats: $_paidCount / $_totalDays paid');
    setState(() {});
  }

  /// Sync fresh data from Supabase cloud (READ-ONLY for viewers)
  Future<void> _refreshFromCloud() async {
    if (_isRefreshing) return;
    
    setState(() => _isRefreshing = true);
    
    try {
      debugPrint('🔄 Starting viewer refresh for committee: ${widget.committee.id}');
      
      // Use the new read-only refresh method
      await _syncService.refreshViewerData(widget.committee.id);
      
      // Reload local data
      _loadData();
      
      // Debug: print payment counts and dates
      final allPayments = _dbService.getPaymentsByCommittee(widget.committee.id);
      final memberPayments = allPayments.where((p) => p.memberId == widget.member.id).toList();
      debugPrint('✅ Total payments for committee: ${allPayments.length}');
      debugPrint('✅ Payments for member ${widget.member.name}: ${memberPayments.length}');
      
      // Show sample of payment dates for this member
      if (memberPayments.isNotEmpty) {
        final sortedPayments = memberPayments..sort((a, b) => a.date.compareTo(b.date));
        debugPrint('✅ First 5 payment dates: ${sortedPayments.take(5).map((p) => "${DateFormat('yyyy-MM-dd').format(p.date)} (paid: ${p.isPaid})").toList()}');
        debugPrint('✅ Last 5 payment dates: ${sortedPayments.reversed.take(5).map((p) => "${DateFormat('yyyy-MM-dd').format(p.date)} (paid: ${p.isPaid})").toList()}');
      }
      
      debugPrint('✅ Paid count for current cycle: $_paidCount / $_totalDays');
      
    } catch (e) {
      debugPrint('❌ Viewer sync error: $e');
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  /// Check if the currently selected cycle is ongoing
  bool _isCurrentCycleOngoing() {
    if (_dates.isEmpty) return false;
    final now = DateTime.now();
    final cycleStart = _dates.first;
    final cycleEnd = _dates.last;
    return !now.isBefore(cycleStart) && !now.isAfter(cycleEnd.add(const Duration(days: 1)));
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
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.committee.name),
            Text(
              'Welcome, ${widget.member.name}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        actions: [
          _isRefreshing
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh from cloud',
                  onPressed: _refreshFromCloud,
                ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Member Info Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.secondaryColor, Color(0xFF059669)],
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        widget.committee.name,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white70, size: 20),
                        onPressed: () {
                          _selectedCycle = 1;
                          _loadData();
                        },
                        tooltip: 'Refresh',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  Text(
                    'Welcome, ${widget.member.name}',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Stats Row - These update with cycle
                  Row(
                    children: [
                      // Paid count
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.check_circle, color: Colors.white, size: 22),
                              const SizedBox(height: 4),
                              Text(
                                '$_paidCount / $_totalDays',
                                style: GoogleFonts.inter(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'Paid',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Amount Contributed
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.payments, color: Colors.white, size: 22),
                              const SizedBox(height: 4),
                              Text(
                                'PKR ${(_paidCount * widget.committee.contributionAmount).toInt()}',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'Contributed',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Per Day/Period
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: [
                              Icon(Icons.calendar_today, color: Colors.white, size: 22),
                              const SizedBox(height: 4),
                              Text(
                                'PKR ${widget.committee.contributionAmount.toInt()}',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'Per ${widget.committee.frequency == 'daily' ? 'Day' : widget.committee.frequency == 'weekly' ? 'Week' : 'Month'}',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Payment History
            Text(
              'Payment History',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[400],
              ),
            ),
            const SizedBox(height: 12),

            // Payment Grid
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: _dates.length,
              itemBuilder: (context, index) {
                final date = _dates[index];
                final isPaid = _isPaymentMarked(date);
                final format = widget.committee.frequency == 'monthly'
                    ? DateFormat('MMM')
                    : DateFormat('d');

                return Container(
                  decoration: BoxDecoration(
                    color:
                        isPaid ? AppTheme.secondaryColor : Colors.grey[800],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isPaid)
                        const Icon(Icons.check, color: Colors.white, size: 14)
                      else
                        const Icon(Icons.close, color: Colors.grey, size: 14),
                      const SizedBox(height: 2),
                      Text(
                        format.format(date),
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          color: isPaid ? Colors.white : Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // Cycle Selector
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.darkCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: _selectedCycle > 1 ? () => _changeCycle(-1) : null,
                    icon: Icon(
                      Icons.chevron_left,
                      color: _selectedCycle > 1 ? Colors.white : Colors.grey[600],
                    ),
                  ),
                  Column(
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Cycle $_selectedCycle of $_maxCycles',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          if (_isCurrentCycleOngoing()) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.orange.withOpacity(0.5)),
                              ),
                              child: Text(
                                'ONGOING',
                                style: GoogleFonts.inter(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (_dates.isNotEmpty)
                        Text(
                          '${DateFormat('MMM d').format(_dates.first)} - ${DateFormat('MMM d, yyyy').format(_dates.last)}',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.grey[400],
                          ),
                        ),
                    ],
                  ),
                  IconButton(
                    onPressed: _selectedCycle < _maxCycles ? () => _changeCycle(1) : null,
                    icon: Icon(
                      Icons.chevron_right,
                      color: _selectedCycle < _maxCycles ? Colors.white : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegend(AppTheme.secondaryColor, 'Paid'),
                const SizedBox(width: 24),
                _buildLegend(Colors.grey[800]!, 'Not Paid'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[500],
          ),
        ),
      ],
    );
  }
}
