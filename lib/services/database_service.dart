import 'package:hive_flutter/hive_flutter.dart';
import '../models/committee.dart';
import '../models/member.dart';
import '../models/payment.dart';

class DatabaseService {
  static const String committeesBox = 'committees';
  static const String membersBox = 'members';
  static const String paymentsBox = 'payments';
  static const String joinedCommitteesBox = 'joined_committees';
  static const String committeeUIBox = 'committee_ui';

  static Future<void> initialize() async {
    await Hive.initFlutter();

    // Register adapters
    Hive.registerAdapter(CommitteeAdapter());
    Hive.registerAdapter(MemberAdapter());
    Hive.registerAdapter(PaymentAdapter());

    // Open boxes
    await Hive.openBox<Committee>(committeesBox);
    await Hive.openBox<Member>(membersBox);
    await Hive.openBox<Payment>(paymentsBox);
    await Hive.openBox<Map>(joinedCommitteesBox);
    await Hive.openBox<Map>(committeeUIBox);
  }

  // ============ COMMITTEE OPERATIONS ============

  Box<Committee> get _committeeBox => Hive.box<Committee>(committeesBox);

  Future<void> saveCommittee(Committee committee) async {
    await _committeeBox.put(committee.id, committee);
  }

  List<Committee> getHostedCommittees(String hostId) {
    return _committeeBox.values.where((c) => c.hostId == hostId).toList();
  }

  Committee? getCommitteeById(String id) {
    return _committeeBox.get(id);
  }

  Committee? getCommitteeByCode(String code) {
    try {
      return _committeeBox.values.firstWhere((c) => c.code == code);
    } catch (e) {
      return null;
    }
  }

  Future<void> deleteCommittee(String id) async {
    await _committeeBox.delete(id);
    // Also delete related members and payments
    final members = getMembersByCommittee(id);
    for (final member in members) {
      await deleteMember(member.id);
    }
  }

  // ============ MEMBER OPERATIONS ============

  Box<Member> get _memberBox => Hive.box<Member>(membersBox);

  Future<void> saveMember(Member member) async {
    await _memberBox.put(member.id, member);
  }

  List<Member> getMembersByCommittee(String committeeId) {
    return _memberBox.values
        .where((m) => m.committeeId == committeeId)
        .toList();
  }

  Member? getMemberById(String id) {
    return _memberBox.get(id);
  }

  Member? getMemberByCode(String committeeId, String memberCode) {
    try {
      return _memberBox.values.firstWhere(
        (m) => m.committeeId == committeeId && m.memberCode == memberCode,
      );
    } catch (e) {
      return null;
    }
  }

  Future<void> deleteMember(String id) async {
    // Delete related payments
    final payments = getPaymentsByMember(id);
    for (final payment in payments) {
      await deletePayment(payment.id);
    }
    await _memberBox.delete(id);
  }

  Future<void> updateMemberPayoutOrder(String memberId, int order) async {
    final member = getMemberById(memberId);
    if (member != null) {
      await saveMember(member.copyWith(payoutOrder: order));
    }
  }

  // ============ PAYMENT OPERATIONS ============

  Box<Payment> get _paymentBox => Hive.box<Payment>(paymentsBox);

  Future<void> savePayment(Payment payment) async {
    await _paymentBox.put(payment.id, payment);
  }

  List<Payment> getPaymentsByCommittee(String committeeId) {
    return _paymentBox.values
        .where((p) => p.committeeId == committeeId)
        .toList();
  }

  List<Payment> getPaymentsByMember(String memberId) {
    return _paymentBox.values.where((p) => p.memberId == memberId).toList();
  }

  Payment? getPayment(String memberId, DateTime date) {
    try {
      return _paymentBox.values.firstWhere(
        (p) =>
            p.memberId == memberId &&
            p.date.year == date.year &&
            p.date.month == date.month &&
            p.date.day == date.day,
      );
    } catch (e) {
      return null;
    }
  }

  Future<void> deletePayment(String id) async {
    await _paymentBox.delete(id);
  }

  Future<void> togglePayment(
    String memberId,
    String committeeId,
    DateTime date,
    String hostId,
  ) async {
    final existingPayment = getPayment(memberId, date);
    if (existingPayment != null) {
      await savePayment(
        existingPayment.copyWith(
          isPaid: !existingPayment.isPaid,
          markedAt: DateTime.now(),
        ),
      );
    } else {
      final payment = Payment(
        id: '${memberId}_${date.toIso8601String()}',
        memberId: memberId,
        committeeId: committeeId,
        date: date,
        isPaid: true,
        markedBy: hostId,
        markedAt: DateTime.now(),
      );
      await savePayment(payment);
    }
  }

  // ============ JOINED COMMITTEES ============

  Box<Map> get _joinedBox => Hive.box<Map>(joinedCommitteesBox);

  Future<void> saveJoinedCommittee(
    String committeeCode,
    String memberCode,
  ) async {
    await _joinedBox.put(committeeCode, {
      'committeeCode': committeeCode,
      'memberCode': memberCode,
      'joinedAt': DateTime.now().toIso8601String(),
    });
  }

  List<Map> getJoinedCommittees() {
    return _joinedBox.values.toList();
  }

  Future<void> removeJoinedCommittee(String committeeCode) async {
    await _joinedBox.delete(committeeCode);
  }

  // ============ UI / PERSISTED SETTINGS ============

  Box<Map> get _uiBox => Hive.box<Map>(committeeUIBox);

  void setSelectedCycle(String committeeId, int cycle) {
    final existing = _uiBox.get(committeeId) ?? {};
    existing['selectedCycle'] = cycle;
    _uiBox.put(committeeId, existing);
  }

  int getSelectedCycle(String committeeId) {
    final val = _uiBox.get(committeeId);
    if (val == null) return 1;
    return (val['selectedCycle'] ?? 1) as int;
  }

  // ============ CLEAR ALL DATA ============

  /// Clears all local data from Hive boxes.
  /// Called on logout to ensure user data separation.
  static Future<void> clearAllData() async {
    await Hive.box<Committee>(committeesBox).clear();
    await Hive.box<Member>(membersBox).clear();
    await Hive.box<Payment>(paymentsBox).clear();
    await Hive.box<Map>(joinedCommitteesBox).clear();
    await Hive.box<Map>(committeeUIBox).clear();
  }
}
