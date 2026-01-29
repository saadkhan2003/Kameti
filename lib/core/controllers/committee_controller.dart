import 'package:flutter/material.dart';
import '../../services/database_service.dart';
import '../../services/auth_service.dart';
import '../../services/auto_sync_service.dart';
import '../../services/sync_service.dart';
import '../../models/committee.dart';
import '../../models/member.dart';

/// Controller for committee detail business logic
/// 
/// Separates member management, committee operations, and stats from UI.
class CommitteeController extends ChangeNotifier {
  final String committeeId;
  
  final _dbService = DatabaseService();
  final _authService = AuthService();
  final _autoSyncService = AutoSyncService();
  final _syncService = SyncService();

  Committee? _committee;
  List<Member> _members = [];
  bool _isLoading = true;
  bool _isSyncing = false;

  // Getters
  Committee? get committee => _committee;
  List<Member> get members => _members;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  bool get isHost => _authService.currentUser?.uid == _committee?.hostId;
  String get hostId => _authService.currentUser?.uid ?? '';

  CommitteeController({required this.committeeId});

  /// Initialize - call in initState
  Future<void> initialize() async {
    await loadData();
  }

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();

    _committee = _dbService.getCommitteeById(committeeId);
    _members = _dbService.getMembersByCommittee(committeeId);
    _members.sort((a, b) => a.payoutOrder.compareTo(b.payoutOrder));

    _isLoading = false;
    notifyListeners();
  }

  Future<void> syncData() async {
    if (_isSyncing) return;
    
    _isSyncing = true;
    notifyListeners();

    try {
      await _syncService.syncMembers(committeeId);
      await _syncService.syncPayments(committeeId);
      await loadData();
    } catch (e) {
      debugPrint('Sync error: $e');
    }

    _isSyncing = false;
    notifyListeners();
  }

  /// Add a new member using saveMember
  Future<bool> addMember(Member member) async {
    if (!isHost) return false;

    try {
      await _autoSyncService.saveMember(member);
      await loadData();
      return true;
    } catch (e) {
      debugPrint('Add member error: $e');
      return false;
    }
  }

  /// Update member details using saveMember
  Future<bool> updateMember(Member member) async {
    if (!isHost) return false;

    try {
      await _autoSyncService.saveMember(member);
      await loadData();
      return true;
    } catch (e) {
      debugPrint('Update member error: $e');
      return false;
    }
  }

  /// Delete a member
  Future<bool> deleteMember(String memberId) async {
    if (!isHost) return false;

    try {
      await _autoSyncService.deleteMember(memberId, committeeId);
      await loadData();
      return true;
    } catch (e) {
      debugPrint('Delete member error: $e');
      return false;
    }
  }

  /// Update member payout order
  Future<bool> updateMemberPayoutOrder(String memberId, int order) async {
    if (!isHost) return false;

    try {
      await _autoSyncService.updateMemberPayoutOrder(memberId, order, committeeId);
      await loadData();
      return true;
    } catch (e) {
      debugPrint('Update order error: $e');
      return false;
    }
  }

  /// Update committee details using saveCommittee
  Future<bool> updateCommittee(Committee updatedCommittee) async {
    if (!isHost) return false;

    try {
      await _autoSyncService.saveCommittee(updatedCommittee);
      await loadData();
      return true;
    } catch (e) {
      debugPrint('Update committee error: $e');
      return false;
    }
  }

  /// Get total collected amount
  double getTotalCollected() {
    final payments = _dbService.getPaymentsByCommittee(committeeId);
    int paidCount = payments.where((p) => p.isPaid).length;
    return paidCount * (_committee?.contributionAmount ?? 0);
  }

  /// Get pending amount
  double getPendingAmount() {
    final payments = _dbService.getPaymentsByCommittee(committeeId);
    int unpaidCount = payments.where((p) => !p.isPaid).length;
    return unpaidCount * (_committee?.contributionAmount ?? 0);
  }

  /// Get next payout member
  Member? getNextPayoutMember() {
    if (_members.isEmpty) return null;
    return _members.first;
  }
}
