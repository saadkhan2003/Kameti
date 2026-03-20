import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

// Project imports
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/export_service.dart';
import '../../services/auto_sync_service.dart';
import '../../services/sync_service.dart';
import '../../services/analytics_service.dart';
import '../../services/supabase_service.dart';
import '../../services/toast_service.dart';
import '../../services/currency_service.dart';
import '../../models/committee.dart';
import '../../models/member.dart';
import 'package:committee_app/ui/theme/theme.dart';
import 'member_management_screen.dart';
import 'pending_proofs_screen.dart';
import '../viewer/member_calendar_view.dart';

part 'payment_sheet_export.part.dart';
part 'payment_sheet_reminders.part.dart';
part 'payment_sheet_widgets.part.dart';

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
  static const Color _bg = AppColors.bg;
  static const Color _surface = AppColors.surface;
  static const Color _primary = AppColors.primary;
  static const Color _success = AppColors.success;
  static const Color _warning = AppColors.warning;
  static const Color _textPrimary = AppColors.textPrimary;
  static const Color _textSecondary = AppColors.textSecondary;

  final _dbService = DatabaseService();
  final _authService = AuthService();
  final _supabaseService = SupabaseService();
  final _exportService = ExportService();
  final _autoSyncService = AutoSyncService();
  final SyncService _syncService = SyncService();

  List<Member> _members = [];
  List<DateTime> _dates = [];
  Map<String, Map<String, bool>> _paymentGrid = {};
  bool _isLoading = true;
  bool _isOverviewExpanded = false;
  int _selectedCycle = 1;
  int _maxCycles = 1;
  int _pendingProofRequests = 0;

  // Number of extra future periods to show (for advance payments)
  final int _extraPeriods = 1;

  @override
  void initState() {
    super.initState();
    _syncAndLoad();
  }

  Future<void> _syncAndLoad({bool waitForSync = false}) async {
    // Load from local FIRST (fast, non-blocking)
    await _loadDataFromLocal();
    await _loadPendingProofCount();

    if (waitForSync) {
      await _syncCommitteeData();
      await _loadDataFromLocal();
      await _loadPendingProofCount();
      return;
    }

    // Then sync in background (don't await - may hang on web)
    _syncInBackground();
  }

  Future<void> _loadPendingProofCount() async {
    if (widget.viewAsMember != null) return;

    final hostId = _authService.currentUser?.id ?? '';
    if (hostId.isEmpty) return;

    final count = await _supabaseService.getPendingProofCountForHostCommittee(
      hostId,
      widget.committee.id,
    );

    if (!mounted) return;
    setState(() => _pendingProofRequests = count);
  }

  Future<void> _syncCommitteeData() async {
    // If viewing as member (viewer mode), use read-only sync
    if (widget.viewAsMember != null) {
      await _syncService.refreshViewerData(
        widget.committee.id,
        memberId: widget.viewAsMember!.id,
      );
      return;
    }

    // Host mode - can write
    await _syncService.syncMembers(widget.committee.id);
    await _syncService.syncPayments(widget.committee.id);
  }

  void _syncInBackground() {
    // Fire and forget - don't block UI
    Future(() async {
      try {
        await _syncCommitteeData();
        // Reload after sync completes
        if (mounted) {
          await _loadDataFromLocal();
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

  /// Generate ALL collection dates from start up through the END of the current
  /// payout cycle. This ensures the stats card "Unpaid" count matches ALL the
  /// columns visible in the payment matrix (which shows the full current cycle
  /// including future dates), so the user sees consistent numbers.
  List<DateTime> _generateAllDatesUpToEndOfCurrentCycle() {
    final startDate = widget.committee.startDate;
    final payoutInterval = widget.committee.paymentIntervalDays;
    final now = DateTime.now();

    int collectionInterval = 1;
    if (widget.committee.frequency == 'weekly') collectionInterval = 7;
    if (widget.committee.frequency == 'monthly') collectionInterval = 30;

    int periodsPerPayout;
    if (widget.committee.frequency == 'monthly') {
      periodsPerPayout = (payoutInterval / 30).ceil();
    } else {
      periodsPerPayout = (payoutInterval / collectionInterval).ceil();
    }
    if (periodsPerPayout < 1) periodsPerPayout = 1;

    // Find the current cycle index by counting total periods elapsed
    int totalPeriodsElapsed = 0;
    if (widget.committee.frequency == 'monthly') {
      final monthsDiff =
          (now.year - startDate.year) * 12 + (now.month - startDate.month);
      totalPeriodsElapsed =
          (now.day >= startDate.day) ? monthsDiff : monthsDiff - 1;
      if (totalPeriodsElapsed < 0) totalPeriodsElapsed = 0;
    } else {
      final daysElapsed = now.difference(startDate).inDays;
      totalPeriodsElapsed = daysElapsed ~/ collectionInterval;
    }

    final currentCycleIndex = totalPeriodsElapsed ~/ periodsPerPayout;
    final totalDatesNeeded = (currentCycleIndex + 1) * periodsPerPayout;

    final List<DateTime> allDates = [];
    DateTime current = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    );
    for (int i = 0; i < totalDatesNeeded; i++) {
      allDates.add(current);
      if (widget.committee.frequency == 'monthly') {
        current = _addMonths(current, 1);
      } else {
        current = current.add(Duration(days: collectionInterval));
      }
    }
    return allDates;
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
        final totalPeriodsPrior = cycleIndex * periodsPerPayout;
        final daysOffset = totalPeriodsPrior * collectionInterval;
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
      final startDate = committeeStartDate;
      DateTime baseEndDate = DateTime.now();

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
    int paidCount = 0;
    int duePeriods = 0;

    for (var date in _dates) {
      duePeriods++;
      if (_isPaymentMarked(memberId, date)) paidCount++;
    }

    final unpaidCount = duePeriods - paidCount;
    final debtAmount = unpaidCount * widget.committee.contributionAmount;

    return {
      'paidCount': paidCount,
      'duePeriods': duePeriods,
      'unpaidCount': unpaidCount,
      'debtAmount': debtAmount,
      'isDefaulter': unpaidCount > 0, // Mark as defaulter if any unpaid
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

    // Use ALL dates from start through end of CURRENT cycle so the global
    // Paid/Unpaid counters match exactly what's visible in the payment matrix
    // (the matrix already shows the full cycle including future dates).
    final allDates = _generateAllDatesUpToEndOfCurrentCycle();

    for (var member in _members) {
      for (var date in allDates) {
        // All dates returned by _generateAllDatesUpToToday are <= today
        totalDue++;
        if (_isPaymentMarked(member.id, date)) {
          totalPaid++;
        }

        // Current-cycle breakdown (for 'Cycle Amt' stat)
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

  @override
  Widget build(BuildContext context) {
    if (widget.viewAsMember != null) {
      return this._buildMemberPersonalView();
    }

    final amountPerCell = widget.committee.contributionAmount;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(AppIcons.back, color: _textPrimary),
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
            icon: const Icon(AppIcons.reminder, color: _textSecondary),
            tooltip: 'Send Reminders',
            onPressed: () => this._showReminderSheet(),
          ),
          IconButton(
            icon: const Icon(AppIcons.download, color: _textSecondary),
            tooltip: 'Export',
            onPressed: () => this._showExportOptions(),
          ),
          IconButton(
            icon: const Icon(AppIcons.refresh, color: _textSecondary),
            onPressed: () => _syncAndLoad(waitForSync: true),
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _members.isEmpty
              ? this._buildEmptyState()
              : Column(
                children: [
                  // Stats Card
                  Builder(
                    builder: (context) {
                      final stats = _calculateCurrentStats();
                      final totalPending = stats['totalPending'] as double;
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.lightBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Cycle Overview',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: _textPrimary,
                                  ),
                                ),
                                const Spacer(),
                                InkWell(
                                  borderRadius: BorderRadius.circular(999),
                                  onTap: () {
                                    setState(() {
                                      _isOverviewExpanded =
                                          !_isOverviewExpanded;
                                    });
                                  },
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    curve: Curves.easeOut,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          _isOverviewExpanded
                                              ? AppColors.cFFE9EEFC
                                              : AppColors.cFFF8FAFF,
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: AppColors.cFFD0D9EE,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          _isOverviewExpanded
                                              ? 'Hide Details'
                                              : 'Show Details',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: _primary,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        Icon(
                                          _isOverviewExpanded
                                              ? AppIcons
                                                  .keyboard_arrow_up_rounded
                                              : AppIcons
                                                  .keyboard_arrow_down_rounded,
                                          size: 18,
                                          color: _primary,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: this._buildStatItem(
                                    icon: AppIcons.check_circle,
                                    color: _success,
                                    value: '${stats['totalPaid']}',
                                    label: 'Paid',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: this._buildStatItem(
                                    icon: AppIcons.cancel,
                                    color: _warning,
                                    value: '${stats['totalUnpaid']}',
                                    label: 'Unpaid',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: this._buildStatItem(
                                    icon: AppIcons.payout,
                                    color: _primary,
                                    value:
                                        '${widget.committee.currency} ${(stats['currentCycleCollected'] as double).toInt()}',
                                    label: 'Cycle Amt',
                                  ),
                                ),
                              ],
                            ),
                            AnimatedSize(
                              duration: const Duration(milliseconds: 400),
                              curve: Curves.easeInOut,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                switchInCurve: Curves.easeOutCubic,
                                switchOutCurve: Curves.easeInCubic,
                                layoutBuilder:
                                    (currentChild, previousChildren) => Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        ...previousChildren,
                                        if (currentChild != null) currentChild,
                                      ],
                                    ),
                                transitionBuilder: (child, animation) {
                                  return FadeTransition(
                                    opacity: animation,
                                    child: ClipRect(
                                      child: SizeTransition(
                                        sizeFactor: animation,
                                        axis: Axis.vertical,
                                        axisAlignment: -1.0,
                                        child: child,
                                      ),
                                    ),
                                  );
                                },
                                child:
                                    _isOverviewExpanded
                                        ? Column(
                                          key: const ValueKey(
                                            'overview-expanded',
                                          ),
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const SizedBox(height: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color:
                                                    totalPending == 0
                                                        ? _success.withOpacity(
                                                          0.1,
                                                        )
                                                        : _warning.withOpacity(
                                                          0.1,
                                                        ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    totalPending == 0
                                                        ? 'All Paid:'
                                                        : 'Pending Dues:',
                                                    style: GoogleFonts.inter(
                                                      color: _textSecondary,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600,
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
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 13,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            SizedBox(
                                              width: double.infinity,
                                              child: ElevatedButton.icon(
                                                onPressed:
                                                    () =>
                                                        this._showReminderSheet(),
                                                icon: const Icon(
                                                  AppIcons.reminder,
                                                  size: 16,
                                                ),
                                                label: const Text(
                                                  'Send Reminders',
                                                ),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: _primary,
                                                  foregroundColor: Colors.white,
                                                  elevation: 0,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                  ),
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        vertical: 10,
                                                      ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              'Collection: ${widget.committee.frequency.toUpperCase()} • Payout: Every ${widget.committee.paymentIntervalDays} Days',
                                              style: GoogleFonts.inter(
                                                fontSize: 10,
                                                color: _textSecondary,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        )
                                        : const SizedBox.shrink(
                                          key: ValueKey('overview-collapsed'),
                                        ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  // Payout Selector - styled with radius
                  if (_members.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 2,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _surface,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppColors.lightBorder,
                                  width: 1,
                                ),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value: _selectedCycle,
                                  isDense: true,
                                  icon: const Icon(
                                    AppIcons.keyboard_arrow_down_rounded,
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
                          const SizedBox(width: 8),
                          OutlinedButton.icon(
                            onPressed: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => PendingProofsScreen(
                                        committeeId: widget.committee.id,
                                      ),
                                ),
                              );

                              if (!mounted) return;
                              await _syncAndLoad(waitForSync: true);
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _primary,
                              side: BorderSide(color: AppColors.lightBorder),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            icon: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                const Icon(AppIcons.verified_user_rounded),
                                if (_pendingProofRequests > 0)
                                  Positioned(
                                    right: -7,
                                    top: -7,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 1,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.error,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: _surface,
                                          width: 1,
                                        ),
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 16,
                                        minHeight: 16,
                                      ),
                                      child: Text(
                                        _pendingProofRequests > 99
                                            ? '99+'
                                            : '$_pendingProofRequests',
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
                            label: const Text('Proofs'),
                          ),
                        ],
                      ),
                    ),

                  // Custom Payment Matrix
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(16, 2, 16, 12),
                      decoration: BoxDecoration(
                        color: _surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppColors.lightBorder),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.darkBg.withOpacity(0.04),
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
                                this._buildLegendChip(
                                  icon: AppIcons.check_rounded,
                                  label: 'Paid',
                                  color: _success,
                                ),
                                const SizedBox(width: 6),
                                this._buildLegendChip(
                                  icon: AppIcons.star_rounded,
                                  label: 'Payout',
                                  color: _warning,
                                ),
                              ],
                            ),
                          ),
                          const Divider(
                            height: 1,
                            color: AppColors.borderMuted,
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Padding(
                                  padding: const EdgeInsets.all(10),
                                  child: this._buildGrid(amountPerCell),
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
}
