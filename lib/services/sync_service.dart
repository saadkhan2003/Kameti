import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/committee.dart';
import '../models/member.dart';
import '../models/payment.dart';
import 'database_service.dart';
import 'supabase_service.dart';

class SyncService {
  final SupabaseService _supabase = SupabaseService();
  final DatabaseService _dbService = DatabaseService();

  // Check if online
  Future<bool> isOnline() async {
    final result = await Connectivity().checkConnectivity();
    // connectivity_plus returns List<ConnectivityResult>
    if (result is List) {
      return !(result as List).contains(ConnectivityResult.none);
    }
    // Fallback for older versions
    return result != ConnectivityResult.none;
  }

  // ============ SYNC ALL DATA ============

  Future<SyncResult> syncAll(String hostId) async {
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
        futures.add(syncMembers(committee.id).catchError((e) {
          print('⚠️ Sync members failed for ${committee.id}: $e');
          return SyncCounts();
        }));
        
        futures.add(syncPayments(committee.id).catchError((e) {
          print('⚠️ Sync payments failed for ${committee.id}: $e');
          return SyncCounts();
        }));
      }
      
      // Wait for all parallel syncs to complete
      final results = await Future.wait(futures);
      for (final result in results) {
        uploaded += result.uploaded;
        downloaded += result.downloaded;
      }

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
        
        if (remote.createdAt.isAfter(local.createdAt)) { // Using CreatedAt as proxy for update is flawed but existing logic
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
          print('🗑️ Sync: Committee ${local.name} was deleted remotely. removing locally.');
          await _dbService.deleteCommittee(local.id);
        } else {
          // Case B: Never synced -> New Local Committee
          // Action: Upload to cloud
          print('ki Sync: New local committee ${local.name} found. Uploading.');
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
          if (cloudMember.payoutDate != null && localMember.payoutDate != null) {
            // Both have dates - take newer
            shouldDownload = cloudMember.payoutDate!.isAfter(localMember.payoutDate!);
          } else if (cloudMember.payoutDate != null && localMember.payoutDate == null) {
            // Cloud has payout, local doesn't - cloud marked payout
            shouldDownload = true;
          } else if (cloudMember.payoutDate == null && localMember.payoutDate != null) {
            // Cloud was REVERTED - download the reverted state
            shouldDownload = true;
          } else {
            // Both null - compare hasReceivedPayout directly
            shouldDownload = cloudMember.hasReceivedPayout != localMember.hasReceivedPayout;
          }
        }
        // Also check for payoutOrder changes
        if (cloudMember.payoutOrder != localMember.payoutOrder) {
          shouldDownload = true;
        }
        // Also check for name/phone changes
        if (cloudMember.name != localMember.name || cloudMember.phone != localMember.phone) {
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

    // Upload local payments to Supabase using batch (faster)
    final localPayments = _dbService.getPaymentsByCommittee(committeeId);
    print('📦 Local payments to upload: ${localPayments.length}');
    
    if (localPayments.isNotEmpty) {
      // Use Supabase Service's batch upsert
      await _supabase.upsertPayments(localPayments);
      uploaded += localPayments.length;
    }

    // Download payments from Supabase
    final cloudPayments = await _supabase.getPayments(committeeId);

    for (final cloudPayment in cloudPayments) {
      final existingPayment = _dbService.getPayment(
        cloudPayment.memberId,
        cloudPayment.date,
      );

      bool shouldDownload = false;
      
      if (existingPayment == null) {
        shouldDownload = true;
      } else if (cloudPayment.isPaid != existingPayment.isPaid) {
        // Payment status changed - compare timestamps
        if (cloudPayment.markedAt != null && existingPayment.markedAt != null) {
          shouldDownload = cloudPayment.markedAt!.isAfter(existingPayment.markedAt!);
        } else if (cloudPayment.markedAt != null) {
          shouldDownload = true;
        }
      } else if (cloudPayment.markedAt != null && existingPayment.markedAt != null) {
        // Same status but check if cloud is newer
        shouldDownload = cloudPayment.markedAt!.isAfter(existingPayment.markedAt!);
      }

      if (shouldDownload) {
        await _dbService.savePayment(cloudPayment);
        downloaded++;
      }
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
      print('Successfully deleted committee $committeeId from cloud');
      return true;
    } catch (e) {
      print('Error deleting committee from cloud: $e');
      return false;
    }
  }

  /// Delete a single member from Supabase
  Future<bool> deleteMemberFromCloud(String memberId) async {
    if (!await isOnline()) return false;

    try {
      await _supabase.deleteMember(memberId);
      // Payments should cascade delete
      print('Successfully deleted member $memberId from cloud');
      return true;
    } catch (e) {
      print('Error deleting member from cloud: $e');
      return false;
    }
  }

  // ============ VIEWER SYNC (READ-ONLY) ============

  /// Sync committee by code - READ ONLY for viewers (no uploads)
  Future<Committee?> syncCommitteeByCode(String code) async {
    if (!await isOnline()) return null;

    try {
      // 1. Fetch Committee by its 'code' field (6-digit sharing code)
      final response = await _supabase.client
          .from(SupabaseService.committeesTable)
          .select()
          .eq('code', code) // Query by the 'code' field, not 'id'
          .maybeSingle();
      
      if (response == null) return null;

      final committee = Committee.fromJson(response);
      await _dbService.saveCommittee(committee);

      // 2. Download Members (READ-ONLY - no upload)
      await _downloadMembersOnly(committee.id);

      // 3. Download Payments (READ-ONLY - no upload)
      await _downloadPaymentsOnly(committee.id);

      return committee;
    } catch (e) {
      print('Viewer sync error: $e');
      return null;
    }
  }

  /// Download members from cloud only - no upload (for viewers)
  Future<int> _downloadMembersOnly(String committeeId) async {
    int downloaded = 0;
    try {
      final cloudMembers = await _supabase.getMembers(committeeId);
      print('📥 Downloaded ${cloudMembers.length} members from cloud');
      
      for (final cloudMember in cloudMembers) {
        await _dbService.saveMember(cloudMember);
        downloaded++;
      }
    } catch (e) {
      print('Error downloading members: $e');
    }
    return downloaded;
  }

  /// Download payments from cloud only - no upload (for viewers)
  Future<int> _downloadPaymentsOnly(String committeeId) async {
    int downloaded = 0;
    try {
      final cloudPayments = await _supabase.getPayments(committeeId);
      print('📥 Downloaded ${cloudPayments.length} payments from cloud');
      
      for (final payment in cloudPayments) {
        await _dbService.savePayment(payment);
        downloaded++;
      }
    } catch (e) {
      print('Error downloading payments: $e');
    }
    return downloaded;
  }

  /// Refresh viewer data from cloud (read-only)
  Future<void> refreshViewerData(String committeeId) async {
    if (!await isOnline()) {
      throw Exception('No internet connection');
    }
    
    print('🔄 Refreshing viewer data for committee: $committeeId');
    await _downloadMembersOnly(committeeId);
    await _downloadPaymentsOnly(committeeId);
    print('✅ Viewer data refreshed');
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
    print('🔥 pushPaymentToCloud: ${payment.id}');
    
    if (!await isOnline()) {
      throw Exception('No internet connection');
    }

    await _supabase.upsertPayment(payment);
    print('✅ Payment pushed: ${payment.id}');
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
          print('🔄 Migrating committee ${committee.name} from ${committee.hostId} to $currentHostId');
          
          final updatedCommittee = committee.copyWith(hostId: currentHostId);
          await _dbService.saveCommittee(updatedCommittee);
          migrationOccurred = true;
        }
      }

      if (migrationOccurred) {
        print('✅ Migration of local data ownership complete.');
      }
    } catch (e) {
      print('⚠️ Migration error: $e');
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
