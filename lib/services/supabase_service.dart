import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import '../models/committee.dart';
import '../models/member.dart';
import '../models/payment.dart';
import '../models/payment_proof.dart';

/// Supabase service for database operations
/// Replaces Firebase Firestore with Supabase PostgreSQL
class SupabaseService {
  void _log(String message) {
    if (kDebugMode) debugPrint(message);
  }

  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  SupabaseClient get client => Supabase.instance.client;

  // Table names
  static const String committeesTable = 'committees';
  static const String membersTable = 'members';
  static const String paymentsTable = 'payments';
  static const String paymentProofsTable = 'payment_proofs';

  static const int _batchSize = 500;

  static const String _committeeColumns =
      'id,code,name,host_id,contribution_amount,frequency,start_date,total_members,created_at,'
      'is_active,payment_interval_days,is_archived,archived_at,total_cycles,is_synced,currency';

  static const String _memberColumns =
      'id,committee_id,member_code,name,phone,payout_order,has_received_payout,payout_date,created_at';

  static const String _paymentColumns =
      'id,member_id,committee_id,date,is_paid,marked_by,marked_at';

  static const String _paymentProofColumns =
      'id,payment_id,committee_id,member_id,host_id,cloudinary_url,cloudinary_public_id,status,'
      'rejection_reason,reviewed_by,reviewed_at,created_at,updated_at';

  List<Map<String, dynamic>> _toRows(dynamic response) {
    return (response as List)
        .map((row) => Map<String, dynamic>.from(row as Map))
        .toList(growable: false);
  }

  Map<String, dynamic>? _toRow(dynamic response) {
    if (response == null) return null;
    return Map<String, dynamic>.from(response as Map);
  }

  Future<void> _upsertInBatches(
    String table,
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) return;

    for (int i = 0; i < rows.length; i += _batchSize) {
      final end = (i + _batchSize < rows.length) ? i + _batchSize : rows.length;
      final batch = rows.sublist(i, end);
      await client.from(table).upsert(batch);
    }
  }

  // ============================================
  // COMMITTEES
  // ============================================

  /// Get all committees for a host
  Future<List<Committee>> getCommittees(String hostId) async {
    try {
      _log('🔍 Supabase: Fetching committees for host $hostId');
      final response = await client
          .from(committeesTable)
          .select(_committeeColumns)
          .eq('host_id', hostId);

      final rows = _toRows(response);
      final committees = rows.map(Committee.fromJson).toList(growable: false);

      _log('✅ Supabase: Parsed ${committees.length} committees');
      return committees;
    } catch (e) {
      _log('❌ Error getting committees: $e');
      return [];
    }
  }

  /// Get a single committee by ID
  Future<Committee?> getCommittee(String committeeId) async {
    try {
      final response =
          await client
              .from(committeesTable)
              .select(_committeeColumns)
              .eq('id', committeeId)
              .maybeSingle();

      final row = _toRow(response);
      return row != null ? Committee.fromJson(row) : null;
    } catch (e) {
      _log('❌ Error getting committee: $e');
      return null;
    }
  }

  /// Create or update a committee
  Future<void> upsertCommittee(Committee committee) async {
    await client.from(committeesTable).upsert(committee.toJson());
  }

  /// Delete a committee
  Future<void> deleteCommittee(String committeeId) async {
    await client.from(committeesTable).delete().eq('id', committeeId);
  }

  /// Subscribe to committee changes for a host
  Stream<List<Committee>> watchCommittees(String hostId) {
    return client
        .from(committeesTable)
        .stream(primaryKey: ['id'])
        .eq('host_id', hostId)
        .map((data) => data.map((json) => Committee.fromJson(json)).toList());
  }

  // ============================================
  // MEMBERS
  // ============================================

  /// Get all members for a committee
  Future<List<Member>> getMembers(String committeeId) async {
    try {
      final response = await client
          .from(membersTable)
          .select(_memberColumns)
          .eq('committee_id', committeeId);

      final rows = _toRows(response);
      return rows.map(Member.fromJson).toList(growable: false);
    } catch (e) {
      _log('❌ Error getting members: $e');
      return [];
    }
  }

  /// Get a single member by ID
  Future<Member?> getMemberById(String memberId) async {
    try {
      final response =
          await client
              .from(membersTable)
              .select(_memberColumns)
              .eq('id', memberId)
              .maybeSingle();

      final row = _toRow(response);
      return row != null ? Member.fromJson(row) : null;
    } catch (e) {
      _log('❌ Error getting member by id: $e');
      return null;
    }
  }

  /// Get a single member by member code within a committee
  Future<Member?> getMemberByCode(String committeeId, String memberCode) async {
    try {
      final response =
          await client
              .from(membersTable)
              .select(_memberColumns)
              .eq('committee_id', committeeId)
              .eq('member_code', memberCode)
              .maybeSingle();

      final row = _toRow(response);
      return row != null ? Member.fromJson(row) : null;
    } catch (e) {
      _log('❌ Error getting member by code: $e');
      return null;
    }
  }

  /// Get member count for a committee (lightweight helper)
  Future<int> getMemberCount(String committeeId) async {
    try {
      final response = await client
          .from(membersTable)
          .select('id')
          .eq('committee_id', committeeId);

      return _toRows(response).length;
    } catch (e) {
      _log('❌ Error getting member count: $e');
      return 0;
    }
  }

  /// Create or update a member
  Future<void> upsertMember(Member member) async {
    await client.from(membersTable).upsert(member.toJson());
  }

  /// Batch upsert members
  Future<void> upsertMembers(List<Member> members) async {
    if (members.isEmpty) return;
    await _upsertInBatches(
      membersTable,
      members.map((m) => m.toJson()).toList(growable: false),
    );
  }

  /// Delete a member
  Future<void> deleteMember(String memberId) async {
    await client.from(membersTable).delete().eq('id', memberId);
  }

  /// Subscribe to member changes for a committee
  Stream<List<Member>> watchMembers(String committeeId) {
    return client
        .from(membersTable)
        .stream(primaryKey: ['id'])
        .eq('committee_id', committeeId)
        .map((data) => data.map((json) => Member.fromJson(json)).toList());
  }

  // ============================================
  // PAYMENTS
  // ============================================

  /// Get all payments for a committee
  Future<List<Payment>> getPayments(String committeeId) async {
    try {
      final response = await client
          .from(paymentsTable)
          .select(_paymentColumns)
          .eq('committee_id', committeeId);

      final rows = _toRows(response);
      return rows.map(Payment.fromJson).toList(growable: false);
    } catch (e) {
      _log('❌ Error getting payments: $e');
      return [];
    }
  }

  /// Get payments for a specific member in a committee
  Future<List<Payment>> getPaymentsForMember(
    String committeeId,
    String memberId,
  ) async {
    try {
      final response = await client
          .from(paymentsTable)
          .select(_paymentColumns)
          .eq('committee_id', committeeId)
          .eq('member_id', memberId);

      final rows = _toRows(response);
      return rows.map(Payment.fromJson).toList(growable: false);
    } catch (e) {
      _log('❌ Error getting member payments: $e');
      return [];
    }
  }

  /// Get a single payment
  Future<Payment?> getPayment(String paymentId) async {
    try {
      final response =
          await client
              .from(paymentsTable)
              .select(_paymentColumns)
              .eq('id', paymentId)
              .maybeSingle();

      final row = _toRow(response);
      return row != null ? Payment.fromJson(row) : null;
    } catch (e) {
      _log('❌ Error getting payment: $e');
      return null;
    }
  }

  /// Create or update a payment
  Future<void> upsertPayment(Payment payment) async {
    await client.from(paymentsTable).upsert(payment.toJson());
  }

  /// Batch upsert payments
  Future<void> upsertPayments(List<Payment> payments) async {
    if (payments.isEmpty) return;

    final rows = payments.map((p) => p.toJson()).toList(growable: false);
    for (int i = 0; i < rows.length; i += _batchSize) {
      final end = (i + _batchSize < rows.length) ? i + _batchSize : rows.length;
      final batch = rows.sublist(i, end);
      await client.from(paymentsTable).upsert(batch);
      _log('✅ Synced batch ${i ~/ _batchSize + 1}: ${batch.length} payments');
    }
  }

  /// Subscribe to payment changes for a committee
  Stream<List<Payment>> watchPayments(String committeeId) {
    return client
        .from(paymentsTable)
        .stream(primaryKey: ['id'])
        .eq('committee_id', committeeId)
        .map((data) => data.map((json) => Payment.fromJson(json)).toList());
  }

  // ============================================
  // PAYMENT PROOFS
  // ============================================

  Future<PaymentProof?> getLatestProofForPayment(String paymentId) async {
    try {
      final response =
          await client
              .from(paymentProofsTable)
              .select(_paymentProofColumns)
              .eq('payment_id', paymentId)
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle();

      final row = _toRow(response);
      return row != null ? PaymentProof.fromJson(row) : null;
    } catch (e) {
      _log('❌ Error getting latest payment proof: $e');
      return null;
    }
  }

  Future<List<PaymentProof>> getProofsForMember(
    String memberId,
    String committeeId,
  ) async {
    try {
      final response = await client
          .from(paymentProofsTable)
          .select(_paymentProofColumns)
          .eq('member_id', memberId)
          .eq('committee_id', committeeId)
          .order('created_at', ascending: false);

      final rows = _toRows(response);
      return rows.map(PaymentProof.fromJson).toList(growable: false);
    } catch (e) {
      _log('❌ Error getting member payment proofs: $e');
      return [];
    }
  }

  Future<List<PaymentProof>> getProofsForHost(
    String hostId, {
    String? status,
  }) async {
    try {
      var query = client
          .from(paymentProofsTable)
          .select(_paymentProofColumns)
          .eq('host_id', hostId);

      if (status != null && status.isNotEmpty && status != 'all') {
        query = query.eq('status', status);
      }

      final response = await query.order('created_at', ascending: false);
      final rows = _toRows(response);
      return rows.map(PaymentProof.fromJson).toList(growable: false);
    } catch (e) {
      _log('❌ Error getting host payment proofs: $e');
      return [];
    }
  }

  Future<bool> hasPendingProof(String paymentId, String memberId) async {
    try {
      final response = await client
          .from(paymentProofsTable)
          .select('id')
          .eq('payment_id', paymentId)
          .eq('member_id', memberId)
          .eq('status', 'pending')
          .limit(1);

      return _toRows(response).isNotEmpty;
    } catch (e) {
      _log('❌ Error checking pending proof: $e');
      return false;
    }
  }

  Future<PaymentProof?> submitPaymentProof(PaymentProof proof) async {
    try {
      final response =
          await client
              .from(paymentProofsTable)
              .insert(proof.toInsertJson())
              .select(_paymentProofColumns)
              .maybeSingle();

      final row = _toRow(response);
      return row != null ? PaymentProof.fromJson(row) : null;
    } catch (e) {
      _log('❌ Error submitting payment proof: $e');
      return null;
    }
  }

  Future<PaymentProof?> getPaymentProofById(String proofId) async {
    try {
      final response =
          await client
              .from(paymentProofsTable)
              .select(_paymentProofColumns)
              .eq('id', proofId)
              .maybeSingle();

      final row = _toRow(response);
      return row != null ? PaymentProof.fromJson(row) : null;
    } catch (e) {
      _log('❌ Error getting payment proof by id: $e');
      return null;
    }
  }

  Future<bool> updatePaymentProofStatus(
    String proofId,
    String status, {
    String? rejectionReason,
    String? reviewedBy,
    String? paymentId,
  }) async {
    try {
      await client
          .from(paymentProofsTable)
          .update({
            'status': status,
            'rejection_reason': rejectionReason,
            'reviewed_by': reviewedBy,
            'reviewed_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', proofId);

      if (paymentId != null && paymentId.isNotEmpty) {
        if (status == 'approved') {
          await client
              .from(paymentsTable)
              .update({
                'is_paid': true,
                'proof_status': 'approved',
                'marked_by': reviewedBy,
                'marked_at': DateTime.now().toIso8601String(),
              })
              .eq('id', paymentId);
        } else if (status == 'pending') {
          await client
              .from(paymentsTable)
              .update({
                'is_paid': false,
                'proof_status': 'pending',
                'marked_by': null,
                'marked_at': null,
              })
              .eq('id', paymentId);
        }
      }

      return true;
    } catch (e) {
      _log('❌ Error updating payment proof status: $e');
      return false;
    }
  }

  Future<bool> deletePaymentProof(
    String proofId, {
    String? paymentId,
    bool resetPaymentAsUnpaid = false,
  }) async {
    try {
      await client.from(paymentProofsTable).delete().eq('id', proofId);

      if (paymentId != null && paymentId.isNotEmpty) {
        final latestRemaining =
            await client
                .from(paymentProofsTable)
                .select('status')
                .eq('payment_id', paymentId)
                .order('created_at', ascending: false)
                .limit(1)
                .maybeSingle();

        final latestRow = _toRow(latestRemaining);
        final latestStatus = (latestRow?['status'] ?? 'none').toString();

        if (latestStatus == 'approved') {
          await client
              .from(paymentsTable)
              .update({'proof_status': 'approved', 'is_paid': true})
              .eq('id', paymentId);
        } else if (latestStatus == 'pending') {
          await client
              .from(paymentsTable)
              .update({
                'proof_status': 'pending',
                'is_paid': false,
                'marked_by': null,
                'marked_at': null,
              })
              .eq('id', paymentId);
        } else if (latestStatus == 'rejected') {
          await client
              .from(paymentsTable)
              .update({
                'proof_status': 'rejected',
                'is_paid': false,
                'marked_by': null,
                'marked_at': null,
              })
              .eq('id', paymentId);
        } else {
          await client
              .from(paymentsTable)
              .update({
                'proof_status': 'none',
                if (resetPaymentAsUnpaid) 'is_paid': false,
                if (resetPaymentAsUnpaid) 'marked_by': null,
                if (resetPaymentAsUnpaid) 'marked_at': null,
              })
              .eq('id', paymentId);
        }
      }

      return true;
    } catch (e) {
      _log('❌ Error deleting payment proof: $e');
      return false;
    }
  }

  Future<int> getPendingProofCountForHostCommittee(
    String hostId,
    String committeeId,
  ) async {
    try {
      final response = await client
          .from(paymentProofsTable)
          .select('id')
          .eq('host_id', hostId)
          .eq('committee_id', committeeId)
          .eq('status', 'pending');

      return _toRows(response).length;
    } catch (e) {
      _log('❌ Error getting pending proof count: $e');
      return 0;
    }
  }
}
