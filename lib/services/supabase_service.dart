import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/committee.dart';
import '../models/member.dart';
import '../models/payment.dart';

/// Supabase service for database operations
/// Replaces Firebase Firestore with Supabase PostgreSQL
class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  SupabaseClient get client => Supabase.instance.client;

  // Table names
  static const String committeesTable = 'committees';
  static const String membersTable = 'members';
  static const String paymentsTable = 'payments';

  // ============================================
  // COMMITTEES
  // ============================================

  /// Get all committees for a host
  Future<List<Committee>> getCommittees(String hostId) async {
    try {
      print('🔍 Supabase: Fetching committees for host $hostId');
      final response = await client
          .from(committeesTable)
          .select()
          .eq('host_id', hostId);

      print('🔍 Supabase: Raw response length: ${(response as List).length}');
      if ((response as List).isNotEmpty) {
        print('🔍 Supabase: First item keys: ${(response as List).first.keys.toList()}');
      }

      final committees = (response as List).map((json) {
         try {
           return Committee.fromJson(json);
         } catch (e) {
           print('❌ Error parsing committee JSON: $e');
           print('   JSON: $json');
           rethrow;
         }
      }).toList();
      
      print('✅ Supabase: Parsed ${committees.length} committees');
      return committees;
    } catch (e) {
      print('❌ Error getting committees: $e');
      return [];
    }
  }

  /// Get a single committee by ID
  Future<Committee?> getCommittee(String committeeId) async {
    try {
      final response = await client
          .from(committeesTable)
          .select()
          .eq('id', committeeId)
          .maybeSingle();

      return response != null ? Committee.fromJson(response) : null;
    } catch (e) {
      print('Error getting committee: $e');
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
          .select()
          .eq('committee_id', committeeId);

      return (response as List).map((json) => Member.fromJson(json)).toList();
    } catch (e) {
      print('Error getting members: $e');
      return [];
    }
  }

  /// Create or update a member
  Future<void> upsertMember(Member member) async {
    await client.from(membersTable).upsert(member.toJson());
  }

  /// Batch upsert members
  Future<void> upsertMembers(List<Member> members) async {
    if (members.isEmpty) return;
    await client.from(membersTable).upsert(
      members.map((m) => m.toJson()).toList(),
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
          .select()
          .eq('committee_id', committeeId);

      return (response as List).map((json) => Payment.fromJson(json)).toList();
    } catch (e) {
      print('Error getting payments: $e');
      return [];
    }
  }

  /// Get a single payment
  Future<Payment?> getPayment(String paymentId) async {
    try {
      final response = await client
          .from(paymentsTable)
          .select()
          .eq('id', paymentId)
          .maybeSingle();

      return response != null ? Payment.fromJson(response) : null;
    } catch (e) {
      print('Error getting payment: $e');
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
    
    // Supabase allows up to 1000 rows per batch
    const batchSize = 500;
    for (int i = 0; i < payments.length; i += batchSize) {
      final batch = payments.skip(i).take(batchSize).toList();
      await client.from(paymentsTable).upsert(
        batch.map((p) => p.toJson()).toList(),
      );
      print('✅ Synced batch ${i ~/ batchSize + 1}: ${batch.length} payments');
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
}
