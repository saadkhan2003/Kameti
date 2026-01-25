import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../../services/auto_sync_service.dart';
import '../../services/sync_service.dart';
import '../../models/committee.dart';
import '../../models/member.dart';
import '../../models/payment.dart';

/// Controller for payment sheet business logic
/// 
/// Separates payment calculations, date generation, and grid management from UI.
class PaymentController extends ChangeNotifier {
  final Committee committee;
  final Member? viewAsMember;

  final _dbService = DatabaseService();
  final _authService = AuthService();
  final _autoSyncService = AutoSyncService();
  final _syncService = SyncService();

  List<Member> _members = [];
  List<DateTime> _dates = [];
  Map<String, Map<String, bool>> _paymentGrid = {};
  bool _isLoading = true;
  int _selectedCycle = 1;
  int _maxCycles = 1;
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  int _extraPeriods = 1;

  // Getters
  List<Member> get members => _members;
  List<DateTime> get dates => _dates;
  bool get isLoading => _isLoading;
  int get selectedCycle => _selectedCycle;
  int get maxCycles => _maxCycles;
  DateTime? get filterStartDate => _filterStartDate;
  DateTime? get filterEndDate => _filterEndDate;
  bool get isHost => _authService.currentUser?.uid == committee.hostId;

  PaymentController({required this.committee, this.viewAsMember});

  /// Initialize - call in initState
  Future<void> initialize() async {
    await syncAndLoad();
  }

  Future<void> syncAndLoad() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      await _syncService.syncMembers(committee.id);
      await _syncService.syncPayments(committee.id);
    } catch (e) {
      debugPrint('Sync error: $e');
    }
    
    await loadData();
  }

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();

    _members = _dbService.getMembersByCommittee(committee.id);
    _members.sort((a, b) => a.payoutOrder.compareTo(b.payoutOrder));

    final allPayments = _dbService.getPaymentsByCommittee(committee.id);
    _maxCycles = _computeMaxCycles(allPayments);

    _selectedCycle = _dbService.getSelectedCycle(committee.id);
    if (_selectedCycle < 1) _selectedCycle = 1;
    if (_selectedCycle > _maxCycles) {
      _selectedCycle = _maxCycles;
      _dbService.setSelectedCycle(committee.id, _selectedCycle);
    }

    _generateDates();
    _loadPayments();

    _isLoading = false;
    notifyListeners();
  }

  void setSelectedCycle(int cycle) {
    _selectedCycle = cycle;
    _dbService.setSelectedCycle(committee.id, cycle);
    _generateDates();
    _loadPayments();
    notifyListeners();
  }

  void setDateFilter({DateTime? start, DateTime? end}) {
    _filterStartDate = start;
    _filterEndDate = end;
    _generateDates();
    _loadPayments();
    notifyListeners();
  }

  void clearDateFilter() {
    _filterStartDate = null;
    _filterEndDate = null;
    _generateDates();
    _loadPayments();
    notifyListeners();
  }

  /// Toggle payment status
  Future<bool> togglePayment(String memberId, DateTime date) async {
    if (!isHost) return false;

    // Optimistic update
    final dateKey = _getDateKey(date);
    _paymentGrid[memberId] ??= {};
    final currentStatus = _paymentGrid[memberId]![dateKey] ?? false;
    _paymentGrid[memberId]![dateKey] = !currentStatus;
    notifyListeners();

    try {
      final hostId = _authService.currentUser?.uid ?? '';
      await _autoSyncService.togglePayment(memberId, committee.id, date, hostId);
      _loadPayments();
      notifyListeners();
      return true;
    } catch (e) {
      // Revert on error
      _loadPayments();
      notifyListeners();
      return false;
    }
  }

  bool isPaymentMarked(String memberId, DateTime date) {
    final dateKey = _getDateKey(date);
    return _paymentGrid[memberId]?[dateKey] ?? false;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CALCULATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  Map<String, dynamic> calculateMemberDebt(String memberId) {
    final now = DateTime.now();
    int paidCount = 0;
    int duePeriods = 0;

    for (var date in _dates) {
      if (!date.isAfter(now)) {
        duePeriods++;
        if (isPaymentMarked(memberId, date)) paidCount++;
      }
    }

    final unpaidCount = duePeriods - paidCount;
    final debtAmount = unpaidCount * committee.contributionAmount;

    return {
      'paidCount': paidCount,
      'duePeriods': duePeriods,
      'unpaidCount': unpaidCount,
      'debtAmount': debtAmount,
      'isDefaulter': unpaidCount > 0,
      'severity': unpaidCount >= 3 ? 'high' : (unpaidCount >= 1 ? 'medium' : 'none'),
    };
  }

  double calculateTotalDebt() {
    double total = 0;
    for (var member in _members) {
      final debt = calculateMemberDebt(member.id);
      total += debt['debtAmount'] as double;
    }
    return total;
  }

  Map<String, dynamic> calculateCurrentStats() {
    final now = DateTime.now();
    final amountPerCell = committee.contributionAmount;
    final payoutInterval = committee.paymentIntervalDays;
    final startDate = committee.startDate;

    final daysElapsed = now.difference(startDate).inDays;
    final currentPayoutCycle = payoutInterval > 0 ? (daysElapsed ~/ payoutInterval) : 0;

    int currentCyclePaid = 0;
    int currentCycleDue = 0;
    int totalPaid = 0;
    int totalDue = 0;

    for (var member in _members) {
      for (var date in _dates) {
        if (!date.isAfter(now)) {
          totalDue++;
          if (isPaymentMarked(member.id, date)) totalPaid++;

          final dateDaysElapsed = date.difference(startDate).inDays;
          final datePayoutCycle = payoutInterval > 0 ? (dateDaysElapsed ~/ payoutInterval) : 0;

          if (datePayoutCycle == currentPayoutCycle) {
            currentCycleDue++;
            if (isPaymentMarked(member.id, date)) currentCyclePaid++;
          }
        }
      }
    }

    final collectionInterval = committee.frequency == 'daily' ? 1 : committee.frequency == 'weekly' ? 7 : 30;
    final collectionsPerPayout = payoutInterval > 0 ? payoutInterval ~/ collectionInterval : 1;
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

  Map<String, dynamic> calculateMemberAdvance(String memberId) {
    final now = DateTime.now();
    int advancePaymentCount = 0;
    for (var date in _dates) {
      if (date.isAfter(now) && isPaymentMarked(memberId, date)) {
        advancePaymentCount++;
      }
    }
    final advanceAmount = advancePaymentCount * committee.contributionAmount;
    return {
      'advanceCount': advancePaymentCount,
      'advanceAmount': advanceAmount,
      'hasAdvance': advancePaymentCount > 0,
    };
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // PRIVATE METHODS
  // ═══════════════════════════════════════════════════════════════════════════

  void _generateDates() {
    _dates = [];
    final committeeStartDate = committee.startDate;
    final payoutIntervalDays = committee.paymentIntervalDays;

    int collectionInterval = 30;
    if (committee.frequency == 'daily') collectionInterval = 1;
    if (committee.frequency == 'weekly') collectionInterval = 7;
    if (committee.frequency == 'monthly') collectionInterval = 30;

    int periodsPerPayout;
    if (committee.frequency == 'monthly') {
      periodsPerPayout = (payoutIntervalDays / 30).ceil();
      if (periodsPerPayout < 1) periodsPerPayout = 1;
    } else {
      periodsPerPayout = (payoutIntervalDays / collectionInterval).ceil();
      if (periodsPerPayout < 1) periodsPerPayout = 1;
    }

    final numMembers = _members.isNotEmpty ? _members.length : (committee.totalMembers > 0 ? committee.totalMembers : 0);

    if (numMembers > 0) {
      DateTime cycleStartDate;
      if (committee.frequency == 'monthly') {
        cycleStartDate = _addMonths(committeeStartDate, (_selectedCycle - 1) * periodsPerPayout);
      } else {
        final daysOffset = (_selectedCycle - 1) * payoutIntervalDays;
        cycleStartDate = committeeStartDate.add(Duration(days: daysOffset));
      }

      final effectiveStartDate = (_filterStartDate != null && _filterStartDate!.isAfter(cycleStartDate))
          ? _filterStartDate!
          : cycleStartDate;

      DateTime current = effectiveStartDate;
      for (int i = 0; i < periodsPerPayout; i++) {
        _dates.add(current);
        if (committee.frequency == 'monthly') {
          current = _addMonths(current, 1);
        } else {
          current = current.add(Duration(days: collectionInterval));
        }
      }
    }
  }

  void _loadPayments() {
    _paymentGrid = {};
    final payments = _dbService.getPaymentsByCommittee(committee.id);
    for (final payment in payments) {
      final dateKey = _getDateKey(payment.date);
      _paymentGrid[payment.memberId] ??= {};
      _paymentGrid[payment.memberId]![dateKey] = payment.isPaid;
    }
  }

  String _getDateKey(DateTime date) => '${date.year}-${date.month}-${date.day}';

  DateTime _addMonths(DateTime date, int monthsToAdd) {
    var newYear = date.year;
    var newMonth = date.month + monthsToAdd;
    while (newMonth > 12) { newYear++; newMonth -= 12; }
    final firstDayOfNextMonth = DateTime(newYear, newMonth + 1, 1);
    final lastDayOfTargetMonth = firstDayOfNextMonth.subtract(const Duration(days: 1)).day;
    final newDay = (date.day > lastDayOfTargetMonth) ? lastDayOfTargetMonth : date.day;
    return DateTime(newYear, newMonth, newDay);
  }

  int _computeMaxCycles(List payments) {
    if (_members.isNotEmpty) return _members.length;
    return 1;
  }
}
