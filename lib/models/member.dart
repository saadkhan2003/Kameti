import 'package:hive/hive.dart';

part 'member.g.dart';

@HiveType(typeId: 1)
class Member extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String committeeId;

  @HiveField(2)
  final String memberCode; // Unique code per member (e.g., "ALI-4829")

  @HiveField(3)
  String name;

  @HiveField(4)
  String phone;

  @HiveField(5)
  int payoutOrder; // Assigned turn (1, 2, 3...)

  @HiveField(6)
  bool hasReceivedPayout;

  @HiveField(7)
  DateTime? payoutDate;

  @HiveField(8)
  final DateTime createdAt;

  Member({
    required this.id,
    required this.committeeId,
    required this.memberCode,
    required this.name,
    required this.phone,
    this.payoutOrder = 0,
    this.hasReceivedPayout = false,
    this.payoutDate,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'committee_id': committeeId,
      'member_code': memberCode,
      'name': name,
      'phone': phone,
      'payout_order': payoutOrder,
      'has_received_payout': hasReceivedPayout,
      'payout_date': payoutDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      id: json['id'],
      committeeId: json['committee_id'] ?? json['committeeId'],
      memberCode: json['member_code'] ?? json['memberCode'] ?? '',
      name: json['name'],
      phone: json['phone'],
      payoutOrder: json['payout_order'] ?? json['payoutOrder'] ?? 0,
      hasReceivedPayout: json['has_received_payout'] ?? json['hasReceivedPayout'] ?? false,
      payoutDate: (json['payout_date'] ?? json['payoutDate']) != null
          ? DateTime.tryParse(json['payout_date'] ?? json['payoutDate'])
          : null,
      createdAt: DateTime.parse(json['created_at'] ?? json['createdAt']),
    );
  }

  Member copyWith({
    String? name,
    String? phone,
    int? payoutOrder,
    bool? hasReceivedPayout,
    DateTime? payoutDate,
    bool clearPayoutDate = false,
  }) {
    return Member(
      id: id,
      committeeId: committeeId,
      memberCode: memberCode,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      payoutOrder: payoutOrder ?? this.payoutOrder,
      hasReceivedPayout: hasReceivedPayout ?? this.hasReceivedPayout,
      payoutDate: clearPayoutDate ? null : (payoutDate ?? this.payoutDate),
      createdAt: createdAt,
    );
  }
}
