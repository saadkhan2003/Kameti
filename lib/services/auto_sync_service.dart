import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'sync_service.dart';
import 'sync_status_service.dart';
import 'supabase_service.dart';
import 'database_service.dart';
import 'realtime_sync_service.dart';
import '../models/committee.dart';
import '../models/member.dart';
import '../models/payment.dart';

/// A wrapper service that automatically syncs data to Firebase
/// whenever changes are made locally.
class AutoSyncService {
  static const Duration _syncDebounce = Duration(milliseconds: 1200);
  static final Map<String, Timer> _syncDebounceTimers = {};
  static final Map<String, Future<void> Function()> _pendingSyncJobs = {};

  final SyncService _syncService = SyncService();
  final DatabaseService _dbService = DatabaseService();
  final RealtimeSyncService _realtimeSyncService = RealtimeSyncService();
  final SyncStatusService _syncStatusService = SyncStatusService();

  void _scheduleDebouncedSync(String key, Future<void> Function() syncFn) {
    _pendingSyncJobs[key] = syncFn;

    final existingTimer = _syncDebounceTimers[key];
    existingTimer?.cancel();

    _syncDebounceTimers[key] = Timer(_syncDebounce, () async {
      _syncDebounceTimers.remove(key);
      final pendingJob = _pendingSyncJobs.remove(key);
      if (pendingJob == null) return;
      await _syncInBackground(pendingJob);
    });
  }

  // ============ COMMITTEE OPERATIONS WITH AUTO-SYNC ============

  Future<void> saveCommittee(Committee committee) async {
    // Save locally first
    await _dbService.saveCommittee(committee);

    // Sync to cloud in background (debounced)
    _scheduleDebouncedSync('committee:${committee.hostId}', () async {
      await _syncService.syncCommittees(committee.hostId);
    });
  }

  Future<bool> deleteCommittee(String committeeId, String hostId) async {
    // Mark as pending delete to prevent real-time sync from re-adding
    _realtimeSyncService.markCommitteeForDelete(committeeId);

    // Delete locally FIRST for instant UI feedback
    await _dbService.deleteCommittee(committeeId);

    // Delete from cloud in background (non-blocking)
    _syncInBackground(() async {
      try {
        final success = await _syncService.deleteCommitteeFromCloud(
          committeeId,
        );
        if (success) {
          print('Cloud delete succeeded for committee $committeeId');
        } else {
          print('Cloud delete failed for committee $committeeId');
        }
      } catch (e) {
        print('Cloud delete error: $e');
      }
    });

    return true; // Local delete always succeeds
  }

  Future<void> archiveCommittee(Committee committee) async {
    final archived = committee.copyWith(
      isArchived: true,
      archivedAt: DateTime.now(),
    );
    await saveCommittee(archived);
  }

  Future<void> unarchiveCommittee(Committee committee) async {
    final unarchived = Committee(
      id: committee.id,
      code: committee.code,
      name: committee.name,
      hostId: committee.hostId,
      contributionAmount: committee.contributionAmount,
      frequency: committee.frequency,
      startDate: committee.startDate,
      totalMembers: committee.totalMembers,
      createdAt: committee.createdAt,
      isActive: committee.isActive,
      paymentIntervalDays: committee.paymentIntervalDays,
      isArchived: false,
      archivedAt: null,
      isSynced: committee.isSynced, // Retain sync status
    );
    await _dbService.saveCommittee(unarchived);

    _scheduleDebouncedSync('committee:${committee.hostId}', () async {
      await _syncService.syncCommittees(committee.hostId);
    });
  }

  /// Archive a committee locally AND wipe all its child data from Supabase
  /// (proofs, payments, members) to free up storage — keeping committee row as marker.
  /// Returns true if cloud purge succeeded, false if offline (data stays local-only).
  Future<bool> purgeArchivedCommittee(Committee committee) async {
    // 1. Archive locally first (instant feedback)
    final archived = committee.copyWith(
      isArchived: true,
      archivedAt: committee.archivedAt ?? DateTime.now(),
    );
    await _dbService.saveCommittee(archived);

    // 2. Wipe members + their payments locally
    //    (deleteMembersByCommittee cascades to payments automatically)
    await _dbService.deleteMembersByCommittee(committee.id);

    // 3. Purge child cloud data (non-blocking, returns success flag)
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) return false;

    return await SupabaseService().purgeCommitteeCloudDataOnly(committee.id);
  }

  // ============ MEMBER OPERATIONS WITH AUTO-SYNC ============

  Future<void> saveMember(Member member) async {
    // Mark as pending update to prevent real-time sync from reverting
    _realtimeSyncService.markMemberForUpdate(member.id);

    await _dbService.saveMember(member);

    // Keep committee.totalMembers in sync with actual local member count
    // so that viewer-mode calendar can always find the correct cycle count.
    _updateCommitteeMemberCount(member.committeeId);

    _scheduleDebouncedSync('members:${member.committeeId}', () async {
      await _syncService.syncMembers(member.committeeId);
    });
  }

  Future<void> deleteMember(String memberId, String committeeId) async {
    // Mark as pending delete to prevent real-time sync from re-adding
    _realtimeSyncService.markMemberForDelete(memberId);

    // Delete locally first for instant UI
    await _dbService.deleteMember(memberId);

    // Keep committee.totalMembers in sync
    _updateCommitteeMemberCount(committeeId);

    // Delete from cloud
    _syncInBackground(() async {
      try {
        final success = await _syncService.deleteMemberFromCloud(memberId);
        if (success) {
          print('Cloud delete succeeded for member $memberId');
        } else {
          print('Cloud delete failed for member $memberId');
        }
      } catch (e) {
        print('Cloud member delete error: $e');
      }
    });
  }

  /// Re-counts all local members for the given committee and saves the updated
  /// totalMembers value back onto the committee record in Hive.
  void _updateCommitteeMemberCount(String committeeId) {
    try {
      final committee = _dbService.getCommitteeById(committeeId);
      if (committee == null) return;
      final memberCount =
          _dbService.getMembersByCommittee(committeeId).length;
      if (committee.totalMembers != memberCount) {
        _dbService.saveCommittee(
          committee.copyWith(totalMembers: memberCount),
        );
      }
    } catch (e) {
      // Non-critical: just a count update
      print('_updateCommitteeMemberCount error: $e');
    }
  }

  Future<void> updateMemberPayoutOrder(
    String memberId,
    int order,
    String committeeId,
  ) async {
    await _dbService.updateMemberPayoutOrder(memberId, order);

    _scheduleDebouncedSync('members:$committeeId', () async {
      await _syncService.syncMembers(committeeId);
    });
  }

  Future<void> updateMemberPayoutOrdersBatch(
    List<Member> orderedMembers,
    String committeeId,
  ) async {
    for (int i = 0; i < orderedMembers.length; i++) {
      final member = orderedMembers[i];
      _realtimeSyncService.markMemberForUpdate(member.id);
      await _dbService.updateMemberPayoutOrder(member.id, i + 1);
    }

    _scheduleDebouncedSync('members:$committeeId', () async {
      await _syncService.syncMembers(committeeId);
    });
  }

  // ============ PAYMENT OPERATIONS WITH AUTO-SYNC ============

  Future<void> savePayment(Payment payment) async {
    // Mark as pending update
    _realtimeSyncService.markPaymentForUpdate(payment.id);

    await _dbService.savePayment(payment);

    _scheduleDebouncedSync('payments:${payment.committeeId}', () async {
      await _syncService.syncPayments(payment.committeeId);
    });
  }

  Future<void> togglePayment(
    String memberId,
    String committeeId,
    DateTime date,
    String hostId,
  ) async {
    // Mark payment as pending to prevent real-time sync from reverting
    final paymentId = '${memberId}_${date.toIso8601String()}';
    _realtimeSyncService.markPaymentForUpdate(paymentId);

    await _dbService.togglePayment(memberId, committeeId, date, hostId);

    _scheduleDebouncedSync('payments:$committeeId', () async {
      await _syncService.syncPayments(committeeId);
    });
  }

  /// Toggle payment with cloud-first approach (no local caching)
  /// Pushes to Firebase first, then updates local for real-time sync
  Future<void> togglePaymentCloudFirst(
    String memberId,
    String committeeId,
    DateTime date,
    String hostId,
  ) async {
    // Fall back to original local-first approach since Firestore writes are timing out
    // This is the same as togglePayment but with a different name for API compatibility
    final paymentId = '${memberId}_${date.toIso8601String()}';

    // Mark payment as pending to prevent real-time sync from reverting
    _realtimeSyncService.markPaymentForUpdate(paymentId);

    // Save locally first (fast, reliable)
    await _dbService.togglePayment(memberId, committeeId, date, hostId);

    // Sync in background (may fail on web, but data is safe locally)
    _scheduleDebouncedSync('payments:$committeeId', () async {
      await _syncService.syncPayments(committeeId);
    });
  }

  // ============ HELPER ============

  Future<void> _syncInBackground(Future<void> Function() syncFn) async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity != ConnectivityResult.none) {
        _syncStatusService.setSyncing();
        await syncFn();
        _syncStatusService.setSynced();
      } else {
        _syncStatusService.addPendingChange();
      }
    } catch (e) {
      // Data is saved locally and will sync on next refresh
      _syncStatusService.setError('$e');
      print('Auto-sync failed (will retry on refresh): $e');
    }
  }
}
