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
      'committeeId': committeeId,
      'memberCode': memberCode,
      'name': name,
      'phone': phone,
      'payoutOrder': payoutOrder,
      'hasReceivedPayout': hasReceivedPayout,
      'payoutDate': payoutDate?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      id: json['id'],
      committeeId: json['committeeId'],
      memberCode: json['memberCode'],
      name: json['name'],
      phone: json['phone'],
      payoutOrder: json['payoutOrder'] ?? 0,
      hasReceivedPayout: json['hasReceivedPayout'] ?? false,
      payoutDate: json['payoutDate'] != null
          ? DateTime.parse(json['payoutDate'])
          : null,
      createdAt: DateTime.parse(json['createdAt']),
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
