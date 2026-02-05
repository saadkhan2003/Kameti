import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

// Project imports
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/export_service.dart';
import '../../services/auto_sync_service.dart';
import '../../services/sync_service.dart';
import '../../services/analytics_service.dart';
import '../../services/toast_service.dart';
import '../../models/committee.dart';
import '../../models/member.dart';
import '../../models/payment.dart';
import '../../utils/app_theme.dart';
import 'member_management_screen.dart';
import '../viewer/member_dashboard_screen.dart';
import '../viewer/member_calendar_view.dart';

class PaymentSheetScreen extends StatefulWidget {
  final Committee committee;
  final Member? viewAsMember;

  const PaymentSheetScreen({
    super.key,
    required this.committee,
    this.viewAsMember,
  });

  @override
  State<PaymentSheetScreen> createState() => _PaymentSheetScreenState();
}

class _PaymentSheetScreenState extends State<PaymentSheetScreen> {
  final _dbService = DatabaseService();
  final _authService = AuthService();
  final _exportService = ExportService();
  final _autoSyncService = AutoSyncService();
  final SyncService _syncService = SyncService();

  List<Member> _members = [];
  List<DateTime> _dates = [];
  Map<String, Map<String, bool>> _paymentGrid = {};
  List<Payment> _cloudPayments = []; // Payments fetched from cloud
  bool _isLoading = true;
  String? _errorMessage;
  int _selectedCycle = 1;
  int _maxCycles = 1;

  // Date filter
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;

  // Number of extra future periods to show (for advance payments)
  int _extraPeriods = 1;

  @override
  void initState() {
    super.initState();
    _syncAndLoad();
  }

  Future<void> _syncAndLoad() async {
    // Load from local FIRST (fast, non-blocking)
    await _loadDataFromLocal();
    
    // Then sync in background (don't await - may hang on web)
    _syncInBackground();
  }

  void _syncInBackground() {
    // Fire and forget - don't block UI
    Future(() async {
      try {
        // If viewing as member (viewer mode), use read-only sync
        if (widget.viewAsMember != null) {
          await _syncService.refreshViewerData(widget.committee.id);
        } else {
          // Host mode - can write
          await _syncService.syncMembers(widget.committee.id);
          await _syncService.syncPayments(widget.committee.id);
        }
        // Reload after sync completes
        if (mounted) {
          _loadPaymentsFromLocal();
          setState(() {});
        }
      } catch (e) {
        debugPrint('Background sync error: $e');
      }
    });
  }

  Future<void> _loadDataFromLocal() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    _members = _dbService.getMembersByCommittee(widget.committee.id);
    _members.sort((a, b) => a.payoutOrder.compareTo(b.payoutOrder));

    final allPayments = _dbService.getPaymentsByCommittee(widget.committee.id);
    _maxCycles = _computeMaxCycles(allPayments);

    // Calculate which cycle contains today's date
    _selectedCycle = _calculateCycleForToday();
    if (_selectedCycle < 1) _selectedCycle = 1;
    if (_selectedCycle > _maxCycles) {
      _selectedCycle = _maxCycles;
    }
    _dbService.setSelectedCycle(widget.committee.id, _selectedCycle);

    _generateDates();
    _loadPaymentsFromLocal();

    if (mounted) setState(() => _isLoading = false);
  }

  /// Calculate which cycle contains today's date
  int _calculateCycleForToday() {
    final today = DateTime.now();
    final committeeStartDate = widget.committee.startDate;
    final payoutIntervalDays = widget.committee.paymentIntervalDays;
    
    // If today is before the committee start date, return cycle 1
    if (today.isBefore(committeeStartDate)) {
      return 1;
    }
    
    // Calculate which cycle today falls into
    final daysSinceStart = today.difference(committeeStartDate).inDays;
    final cycleNumber = (daysSinceStart ~/ payoutIntervalDays) + 1;
    
    return cycleNumber;
  }

  Future<void> _loadData() async {
    await _loadDataFromLocal();
  }

  // Helper to safely add months without skipping (e.g., Jan 31 -> Feb 28)
  DateTime _addMonths(DateTime date, int monthsToAdd) {
    var newYear = date.year;
    var newMonth = date.month + monthsToAdd;

    // Adjust year if month goes over 12
    while (newMonth > 12) {
      newYear++;
      newMonth -= 12;
    }

    // Determine the last day of the target month
    final firstDayOfNextMonth = DateTime(newYear, newMonth + 1, 1);
    final lastDayOfTargetMonth =
        firstDayOfNextMonth.subtract(const Duration(days: 1)).day;

    // Clamp the day
    final newDay =
        (date.day > lastDayOfTargetMonth) ? lastDayOfTargetMonth : date.day;

    return DateTime(newYear, newMonth, newDay);
  }

  void _generateDates() {
    _dates = [];
    final committeeStartDate = widget.committee.startDate;
    final payoutIntervalDays = widget.committee.paymentIntervalDays;

    // Use collection frequency to determine interval between collection dates
    int collectionInterval = 30;
    if (widget.committee.frequency == 'daily') collectionInterval = 1;
    if (widget.committee.frequency == 'weekly') collectionInterval = 7;
    if (widget.committee.frequency == 'monthly') collectionInterval = 30;

    // Calculate how many collection periods fit in one payout cycle
    // e.g., payoutIntervalDays=30 with weekly collection (7) = ~4 columns per payout
    // e.g., payoutIntervalDays=30 with monthly collection (30) = 1 column per payout
    // e.g., payoutIntervalDays=30 with daily collection (1) = 30 columns per payout
    int periodsPerPayout;
    if (widget.committee.frequency == 'monthly') {
      // For monthly collection, calculate roughly how many months per payout
      periodsPerPayout = (payoutIntervalDays / 30).ceil();
      if (periodsPerPayout < 1) periodsPerPayout = 1;
    } else {
      periodsPerPayout = (payoutIntervalDays / collectionInterval).ceil();
      if (periodsPerPayout < 1) periodsPerPayout = 1;
    }

    // If committee has members, generate dates for the SELECTED cycle only
    final numMembers =
        _members.isNotEmpty
            ? _members.length
            : (widget.committee.totalMembers > 0
                ? widget.committee.totalMembers
                : 0);

    if (numMembers > 0) {
      // Generate dates for the SELECTED payout cycle only
      final cycleIndex = _selectedCycle - 1; // _selectedCycle is 1-based
      
      DateTime cycleStartDate;
      if (widget.committee.frequency == 'monthly') {
        cycleStartDate = _addMonths(committeeStartDate, cycleIndex * periodsPerPayout);
      } else {
        final daysOffset = cycleIndex * payoutIntervalDays;
        cycleStartDate = committeeStartDate.add(Duration(days: daysOffset));
      }

      // Generate exactly periodsPerPayout dates for this payout cycle
      DateTime current = cycleStartDate;
      for (int i = 0; i < periodsPerPayout; i++) {
        _dates.add(current);
        if (widget.committee.frequency == 'monthly') {
          current = _addMonths(current, 1);
        } else {
          current = current.add(Duration(days: collectionInterval));
        }
      }
    } else {
      // Fallback: no members, use extraPeriods logic
      final startDate = _filterStartDate ?? committeeStartDate;
      DateTime baseEndDate = _filterEndDate ?? DateTime.now();

      DateTime endDate;
      if (widget.committee.frequency == 'monthly') {
        endDate = _addMonths(baseEndDate, _extraPeriods);
      } else {
        endDate = baseEndDate.add(Duration(days: collectionInterval * _extraPeriods));
      }

      DateTime current = DateTime(
        startDate.year,
        startDate.month,
        startDate.day,
      );

      // Safety break to prevent infinite loops if dates are messed up
      int safetyCounter = 0;

      while (!current.isAfter(endDate) && safetyCounter < 500) {
        _dates.add(current);
        if (widget.committee.frequency == 'monthly') {
          current = _addMonths(current, 1);
        } else {
          current = current.add(Duration(days: collectionInterval));
        }
        safetyCounter++;
      }

      if (_dates.isEmpty) {
        _dates.add(current);
      }
    }
  }

  void _loadPaymentsFromCloudData() {
    _paymentGrid = {};
    for (final payment in _cloudPayments) {
      final dateKey = _getDateKey(payment.date);
      _paymentGrid[payment.memberId] ??= {};
      _paymentGrid[payment.memberId]![dateKey] = payment.isPaid;
    }
  }

  /// Load payments from local Hive database
  void _loadPaymentsFromLocal() {
    _paymentGrid = {};
    final payments = _dbService.getPaymentsByCommittee(widget.committee.id);
    for (final payment in payments) {
      final dateKey = _getDateKey(payment.date);
      _paymentGrid[payment.memberId] ??= {};
      _paymentGrid[payment.memberId]![dateKey] = payment.isPaid;
    }
  }

  void _loadPayments() {
    _loadPaymentsFromLocal();
  }

  String _getDateKey(DateTime date) {
    return '${date.year}-${date.month}-${date.day}';
  }

  bool _isPaymentMarked(String memberId, DateTime date) {
    final dateKey = _getDateKey(date);
    return _paymentGrid[memberId]?[dateKey] ?? false;
  }

  // _togglePayment is defined later with host checks and optimistic update.

  int _periodIndexForDate(DateTime date) {
    final start = widget.committee.startDate;
    if (widget.committee.frequency == 'monthly') {
      return (date.year - start.year) * 12 + (date.month - start.month) + 1;
    } else {
      int interval = 30;
      if (widget.committee.frequency == 'daily') interval = 1;
      if (widget.committee.frequency == 'weekly') interval = 7;
      final daysDiff = date.difference(start).inDays;
      return (daysDiff >= 0) ? (daysDiff ~/ interval) + 1 : 1;
    }
  }

  int _computeMaxCycles(List payments) {
    // If we have members, the number of cycles is equal to the number of members
    // (each member receives the payout once per full rotation).
    if (_members.isNotEmpty) {
      return _members.length;
    }

    // Otherwise estimate from existing payments/dates (fallback)
    DateTime farDate =
        _dates.isNotEmpty ? _dates.last : widget.committee.startDate;
    for (final p in payments) {
      if (p.date.isAfter(farDate)) farDate = p.date;
    }

    final periodIndex = _periodIndexForDate(farDate);
    final numMembers =
        widget.committee.totalMembers > 0 ? widget.committee.totalMembers : 1;
    final cycle = ((periodIndex - 1) ~/ numMembers) + 1;

    // Allow a small buffer
    return (cycle + 2) < 1 ? 1 : (cycle + 2);
  }

  // _loadPayments is defined earlier; avoid duplicate definition and restore
  // proper member debt calculator here.

  Map<String, dynamic> _calculateMemberDebt(String memberId) {
    final now = DateTime.now();
    int paidCount = 0;
    int duePeriods = 0;

    for (var date in _dates) {
      if (!date.isAfter(now)) {
        duePeriods++;
        if (_isPaymentMarked(memberId, date)) paidCount++;
      }
    }

    final unpaidCount = duePeriods - paidCount;
    final debtAmount = unpaidCount * widget.committee.contributionAmount;

    return {
      'paidCount': paidCount,
      'duePeriods': duePeriods,
      'unpaidCount': unpaidCount,
      'debtAmount': debtAmount,
      'isDefaulter': unpaidCount > 0,
      'severity':
          unpaidCount >= 3 ? 'high' : (unpaidCount >= 1 ? 'medium' : 'none'),
    };
  }

  double _calculateTotalDebt() {
    double total = 0;
    for (var member in _members) {
      final debt = _calculateMemberDebt(member.id);
      total += debt['debtAmount'] as double;
    }
    return total;
  }

  Map<String, dynamic> _calculateCurrentStats() {
    final now = DateTime.now();
    final amountPerCell = widget.committee.contributionAmount;
    final payoutInterval = widget.committee.paymentIntervalDays;
    final startDate = widget.committee.startDate;

    final daysElapsed = now.difference(startDate).inDays;
    final currentPayoutCycle =
        payoutInterval > 0 ? (daysElapsed ~/ payoutInterval) : 0;

    int currentCyclePaid = 0;
    int currentCycleDue = 0;
    int totalPaid = 0;
    int totalDue = 0;

    for (var member in _members) {
      for (var date in _dates) {
        if (!date.isAfter(now)) {
          totalDue++;
          if (_isPaymentMarked(member.id, date)) {
            totalPaid++;
          }

          final dateDaysElapsed = date.difference(startDate).inDays;
          final datePayoutCycle =
              payoutInterval > 0 ? (dateDaysElapsed ~/ payoutInterval) : 0;

          if (datePayoutCycle == currentPayoutCycle) {
            currentCycleDue++;
            if (_isPaymentMarked(member.id, date)) {
              currentCyclePaid++;
            }
          }
        }
      }
    }

    // Calculate total payout amount (members × contribution × collections per payout)
    final collectionInterval = widget.committee.frequency == 'daily'
        ? 1
        : widget.committee.frequency == 'weekly'
            ? 7
            : 30;
    final collectionsPerPayout = payoutInterval > 0
        ? payoutInterval ~/ collectionInterval
        : 1;
    final totalPayoutAmount = _members.length * amountPerCell * collectionsPerPayout;

    return {
      'totalPaid': totalPaid,
      'totalDue': totalDue,
      'totalUnpaid': totalDue - totalPaid,
      'totalCollected': totalPaid * amountPerCell,
      'totalPending': (totalDue - totalPaid) * amountPerCell,
      'currentCyclePaid': currentCyclePaid,
      'currentCycleDue': currentCycleDue,
      'currentCycleCollected': currentCyclePaid * amountPerCell,
      'currentPayoutCycle': currentPayoutCycle + 1,
      'totalPayoutAmount': totalPayoutAmount,
      'collectionsPerPayout': collectionsPerPayout,
      'daysElapsed': daysElapsed,
    };
  }

  int _getMinimumPeriods() {
    final now = DateTime.now();
    int count = 0;
    for (var date in _dates) {
      if (!date.isAfter(now)) {
        count++;
      }
    }
    return count > 0 ? count : 1;
  }

  Map<String, dynamic> _calculateMemberAdvance(String memberId) {
    final now = DateTime.now();
    int advancePaymentCount = 0;
    for (var date in _dates) {
      if (date.isAfter(now) && _isPaymentMarked(memberId, date)) {
        advancePaymentCount++;
      }
    }
    final advanceAmount =
        advancePaymentCount * widget.committee.contributionAmount;
    return {
      'advanceCount': advancePaymentCount,
      'advanceAmount': advanceAmount,
      'hasAdvance': advancePaymentCount > 0,
    };
  }

  Future<void> _togglePayment(String memberId, DateTime date) async {
    final currentUser = _authService.currentUser;
    if (currentUser?.id != widget.committee.hostId) {
      if (!mounted) return;
      ToastService.warning(context, 'Only the host can mark payments');
      return;
    }

    // Optimistic Update: Toggle immediately in UI
    final dateKey = _getDateKey(date);
    final currentStatus = _paymentGrid[memberId]?[dateKey] ?? false;
    setState(() {
      _paymentGrid[memberId] ??= {};
      _paymentGrid[memberId]![dateKey] = !currentStatus;
    });

    try {
      final hostId = currentUser?.id ?? '';
      
      // Use local-first toggle (saves locally, syncs in background)
      await _autoSyncService.togglePayment(
        memberId,
        widget.committee.id,
        date,
        hostId,
      );
      
      // Log analytics event
      final newStatus = !currentStatus;
      AnalyticsService.logPaymentMarked(
        amount: widget.committee.contributionAmount,
        isPaid: newStatus,
      );

      // Reload from local to ensure consistency
      if (mounted) {
        _loadPaymentsFromLocal();
        setState(() {});
      }
    } catch (e) {
      // Revert on error
      if (mounted) {
        _loadPaymentsFromLocal();
        setState(() {});
        ToastService.error(context, 'Update failed: $e');
      }
    }
  }

  void _showDateFilterDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: AppTheme.darkCard,
            title: const Text('Filter by Date Range'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(
                    'Start Date',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                  subtitle: Text(
                    _filterStartDate != null
                        ? DateFormat('dd/MM/yyyy').format(_filterStartDate!)
                        : 'Kameti Start',
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate:
                          _filterStartDate ?? widget.committee.startDate,
                      firstDate: widget.committee.startDate,
                      lastDate: DateTime.now(),
                    );
                    if (date != null && mounted) {
                      setState(() => _filterStartDate = date);
                      _generateDates();
                      _loadPayments();
                      Navigator.pop(context);
                      _showDateFilterDialog();
                    }
                  },
                ),
                ListTile(
                  title: Text(
                    'End Date',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                  subtitle: Text(
                    _filterEndDate != null
                        ? DateFormat('dd/MM/yyyy').format(_filterEndDate!)
                        : 'Today',
                    style: const TextStyle(color: Colors.white),
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _filterEndDate ?? DateTime.now(),
                      firstDate: widget.committee.startDate,
                      lastDate: DateTime.now(),
                    );
                    if (date != null && mounted) {
                      setState(() => _filterEndDate = date);
                      _generateDates();
                      _loadPayments();
                      Navigator.pop(context);
                      _showDateFilterDialog();
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _filterStartDate = null;
                    _filterEndDate = null;
                  });
                  _generateDates();
                  _loadPayments();
                  Navigator.pop(context);
                },
                child: const Text('Clear Filter'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Done'),
              ),
            ],
          ),
    );
  }

  void _showExportOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Export Payment Sheet',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Select a cycle to export',
                  style: TextStyle(color: Colors.grey[400], fontSize: 12),
                ),
                const SizedBox(height: 16),
                // Cycle selection chips
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _maxCycles + 1, // +1 for "All Cycles" option
                    itemBuilder: (context, index) {
                      final isAllCycles = index == 0;
                      final cycleNum = index;
                      final isOngoing = !isAllCycles && _exportService.isCycleOngoing(widget.committee, cycleNum);
                      final isCompleted = !isAllCycles && _exportService.isCycleCompleted(widget.committee, cycleNum);
                      
                      String label;
                      Color bgColor;
                      if (isAllCycles) {
                        label = 'All Cycles';
                        bgColor = AppTheme.primaryColor.withOpacity(0.2);
                      } else if (isOngoing) {
                        label = 'Cycle $cycleNum (Ongoing)';
                        bgColor = Colors.orange.withOpacity(0.2);
                      } else if (isCompleted) {
                        label = 'Cycle $cycleNum';
                        bgColor = Colors.green.withOpacity(0.2);
                      } else {
                        label = 'Cycle $cycleNum (Upcoming)';
                        bgColor = Colors.grey.withOpacity(0.2);
                      }
                      
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          label: Text(label, style: const TextStyle(fontSize: 12)),
                          backgroundColor: bgColor,
                          onPressed: () {
                            Navigator.pop(context);
                            _showExportFormatDialog(isAllCycles ? null : cycleNum);
                          },
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Tap a cycle above to export, or scroll for more cycles',
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
              ],
            ),
          ),
    );
  }

  void _showExportFormatDialog(int? cycle) {
    final cycleLabel = cycle != null ? 'Cycle $cycle' : 'All Cycles';
    String? dateRange;
    if (cycle != null) {
      final range = _exportService.getCycleDateRange(widget.committee, cycle);
      final start = range['start']!;
      final end = range['end']!;
      dateRange = '${_formatDate(start)} - ${_formatDate(end)}';
    }
    
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.darkCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Export $cycleLabel',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            if (dateRange != null) ...[
              const SizedBox(height: 4),
              Text(
                dateRange,
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
            ],
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.picture_as_pdf, color: Colors.red),
              ),
              title: const Text(
                'Export as PDF',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                'Print or share as document',
                style: TextStyle(color: Colors.grey[500]),
              ),
              onTap: () async {
                Navigator.pop(context);
                ToastService.info(context, 'Generating PDF...');
                await _exportService.exportToPdf(
                  widget.committee,
                  cycle: cycle,
                );
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.table_chart, color: Colors.green),
              ),
              title: const Text(
                'Export as CSV (Excel)',
                style: TextStyle(color: Colors.white),
              ),
              subtitle: Text(
                'Open in Excel or Google Sheets',
                style: TextStyle(color: Colors.grey[500]),
              ),
              onTap: () async {
                Navigator.pop(context);
                ToastService.info(context, 'Generating CSV...');
                await _exportService.exportToCsv(
                  widget.committee,
                  cycle: cycle,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.viewAsMember != null) {
      return _buildMemberPersonalView();
    }

    final amountPerCell = widget.committee.contributionAmount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Sheet'),
        actions: [
          IconButton(
            icon: Icon(
              Icons.date_range,
              color:
                  (_filterStartDate != null || _filterEndDate != null)
                      ? AppTheme.primaryColor
                      : null,
            ),
            tooltip: 'Filter by Date',
            onPressed: _showDateFilterDialog,
          ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export',
            onPressed: _showExportOptions,
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _members.isEmpty
              ? _buildEmptyState()
              : Column(
                children: [
                  // Stats Card
                  Builder(
                    builder: (context) {
                      final stats = _calculateCurrentStats();
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.primaryColor.withAlpha(40),
                              AppTheme.secondaryColor.withAlpha(20),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppTheme.primaryColor.withAlpha(50),
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStatItem(
                                    icon: Icons.check_circle,
                                    color: AppTheme.secondaryColor,
                                    value: '${stats['totalPaid']}',
                                    label: 'Paid',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildStatItem(
                                    icon: Icons.cancel,
                                    color: Colors.grey[500]!,
                                    value: '${stats['totalUnpaid']}',
                                    label: 'Unpaid',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildStatItem(
                                    icon: Icons.today,
                                    color: Colors.blue[400]!,
                                    value:
                                        'PKR ${(stats['currentCycleCollected'] as double).toInt()}',
                                    label: 'Amount of\n(${stats['daysElapsed']} days)',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    (stats['totalPending'] as double) == 0
                                        ? Colors.green.withOpacity(0.1)
                                        : Colors.red.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    (stats['totalPending'] as double) == 0
                                        ? 'All Paid:'
                                        : 'Pending Dues:',
                                    style: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 12,
                                    ),
                                  ),
                                  Text(
                                    (stats['totalPending'] as double) == 0
                                        ? 'No Pending ✓'
                                        : 'PKR ${(stats['totalPending'] as double).toInt()}',
                                    style: TextStyle(
                                      color:
                                          (stats['totalPending'] as double) == 0
                                              ? Colors.green[300]
                                              : Colors.red[300],
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Collection: ${widget.committee.frequency.toUpperCase()} • Payout: Every ${widget.committee.paymentIntervalDays} Days',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),


                  // Payout Selector - styled with radius
                  if (_members.isNotEmpty)
                    Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.primaryColor.withAlpha(30),
                              AppTheme.secondaryColor.withAlpha(20),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppTheme.primaryColor.withAlpha(60),
                            width: 1,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _selectedCycle,
                            isDense: true,
                            icon: Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: AppTheme.primaryColor,
                              size: 20,
                            ),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            dropdownColor: AppTheme.darkCard,
                            borderRadius: BorderRadius.circular(16),
                            elevation: 8,
                            menuMaxHeight: 300,
                            items: List.generate(
                              _maxCycles,
                              (i) => DropdownMenuItem<int>(
                                value: i + 1,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  child: Text(
                                    'Cycle ${i + 1}',
                                    style: TextStyle(
                                      color: (i + 1) == _selectedCycle
                                          ? AppTheme.primaryColor
                                          : Colors.white,
                                      fontWeight: (i + 1) == _selectedCycle
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            onChanged: (val) {
                              if (val == null) return;
                              setState(() {
                                _selectedCycle = val;
                                _dbService.setSelectedCycle(
                                  widget.committee.id,
                                  val,
                                );
                                _generateDates();
                                _loadPayments();
                              });
                            },
                          ),
                        ),
                      ),
                    ),






                  // Grid with Proper Scrolling
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: _buildGrid(amountPerCell),
                      ),
                    ),
                  ),
                ],
              ),
    );
  }

  Widget _buildGrid(double amountPerCell) {
    final totals = List<double>.generate(_dates.length, (index) {
      double total = 0;
      final date = _dates[index];
      for (var member in _members) {
        if (_isPaymentMarked(member.id, date)) {
          total += amountPerCell;
        }
      }
      return total;
    });

    final targetAmount = amountPerCell * _members.length;
    final payoutInterval = widget.committee.paymentIntervalDays;
    final startDate = widget.committee.startDate;

    return DataTable(
      columnSpacing: 8,
      horizontalMargin: 16,
      headingRowColor: WidgetStateProperty.all(AppTheme.darkCard),
      columns: [
        const DataColumn(
          label: Text('Member', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        ..._dates.asMap().entries.map((entry) {
          final index = entry.key;
          final date = entry.value;
          final now = DateTime.now();
          final isFutureDate = date.isAfter(now);
          final format =
              widget.committee.frequency == 'monthly'
                  ? DateFormat('MMM')
                  : DateFormat('dd/MM');
          final isTargetMet = totals[index] >= targetAmount;

          final daysElapsed = date.difference(startDate).inDays + 1;
          final isPayoutDay =
              payoutInterval > 0 &&
              daysElapsed > 0 &&
              (daysElapsed % payoutInterval == 0);

          return DataColumn(
            label: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                RotatedBox(
                  quarterTurns: -1,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isFutureDate)
                        Icon(Icons.schedule, size: 10, color: Colors.blue[300]),
                      if (isFutureDate) const SizedBox(width: 2),
                      Text(
                        format.format(date),
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color:
                              isFutureDate
                                  ? Colors.blue[300]
                                  : isPayoutDay
                                  ? Colors.amber
                                  : null,
                        ),
                      ),
                    ],
                  ),
                ),
                if (totals[index] > 0) ...[
                  const SizedBox(height: 4),
                  Container(
                    width: 4,
                    height: 4,
                    decoration: BoxDecoration(
                      color:
                          isTargetMet ? AppTheme.secondaryColor : Colors.orange,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
        const DataColumn(
          label: Text(
            'Dues',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
          ),
        ),
      ],
      rows: [
        ..._members.asMap().entries.map((entry) {
          final memberIndex = entry.key;
          final member = entry.value;
          final memberDebt = _calculateMemberDebt(member.id);
          final isDefaulter = memberDebt['isDefaulter'] as bool;
          final unpaidCount = memberDebt['unpaidCount'] as int;
          final memberAdvance = _calculateMemberAdvance(member.id);
          final hasAdvance = memberAdvance['hasAdvance'] as bool;
          final advanceCount = memberAdvance['advanceCount'] as int;

          return DataRow(
            cells: [
              DataCell(
                Row(
                  children: [
                    // Payout order number on LEFT
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[800],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '#${member.payoutOrder}',
                        style: TextStyle(fontSize: 9, color: Colors.grey[400]),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Warning icon if defaulter
                    if (isDefaulter) ...[
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: Colors.amber,
                      ),
                      const SizedBox(width: 4),
                    ],
                    // Member name in MIDDLE
                    SizedBox(
                      width: (isDefaulter || hasAdvance) ? 60 : 70,
                      child: Text(
                        member.name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          color:
                              isDefaulter
                                  ? Colors.amber[300]
                                  : hasAdvance
                                  ? Colors.blue[300]
                                  : null,
                        ),
                      ),
                    ),
                    // Advance count on RIGHT
                    if (hasAdvance) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '+$advanceCount',
                          style: TextStyle(
                            fontSize: 8,
                            color: Colors.blue[300],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              ..._dates.asMap().entries.map((dateEntry) {
                final date = dateEntry.value;
                final isPaid = _isPaymentMarked(member.id, date);

                final daysElapsed = date.difference(startDate).inDays;
                final currentRound =
                    payoutInterval > 0 ? (daysElapsed ~/ payoutInterval) : 0;
                final receiverIndex = currentRound % _members.length;
                final isPayoutReceiver = (receiverIndex == memberIndex);

                // Highlight Payout Day
                final isPayoutDay =
                    payoutInterval > 0 &&
                    ((daysElapsed + 1) % payoutInterval == 0);
                final isPayoutCell = isPayoutReceiver && isPayoutDay;

                return DataCell(
                  GestureDetector(
                    onTap: () => _togglePayment(member.id, date),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color:
                            isPaid ? AppTheme.secondaryColor : Colors.grey[800],
                        borderRadius: BorderRadius.circular(6),
                        border:
                            isPayoutCell
                                ? Border.all(color: Colors.amber, width: 2)
                                : Border.all(
                                  color:
                                      isPaid
                                          ? AppTheme.secondaryColor
                                          : Colors.grey[700]!,
                                  width: 1,
                                ),
                        boxShadow:
                            isPayoutCell
                                ? [
                                  BoxShadow(
                                    color: Colors.amber.withOpacity(0.3),
                                    blurRadius: 4,
                                  ),
                                ]
                                : null,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (isPaid)
                            const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 18,
                            ),
                          if (isPayoutCell && !isPaid)
                            const Icon(
                              Icons.star_outline,
                              color: Colors.amber,
                              size: 18,
                            ),
                          if (isPayoutCell && isPaid)
                            const Positioned(
                              right: 0,
                              top: 0,
                              child: Icon(
                                Icons.star,
                                color: Colors.amber,
                                size: 8,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isDefaulter
                            ? Colors.amber.withOpacity(0.2)
                            : hasAdvance
                            ? Colors.blue.withOpacity(0.2)
                            : Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (isDefaulter) ...[
                        Text(
                          'PKR ${(unpaidCount * widget.committee.contributionAmount).toInt()}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber[300],
                          ),
                        ),
                        Text(
                          '$unpaidCount unpaid',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[400],
                          ),
                        ),
                      ] else if (hasAdvance) ...[
                        Text(
                          '+$advanceCount',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[300],
                          ),
                        ),
                      ] else ...[
                        Text(
                          '✓',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.secondaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        }),
        DataRow(
          cells: [
            const DataCell(
              Text(
                'Collected',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ),
            ..._dates.asMap().entries.map((entry) {
              final index = entry.key;
              final total = totals[index];
              final isMet = total >= targetAmount;
              return DataCell(
                Text(
                  '${(total).toInt()}/${(targetAmount).toInt()}',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: isMet ? AppTheme.secondaryColor : Colors.grey[400],
                  ),
                ),
              );
            }),
            DataCell(
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      _calculateTotalDebt() > 0
                          ? Colors.red.withOpacity(0.2)
                          : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _calculateTotalDebt() > 0
                      ? 'PKR ${_calculateTotalDebt().toInt()}'
                      : 'All Paid ✓',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color:
                        _calculateTotalDebt() > 0
                            ? Colors.red[300]
                            : AppTheme.secondaryColor,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required Color color,
    required String value,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[400]),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.grid_off_rounded, size: 80, color: Colors.grey[700]),
          const SizedBox(height: 16),
          Text(
            'No Members Yet',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Add members to start collecting payments. The Period and Cycle options will appear once members are added.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500]),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () async {
              // Navigate to member management to add members
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (_) =>
                          MemberManagementScreen(committee: widget.committee),
                ),
              );
              _loadData();
            },
            icon: const Icon(Icons.person_add_alt_1),
            label: const Text('Add Members'),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem({required Color color, required String label}) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: Colors.grey[400])),
      ],
    );
  }

  Widget _buildMemberPersonalView() {
    final member = widget.viewAsMember!;

    int paidCount = 0;
    int advanceCount = 0;
    final now = DateTime.now();

    for (var date in _dates) {
      if (_isPaymentMarked(member.id, date)) {
        paidCount++;
        if (date.isAfter(now)) advanceCount++;
      }
    }

    final totalDue = _dates.length;
    final totalContribution = paidCount * widget.committee.contributionAmount;
    final advanceAmount = advanceCount * widget.committee.contributionAmount;

    return MemberCalendarView(
      member: member,
      committee: widget.committee,
      members: _members,
      dates: _dates,
      paidCount: paidCount,
      totalDue: totalDue,
      totalContribution: totalContribution,
      advanceCount: advanceCount,
      advanceAmount: advanceAmount,
      isPaymentMarked: _isPaymentMarked,
      onRefresh: _loadData,
    );
  }
}
