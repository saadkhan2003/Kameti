import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/sync_service.dart';
import '../../services/auto_sync_service.dart';
import '../../services/realtime_sync_service.dart';
import '../../models/committee.dart';

/// Controller for dashboard business logic
/// 
/// Separates sync, load, and committee management logic from UI.
/// 
/// Usage:
/// ```dart
/// final controller = DashboardController();
/// controller.addListener(() => setState(() {}));
/// await controller.initialize();
/// ```
class DashboardController extends ChangeNotifier {
  final _authService = AuthService();
  final _dbService = DatabaseService();
  final _syncService = SyncService();
  final _autoSyncService = AutoSyncService();
  final _realtimeSyncService = RealtimeSyncService();

  List<Committee> _activeCommittees = [];
  List<Committee> _archivedCommittees = [];
  bool _isSyncing = false;
  bool _isEmailVerified = false;
  Timer? _emailVerificationTimer;

  // Getters
  List<Committee> get activeCommittees => _activeCommittees;
  List<Committee> get archivedCommittees => _archivedCommittees;
  bool get isSyncing => _isSyncing;
  bool get isEmailVerified => _isEmailVerified;
  String get userId => _authService.currentUser?.uid ?? '';
  String get displayName => _authService.currentUser?.displayName ?? 
                            _authService.currentUser?.email?.split('@')[0] ?? 'Host';
  String get email => _authService.currentUser?.email ?? 'Anonymous User';
  bool get needsEmailVerification => _authService.currentUser != null && 
                                      !_authService.currentUser!.emailVerified;

  /// Initialize controller - call in initState
  Future<void> initialize() async {
    loadCommittees();
    
    // Start real-time sync listener
    if (userId.isNotEmpty) {
      _realtimeSyncService.onDataChanged = loadCommittees;
      _realtimeSyncService.startListening(userId);
    }
    
    // Trigger silent sync
    await syncDataSilent();
    
    // Start email verification check
    _startEmailVerificationCheck();
  }

  /// Dispose controller - call in dispose
  void disposeController() {
    _emailVerificationTimer?.cancel();
    _realtimeSyncService.stopListening();
  }

  void _startEmailVerificationCheck() {
    if (needsEmailVerification) {
      _emailVerificationTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
        await _authService.reloadUser();
        if (_authService.isEmailVerified) {
          timer.cancel();
          _isEmailVerified = true;
          notifyListeners();
        }
      });
    }
  }

  /// Load committees from local database
  void loadCommittees() {
    final all = _dbService.getHostedCommittees(userId);
    _activeCommittees = all.where((c) => !c.isArchived).toList();
    _archivedCommittees = all.where((c) => c.isArchived).toList();
    notifyListeners();
  }

  /// Silent sync (no UI feedback)
  Future<void> syncDataSilent() async {
    if (_isSyncing) return;

    _isSyncing = true;
    notifyListeners();

    final result = await _syncService.syncAll(userId);

    _isSyncing = false;
    if (result.success) {
      loadCommittees();
    }
    notifyListeners();
  }

  /// Sync with result for UI feedback
  Future<SyncResult> syncData() async {
    if (_isSyncing) return SyncResult(success: false, message: 'Already syncing');

    _isSyncing = true;
    notifyListeners();

    final result = await _syncService.syncAll(userId);

    _isSyncing = false;
    if (result.success) {
      loadCommittees();
    }
    notifyListeners();

    return result;
  }

  /// Archive a committee
  Future<void> archiveCommittee(Committee committee) async {
    await _autoSyncService.archiveCommittee(committee);
    loadCommittees();
  }

  /// Unarchive a committee
  Future<void> unarchiveCommittee(Committee committee) async {
    await _autoSyncService.unarchiveCommittee(committee);
    loadCommittees();
  }

  /// Delete a committee
  Future<void> deleteCommittee(String committeeId) async {
    await _autoSyncService.deleteCommittee(committeeId, userId);
    loadCommittees();
  }

  /// Logout
  Future<void> logout() async {
    await _authService.signOut();
  }

  /// Resend email verification
  Future<void> resendEmailVerification() async {
    await _authService.sendEmailVerification();
  }

  /// Get total members across all active committees
  int getTotalMembers() {
    int total = 0;
    for (var committee in _activeCommittees) {
      total += _dbService.getMembersByCommittee(committee.id).length;
    }
    return total;
  }

  /// Get member names for a specific committee
  List<String> getMemberNames(String committeeId) {
    return _dbService.getMembersByCommittee(committeeId).map((m) => m.name).toList();
  }

  /// Get this month's potential collection
  double getThisMonthCollection() {
    double total = 0;
    for (var committee in _activeCommittees) {
      total += committee.contributionAmount * _dbService.getMembersByCommittee(committee.id).length;
    }
    return total;
  }
}
