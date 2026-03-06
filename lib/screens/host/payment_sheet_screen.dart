import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

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
import '../../utils/app_theme.dart';
import 'member_management_screen.dart';
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
  static const Color _bg = Color(0xFFF7F8FC);
  static const Color _surface = Colors.white;
  static const Color _primary = Color(0xFF3347A8);
  static const Color _success = Color(0xFF059669);
  static const Color _warning = Color(0xFFD97706);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);

  final _dbService = DatabaseService();
  final _authService = AuthService();
  final _exportService = ExportService();
  final _autoSyncService = AutoSyncService();
  final SyncService _syncService = SyncService();

  List<Member> _members = [];
  List<DateTime> _dates = [];
  Map<String, Map<String, bool>> _paymentGrid = {};
  bool _isLoading = true;
  int _selectedCycle = 1;
  int _maxCycles = 1;

  // Date filter
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;

  // Number of extra future periods to show (for advance payments)
  final int _extraPeriods = 1;

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
        cycleStartDate = _addMonths(
          committeeStartDate,
          cycleIndex * periodsPerPayout,
        );
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
        endDate = baseEndDate.add(
          Duration(days: collectionInterval * _extraPeriods),
        );
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
    final collectionInterval =
        widget.committee.frequency == 'daily'
            ? 1
            : widget.committee.frequency == 'weekly'
            ? 7
            : 30;
    final collectionsPerPayout =
        payoutInterval > 0 ? payoutInterval ~/ collectionInterval : 1;
    final totalPayoutAmount =
        _members.length * amountPerCell * collectionsPerPayout;

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
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Export Payment Sheet',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Select a cycle to export',
                  style: GoogleFonts.inter(
                    color: _textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 16),
                // Cycle selection chips
                SizedBox(
                  height: 44,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _maxCycles + 1, // +1 for "All Cycles" option
                    itemBuilder: (context, index) {
                      final isAllCycles = index == 0;
                      final cycleNum = index;
                      final isOngoing =
                          !isAllCycles &&
                          _exportService.isCycleOngoing(
                            widget.committee,
                            cycleNum,
                          );
                      final isCompleted =
                          !isAllCycles &&
                          _exportService.isCycleCompleted(
                            widget.committee,
                            cycleNum,
                          );

                      String label;
                      Color bgColor;
                      Color textColor;
                      Color borderColor;
                      if (isAllCycles) {
                        label = 'All Cycles';
                        bgColor = _primary.withOpacity(0.12);
                        textColor = _primary;
                        borderColor = _primary.withOpacity(0.35);
                      } else if (isOngoing) {
                        label = 'Cycle $cycleNum (Ongoing)';
                        bgColor = _warning.withOpacity(0.14);
                        textColor = _warning;
                        borderColor = _warning.withOpacity(0.35);
                      } else if (isCompleted) {
                        label = 'Cycle $cycleNum';
                        bgColor = _success.withOpacity(0.12);
                        textColor = _success;
                        borderColor = _success.withOpacity(0.35);
                      } else {
                        label = 'Cycle $cycleNum (Upcoming)';
                        bgColor = const Color(0xFFF1F5F9);
                        textColor = _textSecondary;
                        borderColor = const Color(0xFFD7DFEE);
                      }

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              Navigator.pop(context);
                              _showExportFormatDialog(
                                isAllCycles ? null : cycleNum,
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: borderColor),
                              ),
                              child: Text(
                                label,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: textColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Tap a cycle above to export, or scroll for more cycles',
                  style: GoogleFonts.inter(color: _textSecondary, fontSize: 11),
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
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (context) => Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Export $cycleLabel',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _textPrimary,
                  ),
                ),
                if (dateRange != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    dateRange,
                    style: GoogleFonts.inter(
                      color: _textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
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
                  title: Text(
                    'Export as PDF',
                    style: GoogleFonts.inter(
                      color: _textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    'Print or share as document',
                    style: GoogleFonts.inter(
                      color: _textSecondary,
                      fontSize: 12,
                    ),
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
                  title: Text(
                    'Export as CSV (Excel)',
                    style: GoogleFonts.inter(
                      color: _textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    'Open in Excel or Google Sheets',
                    style: GoogleFonts.inter(
                      color: _textSecondary,
                      fontSize: 12,
                    ),
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
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: _textPrimary),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
        ),
        title: Text(
          'Payment Sheet',
          style: GoogleFonts.inter(
            color: _textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.date_range,
              color:
                  (_filterStartDate != null || _filterEndDate != null)
                      ? _primary
                      : _textSecondary,
            ),
            tooltip: 'Filter by Date',
            onPressed: _showDateFilterDialog,
          ),
          IconButton(
            icon: const Icon(
              Icons.file_download_outlined,
              color: _textSecondary,
            ),
            tooltip: 'Export',
            onPressed: _showExportOptions,
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: _textSecondary),
            onPressed: _loadData,
          ),
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
                      final totalPending = stats['totalPending'] as double;
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFDCE4F7)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cycle Overview',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: _textPrimary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStatItem(
                                    icon: Icons.check_circle,
                                    color: _success,
                                    value: '${stats['totalPaid']}',
                                    label: 'Paid',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildStatItem(
                                    icon: Icons.cancel,
                                    color: _warning,
                                    value: '${stats['totalUnpaid']}',
                                    label: 'Unpaid',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: _buildStatItem(
                                    icon: Icons.payments_outlined,
                                    color: _primary,
                                    value:
                                        '${widget.committee.currency} ${(stats['currentCycleCollected'] as double).toInt()}',
                                    label: 'Cycle Amt',
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
                                    totalPending == 0
                                        ? _success.withOpacity(0.1)
                                        : _warning.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    totalPending == 0
                                        ? 'All Paid:'
                                        : 'Pending Dues:',
                                    style: GoogleFonts.inter(
                                      color: _textSecondary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    totalPending == 0
                                        ? 'No Pending ✓'
                                        : '${widget.committee.currency} ${totalPending.toInt()}',
                                    style: GoogleFonts.inter(
                                      color:
                                          totalPending == 0
                                              ? _success
                                              : _warning,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Collection: ${widget.committee.frequency.toUpperCase()} • Payout: Every ${widget.committee.paymentIntervalDays} Days',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: _textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFDCE4F7),
                            width: 1,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            value: _selectedCycle,
                            isDense: true,
                            icon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: _primary,
                              size: 20,
                            ),
                            style: GoogleFonts.inter(
                              color: _textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            dropdownColor: _surface,
                            borderRadius: BorderRadius.circular(16),
                            elevation: 8,
                            menuMaxHeight: 300,
                            items: List.generate(
                              _maxCycles,
                              (i) => DropdownMenuItem<int>(
                                value: i + 1,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  child: Text(
                                    'Cycle ${i + 1}',
                                    style: GoogleFonts.inter(
                                      color:
                                          (i + 1) == _selectedCycle
                                              ? _primary
                                              : _textPrimary,
                                      fontWeight:
                                          (i + 1) == _selectedCycle
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

                  // Custom Payment Matrix
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFDCE4F7)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0F172A).withOpacity(0.04),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                            child: Row(
                              children: [
                                Text(
                                  'Payment Matrix',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: _textPrimary,
                                  ),
                                ),
                                const Spacer(),
                                _buildLegendChip(
                                  icon: Icons.check_rounded,
                                  label: 'Paid',
                                  color: _success,
                                ),
                                const SizedBox(width: 6),
                                _buildLegendChip(
                                  icon: Icons.star_rounded,
                                  label: 'Payout',
                                  color: _warning,
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, color: Color(0xFFE2E8F0)),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: _buildGrid(amountPerCell),
                                ),
                              ),
                            ),
                          ),
                        ],
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
    const double memberColWidth = 190;
    const double dateColWidth = 56;
    const double duesColWidth = 120;

    final now = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFDCE4F7)),
          ),
          child: Row(
            children: [
              _buildMatrixHeaderCell('Member', memberColWidth, isStart: true),
              ..._dates.asMap().entries.map((entry) {
                final index = entry.key;
                final date = entry.value;
                final isFutureDate = date.isAfter(now);
                final format =
                    widget.committee.frequency == 'monthly'
                        ? DateFormat('MMM')
                        : DateFormat('dd/MM');
                final daysElapsed = date.difference(startDate).inDays + 1;
                final isPayoutDay =
                    payoutInterval > 0 &&
                    daysElapsed > 0 &&
                    (daysElapsed % payoutInterval == 0);

                return _buildDateHeaderCell(
                  width: dateColWidth,
                  label: format.format(date),
                  isFutureDate: isFutureDate,
                  isPayoutDay: isPayoutDay,
                  progress: totals[index] / targetAmount,
                );
              }),
              _buildMatrixHeaderCell('Dues', duesColWidth, isEnd: true),
            ],
          ),
        ),
        const SizedBox(height: 10),
        ..._members.asMap().entries.map((entry) {
          final memberIndex = entry.key;
          final member = entry.value;
          final memberDebt = _calculateMemberDebt(member.id);
          final isDefaulter = memberDebt['isDefaulter'] as bool;
          final unpaidCount = memberDebt['unpaidCount'] as int;
          final memberAdvance = _calculateMemberAdvance(member.id);
          final hasAdvance = memberAdvance['hasAdvance'] as bool;
          final advanceCount = memberAdvance['advanceCount'] as int;

          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    isDefaulter
                        ? _warning.withOpacity(0.35)
                        : const Color(0xFFE5ECF9),
              ),
            ),
            child: Row(
              children: [
                _buildMemberInfoCell(
                  member: member,
                  width: memberColWidth,
                  isDefaulter: isDefaulter,
                  hasAdvance: hasAdvance,
                  advanceCount: advanceCount,
                ),
                ..._dates.map((date) {
                  final isPaid = _isPaymentMarked(member.id, date);

                  final daysElapsed = date.difference(startDate).inDays;
                  final currentRound =
                      payoutInterval > 0 ? (daysElapsed ~/ payoutInterval) : 0;
                  final receiverIndex = currentRound % _members.length;
                  final isPayoutReceiver = receiverIndex == memberIndex;

                  final isPayoutDay =
                      payoutInterval > 0 &&
                      ((daysElapsed + 1) % payoutInterval == 0);
                  final isPayoutCell = isPayoutReceiver && isPayoutDay;

                  return _buildPaymentCell(
                    width: dateColWidth,
                    isPaid: isPaid,
                    isPayoutCell: isPayoutCell,
                    onTap: () => _togglePayment(member.id, date),
                  );
                }),
                _buildDuesCell(
                  width: duesColWidth,
                  isDefaulter: isDefaulter,
                  unpaidCount: unpaidCount,
                  hasAdvance: hasAdvance,
                  advanceCount: advanceCount,
                ),
              ],
            ),
          );
        }),
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFF),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFDCE4F7)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: memberColWidth,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'Collected',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: _textSecondary,
                    ),
                  ),
                ),
              ),
              ...totals.map((total) {
                final isMet = total >= targetAmount;
                return SizedBox(
                  width: dateColWidth,
                  child: Text(
                    '${total.toInt()}',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isMet ? _success : _textSecondary,
                    ),
                  ),
                );
              }),
              SizedBox(
                width: duesColWidth,
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color:
                        _calculateTotalDebt() > 0
                            ? _warning.withOpacity(0.14)
                            : _success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _calculateTotalDebt() > 0
                        ? '${widget.committee.currency} ${_calculateTotalDebt().toInt()}'
                        : 'All Paid ✓',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: _calculateTotalDebt() > 0 ? _warning : _success,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatrixHeaderCell(
    String title,
    double width, {
    bool isStart = false,
    bool isEnd = false,
  }) {
    return Container(
      width: width,
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(
            color: const Color(0xFFE5ECF9),
            width: isEnd ? 0 : 1,
          ),
        ),
      ),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: _textPrimary,
        ),
      ),
    );
  }

  Widget _buildDateHeaderCell({
    required double width,
    required String label,
    required bool isFutureDate,
    required bool isPayoutDay,
    required double progress,
  }) {
    return Container(
      width: width,
      height: 56,
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: Color(0xFFE5ECF9), width: 1)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color:
                  isFutureDate
                      ? _primary
                      : (isPayoutDay ? _warning : _textSecondary),
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: 20,
            height: 3,
            decoration: BoxDecoration(
              color: progress >= 1 ? _success : const Color(0xFFD7E0F2),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberInfoCell({
    required Member member,
    required double width,
    required bool isDefaulter,
    required bool hasAdvance,
    required int advanceCount,
  }) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFE8EEFA),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '#${member.payoutOrder}',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: _primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                member.name,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color:
                      isDefaulter
                          ? _warning
                          : hasAdvance
                          ? _primary
                          : _textPrimary,
                ),
              ),
            ),
            if (isDefaulter)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(
                  Icons.warning_amber_rounded,
                  size: 14,
                  color: _warning,
                ),
              ),
            if (hasAdvance)
              Container(
                margin: const EdgeInsets.only(left: 4),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: _primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '+$advanceCount',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    color: _primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentCell({
    required double width,
    required bool isPaid,
    required bool isPayoutCell,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: width,
      child: Center(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isPaid ? _success : const Color(0xFFEEF2FA),
              borderRadius: BorderRadius.circular(8),
              border:
                  isPayoutCell
                      ? Border.all(color: _warning, width: 2)
                      : Border.all(
                        color: isPaid ? _success : const Color(0xFFD3DDEF),
                        width: 1,
                      ),
              boxShadow:
                  isPayoutCell
                      ? [
                        BoxShadow(
                          color: _warning.withOpacity(0.2),
                          blurRadius: 5,
                        ),
                      ]
                      : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (isPaid)
                  const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 17,
                  ),
                if (isPayoutCell && !isPaid)
                  const Icon(
                    Icons.star_outline_rounded,
                    color: _warning,
                    size: 16,
                  ),
                if (isPayoutCell && isPaid)
                  const Positioned(
                    right: 1,
                    top: 1,
                    child: Icon(Icons.star_rounded, color: _warning, size: 8),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDuesCell({
    required double width,
    required bool isDefaulter,
    required int unpaidCount,
    required bool hasAdvance,
    required int advanceCount,
  }) {
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color:
                isDefaulter
                    ? _warning.withOpacity(0.14)
                    : hasAdvance
                    ? _primary.withOpacity(0.12)
                    : _success.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isDefaulter) ...[
                Text(
                  '${widget.committee.currency} ${(unpaidCount * widget.committee.contributionAmount).toInt()}',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _warning,
                  ),
                ),
                Text(
                  '$unpaidCount unpaid',
                  style: GoogleFonts.inter(fontSize: 9, color: _textSecondary),
                ),
              ] else if (hasAdvance) ...[
                Text(
                  '+$advanceCount',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _primary,
                  ),
                ),
                Text(
                  'advance',
                  style: GoogleFonts.inter(fontSize: 9, color: _textSecondary),
                ),
              ] else ...[
                const Icon(Icons.verified_rounded, color: _success, size: 14),
                Text(
                  'clear',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    color: _success,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
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
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: _textSecondary,
              fontWeight: FontWeight.w500,
            ),
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
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              color: const Color(0xFFE9EEFC),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.grid_off_rounded,
              size: 44,
              color: _primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No Members Yet',
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Add members to start collecting payments. The Period and Cycle options will appear once members are added.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: _textSecondary),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
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
