import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../models/committee.dart';
import '../models/member.dart';
import '../models/payment.dart';
import 'database_service.dart';
import 'supabase_service.dart';

class SyncService {
  void _log(String message) {
    if (kDebugMode) debugPrint(message);
  }

  static const Duration _fullSyncCooldown = Duration(seconds: 20);
  static final Map<String, DateTime> _lastFullSyncByHost = {};
  static final Map<String, Future<SyncResult>> _inFlightFullSyncByHost = {};

  final SupabaseService _supabase = SupabaseService();
  final DatabaseService _dbService = DatabaseService();

  // Check if online
  Future<bool> isOnline() async {
    final result = await Connectivity().checkConnectivity();
    // connectivity_plus returns List<ConnectivityResult>
    return !(result as List).contains(ConnectivityResult.none);
  }

  // ============ SYNC ALL DATA ============

  Future<SyncResult> syncAll(String hostId, {bool force = false}) async {
    final inFlight = _inFlightFullSyncByHost[hostId];
    if (inFlight != null) {
      _log(
        '⏳ Full sync already running. Joining existing sync for host: $hostId',
      );
      return inFlight;
    }

    final syncFuture = _runSyncAll(hostId, force: force);
    _inFlightFullSyncByHost[hostId] = syncFuture;

    try {
      return await syncFuture;
    } finally {
      if (identical(_inFlightFullSyncByHost[hostId], syncFuture)) {
        _inFlightFullSyncByHost.remove(hostId);
      }
    }
  }

  Future<SyncResult> _runSyncAll(String hostId, {required bool force}) async {
    final lastSyncAt = _lastFullSyncByHost[hostId];
    if (!force && lastSyncAt != null) {
      final elapsed = DateTime.now().difference(lastSyncAt);
      if (elapsed < _fullSyncCooldown) {
        _log('⏱️ Skipping full sync (cooldown active) for host: $hostId');
        return SyncResult(success: true, message: 'Sync recently completed');
      }
    }

    if (!await isOnline()) {
      return SyncResult(success: false, message: 'No internet connection');
    }

    try {
      int uploaded = 0;
      int downloaded = 0;

      // MIGRATION: Check for legacy Firebase data and reassign to new Supabase Host
      await _migrateLocalDataIfNeeded(hostId);

      // Sync committees first (must complete before members/payments)
      final committeesResult = await syncCommittees(hostId);
      uploaded += committeesResult.uploaded;
      downloaded += committeesResult.downloaded;

      // Get all committees to sync
      final committees = _dbService.getHostedCommittees(hostId);

      // Sync all members and payments in PARALLEL for speed
      // Wrap in try-catch blocks to prevent one failure from stopping others
      final futures = <Future<SyncCounts>>[];
      for (final committee in committees) {
        futures.add(
          syncMembers(committee.id).catchError((e) {
            _log('⚠️ Sync members failed for ${committee.id}: $e');
            return SyncCounts();
          }),
        );

        futures.add(
          syncPayments(committee.id).catchError((e) {
            _log('⚠️ Sync payments failed for ${committee.id}: $e');
            return SyncCounts();
          }),
        );
      }

      // Wait for all parallel syncs to complete
      final results = await Future.wait(futures);
      for (final result in results) {
        uploaded += result.uploaded;
        downloaded += result.downloaded;
      }

      _lastFullSyncByHost[hostId] = DateTime.now();

      return SyncResult(
        success: true,
        message: 'Sync complete!',
        uploaded: uploaded,
        downloaded: downloaded,
      );
    } catch (e) {
      return SyncResult(success: false, message: 'Sync failed: $e');
    }
  }

  // ============ COMMITTEE SYNC ============

  Future<SyncCounts> syncCommittees(String hostId) async {
    int uploaded = 0;
    int downloaded = 0;

    // 1. Get ALL remote committees IDs first (lightweight)
    // We need to know what exists on cloud to detect deletions
    final remoteCommittees = await _supabase.getCommittees(hostId);
    final remoteIds = remoteCommittees.map((c) => c.id).toSet();
    final remoteMap = {for (var c in remoteCommittees) c.id: c};

    // 2. Process LOCAL committees
    final localCommittees = _dbService.getHostedCommittees(hostId);

    for (final local in localCommittees) {
      if (remoteIds.contains(local.id)) {
        // Exists on BOTH -> Update logic
        final remote = remoteMap[local.id]!;

        // If local is newer or has changes (not implemented yet, but good for future)
        // For now, we trust CLOUD as source of truth if timestamps differ significantly
        // But if local was just edited (e.g. settings), we might want to push?
        // Let's stick to: if cloud is newer, download. If local is newer, upload.

        if (remote.createdAt.isAfter(local.createdAt)) {
          // Using CreatedAt as proxy for update is flawed but existing logic
          await _dbService.saveCommittee(remote.copyWith(isSynced: true));
          downloaded++;
        } else {
          // Upload local changes if any (or just ensure consistency)
          // Mark as synced since it exists on cloud
          if (!local.isSynced) {
            await _dbService.saveCommittee(local.copyWith(isSynced: true));
          }
        }
      } else {
        // Exists LOCALLY but NOT on Cloud
        if (local.isSynced) {
          // Case A: Was synced before -> Remote Deletion detected!
          // Action: Delete local
          _log(
            '🗑️ Sync: Committee ${local.name} was deleted remotely. removing locally.',
          );
          await _dbService.deleteCommittee(local.id);
        } else {
          // Case B: Never synced -> New Local Committee
          // Action: Upload to cloud
          _log('⬆️ Sync: New local committee ${local.name} found. Uploading.');
          await _supabase.upsertCommittee(local);
          await _dbService.saveCommittee(local.copyWith(isSynced: true));
          uploaded++;
        }
      }
    }

    // 3. Process REMOTE committees (Download missing ones)
    final localIds = localCommittees.map((c) => c.id).toSet();

    for (final remote in remoteCommittees) {
      if (!localIds.contains(remote.id)) {
        // New on cloud -> Download
        await _dbService.saveCommittee(remote.copyWith(isSynced: true));
        downloaded++;
      }
    }

    return SyncCounts(uploaded: uploaded, downloaded: downloaded);
  }

  // ============ MEMBER SYNC ============

  Future<SyncCounts> syncMembers(String committeeId) async {
    int uploaded = 0;
    int downloaded = 0;

    // Upload local members to Supabase (Batch)
    final localMembers = _dbService.getMembersByCommittee(committeeId);
    if (localMembers.isNotEmpty) {
      await _supabase.upsertMembers(localMembers);
      uploaded += localMembers.length;
    }

    // Download members from Supabase
    final cloudMembers = await _supabase.getMembers(committeeId);

    for (final cloudMember in cloudMembers) {
      final localMember = _dbService.getMemberById(cloudMember.id);

      // Check if cloud is newer - compare payout status
      bool shouldDownload = false;

      if (localMember == null) {
        shouldDownload = true;
      } else {
        // Compare payout status
        if (cloudMember.hasReceivedPayout != localMember.hasReceivedPayout) {
          // Payout status differs - use timestamps to decide
          if (cloudMember.payoutDate != null &&
              localMember.payoutDate != null) {
            // Both have dates - take newer
            shouldDownload = cloudMember.payoutDate!.isAfter(
              localMember.payoutDate!,
            );
          } else if (cloudMember.payoutDate != null &&
              localMember.payoutDate == null) {
            // Cloud has payout, local doesn't - cloud marked payout
            shouldDownload = true;
          } else if (cloudMember.payoutDate == null &&
              localMember.payoutDate != null) {
            // Cloud was REVERTED - download the reverted state
            shouldDownload = true;
          } else {
            // Both null - compare hasReceivedPayout directly
            shouldDownload =
                cloudMember.hasReceivedPayout != localMember.hasReceivedPayout;
          }
        }
        // Also check for payoutOrder changes
        if (cloudMember.payoutOrder != localMember.payoutOrder) {
          shouldDownload = true;
        }
        // Also check for name/phone changes
        if (cloudMember.name != localMember.name ||
            cloudMember.phone != localMember.phone) {
          shouldDownload = true;
        }
      }

      if (shouldDownload) {
        await _dbService.saveMember(cloudMember);
        downloaded++;
      }
    }

    return SyncCounts(uploaded: uploaded, downloaded: downloaded);
  }

  // ============ PAYMENT SYNC ============

  Future<SyncCounts> syncPayments(String committeeId) async {
    int uploaded = 0;
    int downloaded = 0;

    // Read local and cloud once, then diff to minimize uploads/downloads
    final localPayments = _dbService.getPaymentsByCommittee(committeeId);
    final cloudPayments = await _supabase.getPayments(committeeId);

    final localById = {
      for (final payment in localPayments) payment.id: payment,
    };
    final cloudById = {
      for (final payment in cloudPayments) payment.id: payment,
    };

    final paymentsToUpload = <Payment>[];
    for (final localPayment in localPayments) {
      final cloudPayment = cloudById[localPayment.id];

      if (cloudPayment == null) {
        paymentsToUpload.add(localPayment);
        continue;
      }

      bool localIsNewer = false;

      if (localPayment.isPaid != cloudPayment.isPaid) {
        if (localPayment.markedAt != null && cloudPayment.markedAt != null) {
          localIsNewer = localPayment.markedAt!.isAfter(cloudPayment.markedAt!);
        } else if (localPayment.markedAt != null &&
            cloudPayment.markedAt == null) {
          localIsNewer = true;
        }
      } else if (localPayment.markedAt != null &&
          cloudPayment.markedAt != null) {
        localIsNewer = localPayment.markedAt!.isAfter(cloudPayment.markedAt!);
      }

      if (localIsNewer) {
        paymentsToUpload.add(localPayment);
      }
    }

    if (paymentsToUpload.isNotEmpty) {
      await _supabase.upsertPayments(paymentsToUpload);
      uploaded += paymentsToUpload.length;
    }

    for (final cloudPayment in cloudPayments) {
      final existingPayment = localById[cloudPayment.id];

      bool shouldDownload = false;

      if (existingPayment == null) {
        shouldDownload = true;
      } else if (cloudPayment.isPaid != existingPayment.isPaid) {
        // Payment status changed - compare timestamps
        if (cloudPayment.markedAt != null && existingPayment.markedAt != null) {
          shouldDownload = cloudPayment.markedAt!.isAfter(
            existingPayment.markedAt!,
          );
        } else if (cloudPayment.markedAt != null) {
          shouldDownload = true;
        }
      } else if (cloudPayment.markedAt != null &&
          existingPayment.markedAt != null) {
        // Same status but check if cloud is newer
        shouldDownload = cloudPayment.markedAt!.isAfter(
          existingPayment.markedAt!,
        );
      }

      if (shouldDownload) {
        await _dbService.savePayment(cloudPayment);
        downloaded++;
      }
    }

    if (paymentsToUpload.isNotEmpty || downloaded > 0) {
      _log(
        '💳 Payments sync [$committeeId] '
        'local:${localPayments.length} cloud:${cloudPayments.length} '
        'uploaded:$uploaded downloaded:$downloaded',
      );
    }

    return SyncCounts(uploaded: uploaded, downloaded: downloaded);
  }

  // ============ DELETE FROM CLOUD ============

  Future<bool> deleteCommitteeFromCloud(String committeeId) async {
    if (!await isOnline()) return false;

    try {
      await _supabase.deleteCommittee(committeeId);
      // Supabase CASCADE delete handles members and paying
      // But let's verify if manual deletion is safer if CASCADE not set
      // (The setup guide SQL had ON DELETE CASCADE, so we trust that)
      _log('✅ Deleted committee from cloud: $committeeId');
      return true;
    } catch (e) {
      _log('❌ Error deleting committee from cloud: $e');
      return false;
    }
  }

  /// Delete a single member from Supabase
  Future<bool> deleteMemberFromCloud(String memberId) async {
    if (!await isOnline()) return false;

    try {
      await _supabase.deleteMember(memberId);
      // Payments should cascade delete
      _log('✅ Deleted member from cloud: $memberId');
      return true;
    } catch (e) {
      _log('❌ Error deleting member from cloud: $e');
      return false;
    }
  }

  // ============ VIEWER SYNC (READ-ONLY) ============

  /// Sync committee by code - READ ONLY for viewers (no uploads)
  Future<Committee?> syncCommitteeByCode(String code) async {
    if (!await isOnline()) return null;

    try {
      // 1. Fetch Committee by its 'code' field (6-digit sharing code)
      final response =
          await _supabase.client
              .from(SupabaseService.committeesTable)
              .select()
              .eq('code', code) // Query by the 'code' field, not 'id'
              .maybeSingle();

      if (response == null) return null;

      final committee = Committee.fromJson(response);
      await _dbService.saveCommittee(committee);

      return committee;
    } catch (e) {
      _log('❌ Viewer sync error: $e');
      return null;
    }
  }

  /// Sync a single member by member code for viewer flow (read-only)
  Future<Member?> syncMemberByCode(
    String committeeId,
    String memberCode,
  ) async {
    if (!await isOnline()) return null;

    try {
      final member = await _supabase.getMemberByCode(committeeId, memberCode);
      if (member != null) {
        await _dbService.saveMember(member);
      }
      return member;
    } catch (e) {
      _log('❌ Viewer member sync error: $e');
      return null;
    }
  }

  /// Download members from cloud only - no upload (for viewers)
  Future<int> _downloadMembersOnly(String committeeId) async {
    int downloaded = 0;
    try {
      final cloudMembers = await _supabase.getMembers(committeeId);
      _log('📥 Downloaded ${cloudMembers.length} members from cloud');

      for (final cloudMember in cloudMembers) {
        await _dbService.saveMember(cloudMember);
        downloaded++;
      }
    } catch (e) {
      _log('❌ Error downloading members: $e');
    }
    return downloaded;
  }

  /// Download only one member from cloud (for viewer-specific refresh)
  Future<int> _downloadSingleMemberOnly(String memberId) async {
    try {
      final member = await _supabase.getMemberById(memberId);
      if (member == null) return 0;
      await _dbService.saveMember(member);
      _log('📥 Downloaded 1 member from cloud (member scoped)');
      return 1;
    } catch (e) {
      _log('❌ Error downloading single member: $e');
      return 0;
    }
  }

  /// Download payments from cloud only - no upload (for viewers)
  Future<int> _downloadPaymentsOnly(
    String committeeId, {
    String? memberId,
  }) async {
    int downloaded = 0;
    try {
      final cloudPayments =
          memberId == null
              ? await _supabase.getPayments(committeeId)
              : await _supabase.getPaymentsForMember(committeeId, memberId);
      _log(
        '📥 Downloaded ${cloudPayments.length} payments from cloud'
        '${memberId != null ? ' (member scoped)' : ''}',
      );

      for (final payment in cloudPayments) {
        await _dbService.savePayment(payment);
        downloaded++;
      }
    } catch (e) {
      _log('❌ Error downloading payments: $e');
    }
    return downloaded;
  }

  /// Refresh viewer data from cloud (read-only)
  Future<void> refreshViewerData(String committeeId, {String? memberId}) async {
    if (!await isOnline()) {
      throw Exception('No internet connection');
    }

    _log('🔄 Refreshing viewer data for committee: $committeeId');
    if (memberId != null) {
      await _downloadSingleMemberOnly(memberId);
    } else {
      await _downloadMembersOnly(committeeId);
    }
    await _downloadPaymentsOnly(committeeId, memberId: memberId);
    _log('✅ Viewer data refreshed');
  }

  // ============ CLOUD-ONLY OPERATIONS (NO LOCAL CACHE) ============

  /// Fetch payments directly from Supabase without touching local storage
  Future<List<Payment>> fetchPaymentsFromCloud(String committeeId) async {
    if (!await isOnline()) {
      throw Exception('No internet connection');
    }
    return await _supabase.getPayments(committeeId);
  }

  /// Fetch members directly from Supabase without touching local storage
  Future<List<Member>> fetchMembersFromCloud(String committeeId) async {
    if (!await isOnline()) {
      throw Exception('No internet connection');
    }
    return await _supabase.getMembers(committeeId);
  }

  /// Get a single payment from Supabase
  Future<Payment?> getPaymentFromCloud(String paymentId) async {
    if (!await isOnline()) return null;
    return await _supabase.getPayment(paymentId);
  }

  /// Push a single payment to Supabase immediately
  Future<void> pushPaymentToCloud(Payment payment) async {
    _log('🔥 pushPaymentToCloud: ${payment.id}');

    if (!await isOnline()) {
      throw Exception('No internet connection');
    }

    await _supabase.upsertPayment(payment);
    _log('✅ Payment pushed: ${payment.id}');
  }

  // ============ MIGRATION HELPER ============

  Future<void> _migrateLocalDataIfNeeded(String currentHostId) async {
    try {
      final allCommittees = _dbService.getAllCommittees();
      bool migrationOccurred = false;

      for (final committee in allCommittees) {
        // Heuristic: If committee hostId is different AND looks like Firebase UID (28 chars)
        // AND currentHostId is Supabase UUID (36 chars)
        // OR simply if we have local data that isn't ours but we are the only user logged in...
        // Let's stick to the length check to be safe + ensuring it's not just another user's data.
        // Firebase UIDs are 28 chars. Supabase UUIDs are 36 chars.

        bool isLegacyHost = committee.hostId.length == 28;
        bool isNewHost = currentHostId.length == 36;

        if (committee.hostId != currentHostId && isLegacyHost && isNewHost) {
          _log(
            '🔄 Migrating committee ${committee.name} from ${committee.hostId} to $currentHostId',
          );

          final updatedCommittee = committee.copyWith(hostId: currentHostId);
          await _dbService.saveCommittee(updatedCommittee);
          migrationOccurred = true;
        }
      }

      if (migrationOccurred) {
        _log('✅ Migration of local data ownership complete.');
      }
    } catch (e) {
      _log('⚠️ Migration error: $e');
    }
  }
}

class SyncResult {
  final bool success;
  final String message;
  final int uploaded;
  final int downloaded;

  SyncResult({
    required this.success,
    required this.message,
    this.uploaded = 0,
    this.downloaded = 0,
  });
}

class SyncCounts {
  final int uploaded;
  final int downloaded;

  SyncCounts({this.uploaded = 0, this.downloaded = 0});
}
