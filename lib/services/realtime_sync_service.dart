import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/committee.dart';
import '../models/member.dart';
import '../models/payment.dart';
import 'database_service.dart';
import 'supabase_service.dart';

/// Helper to parse dates that can be Timestamp or String
DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

/// Real-time sync service that listens to Supabase changes
/// and updates local database automatically
class RealtimeSyncService {
  static final RealtimeSyncService _instance = RealtimeSyncService._internal();
  factory RealtimeSyncService() => _instance;
  RealtimeSyncService._internal();

  final SupabaseService _supabase = SupabaseService();
  final DatabaseService _dbService = DatabaseService();

  // Supabase Realtime Channel
  RealtimeChannel? _channel;

  // Track pending deletes to prevent re-syncing deleted items
  final Set<String> _pendingCommitteeDeletes = {};
  final Set<String> _pendingMemberDeletes = {};
  final Set<String> _pendingPaymentUpdates = {};  // For payment toggles and reverts

  // Callback for UI updates
  VoidCallback? onDataChanged;

  bool _isListening = false;
  String? _currentHostId;

  /// Mark a committee as pending delete (call before deleting)
  void markCommitteeForDelete(String committeeId) {
    _pendingCommitteeDeletes.add(committeeId);
    Future.delayed(const Duration(seconds: 10), () {
      _pendingCommitteeDeletes.remove(committeeId);
    });
  }

  /// Mark a member as pending delete
  void markMemberForDelete(String memberId) {
    _pendingMemberDeletes.add(memberId);
    Future.delayed(const Duration(seconds: 10), () {
      _pendingMemberDeletes.remove(memberId);
    });
  }

  /// Mark a member as pending update (for payout revert and edits)
  void markMemberForUpdate(String memberId) {
    _pendingMemberDeletes.add(memberId); // Reuse the same set to skip sync
    Future.delayed(const Duration(seconds: 10), () {
      _pendingMemberDeletes.remove(memberId);
    });
  }

  /// Mark a payment as pending update (for toggles and reverts)
  void markPaymentForUpdate(String paymentId) {
    _pendingPaymentUpdates.add(paymentId);
    Future.delayed(const Duration(seconds: 10), () {
      _pendingPaymentUpdates.remove(paymentId);
    });
  }

  /// Check if payment is pending update
  bool isPaymentPendingUpdate(String paymentId) {
    return _pendingPaymentUpdates.contains(paymentId);
  }

  /// Start listening to real-time updates for a host
  void startListening(String hostId) {
    if (_isListening && _currentHostId == hostId) return;
    
    stopListening();

    _currentHostId = hostId;
    _isListening = true;

    debugPrint('🔄 Starting Supabase real-time sync for host: $hostId');

    // Create a single channel for all tables and chain listeners
    _channel = _supabase.client.channel('public:app_sync');

    _channel!
      // 1. Listen to COMMITTEES
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: SupabaseService.committeesTable,
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'host_id',
          value: hostId,
        ),
        callback: (payload) => _handleCommitteeChange(payload),
      )
      // 2. Listen to MEMBERS
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: SupabaseService.membersTable,
        callback: (payload) => _handleMemberChange(payload),
      )
      // 3. Listen to PAYMENTS
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: SupabaseService.paymentsTable,
        callback: (payload) => _handlePaymentChange(payload),
      )
      .subscribe();
  }

  /// Handle committee changes
  void _handleCommitteeChange(PostgresChangePayload payload) async {
    final record = payload.newRecord; // null for DELETE
    final oldRecord = payload.oldRecord; // only has ID for DELETE usually

    if (payload.eventType == PostgresChangeEvent.delete) {
      final id = oldRecord['id'] as String;
      if (_pendingCommitteeDeletes.contains(id)) return;
      
      await _dbService.deleteCommittee(id);
      debugPrint('🗑️ Committee deleted (cloud): $id');
    } else {
      // INSERT or UPDATE
      if (record.isEmpty) return;
      
      final committee = Committee.fromJson(record);
      if (_pendingCommitteeDeletes.contains(committee.id)) return;

      await _dbService.saveCommittee(committee);
      debugPrint('💾 Committee synced: ${committee.name}');
    }
    onDataChanged?.call();
  }

  /// Handle member changes
  void _handleMemberChange(PostgresChangePayload payload) async {
    final record = payload.newRecord;
    final oldRecord = payload.oldRecord;

    if (payload.eventType == PostgresChangeEvent.delete) {
      final id = oldRecord['id'] as String;
      if (_pendingMemberDeletes.contains(id)) return;

      await _dbService.deleteMember(id);
      debugPrint('🗑️ Member deleted (cloud): $id');
    } else {
      if (record.isEmpty) return;
      
      final member = Member.fromJson(record);
       if (_pendingMemberDeletes.contains(member.id)) return;

      // Verify we have the committee locally (optional, but good for consistency)
      // await _dbService.saveMember(member);
      // Logic from old service: check for newer data?
      // Supabase Realtime pushes LATEST data. So we generally trust it.
      await _dbService.saveMember(member);
      debugPrint('💾 Member synced: ${member.name}');
    }
    onDataChanged?.call();
  }

  /// Handle payment changes
  void _handlePaymentChange(PostgresChangePayload payload) async {
    final record = payload.newRecord;
    final oldRecord = payload.oldRecord;

    if (payload.eventType == PostgresChangeEvent.delete) {
      final id = oldRecord['id'] as String;
      if (_pendingPaymentUpdates.contains(id)) return;

      await _dbService.deletePayment(id);
    } else {
      if (record.isEmpty) return;
      
      final payment = Payment.fromJson(record);
      if (_pendingPaymentUpdates.contains(payment.id)) return;

      await _dbService.savePayment(payment);
      // debugPrint('💾 Payment synced: ${payment.id} isPaid: ${payment.isPaid}');
    }
    onDataChanged?.call();
  }

  /// Stop all listeners
  void stopListening() {
    if (_isListening) {
      debugPrint('⏹️ Stopping Supabase real-time sync');
      _supabase.client.removeAllChannels();
      _channel = null;
      _isListening = false;
      _currentHostId = null;
    }
  }
}
