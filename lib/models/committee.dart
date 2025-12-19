import 'package:hive/hive.dart';

part 'committee.g.dart';

@HiveType(typeId: 0)
class Committee extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String code; // 6-digit unique code for sharing

  @HiveField(2)
  String name;

  @HiveField(3)
  final String hostId; // Firebase Auth UID

  @HiveField(4)
  double contributionAmount;

  @HiveField(5)
  String frequency; // 'daily', 'weekly', 'monthly'

  @HiveField(6)
  DateTime startDate;

  @HiveField(7)
  int totalMembers;

  @HiveField(8)
  final DateTime createdAt;

  @HiveField(9)
  bool isActive;

  @HiveField(10)
  final int paymentIntervalDays; // For custom payout cycles

  @HiveField(11)
  bool isArchived; // For archiving completed committees

  @HiveField(12)
  DateTime? archivedAt; // When the committee was archived

  Committee({
    required this.id,
    required this.code,
    required this.name,
    required this.hostId,
    required this.contributionAmount,
    required this.frequency,
    required this.startDate,
    required this.totalMembers,
    required this.createdAt,
    this.isActive = true,
    this.paymentIntervalDays = 30, // Default to monthly
    this.isArchived = false,
    this.archivedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'hostId': hostId,
      'contributionAmount': contributionAmount,
      'frequency': frequency,
      'startDate': startDate.toIso8601String(),
      'totalMembers': totalMembers,
      'createdAt': createdAt.toIso8601String(),
      'isActive': isActive,
      'paymentIntervalDays': paymentIntervalDays,
      'isArchived': isArchived,
      'archivedAt': archivedAt?.toIso8601String(),
    };
  }

  factory Committee.fromJson(Map<String, dynamic> json) {
    return Committee(
      id: json['id'],
      code: json['code'],
      name: json['name'],
      hostId: json['hostId'],
      contributionAmount: (json['contributionAmount'] as num).toDouble(),
      frequency: json['frequency'],
      startDate: DateTime.parse(json['startDate']),
      totalMembers: json['totalMembers'],
      createdAt: DateTime.parse(json['createdAt']),
      isActive: json['isActive'] ?? true,
      paymentIntervalDays: json['paymentIntervalDays'] ?? 30,
      isArchived: json['isArchived'] ?? false,
      archivedAt:
          json['archivedAt'] != null
              ? DateTime.parse(json['archivedAt'])
              : null,
    );
  }

  Committee copyWith({
    String? name,
    double? contributionAmount,
    String? frequency,
    DateTime? startDate,
    int? totalMembers,
    bool? isActive,
    int? paymentIntervalDays,
    bool? isArchived,
    DateTime? archivedAt,
  }) {
    return Committee(
      id: id,
      code: code,
      name: name ?? this.name,
      hostId: hostId,
      contributionAmount: contributionAmount ?? this.contributionAmount,
      frequency: frequency ?? this.frequency,
      startDate: startDate ?? this.startDate,
      totalMembers: totalMembers ?? this.totalMembers,
      createdAt: createdAt,
      isActive: isActive ?? this.isActive,
      paymentIntervalDays: paymentIntervalDays ?? this.paymentIntervalDays,
      isArchived: isArchived ?? this.isArchived,
      archivedAt: archivedAt ?? this.archivedAt,
    );
  }
}
