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

  @HiveField(13)
  int totalCycles; // Total number of cycles (rounds) for the committee

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
    this.totalCycles = 0, // Default to 0
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'host_id': hostId,
      'contribution_amount': contributionAmount,
      'frequency': frequency,
      'start_date': startDate.toIso8601String(),
      'total_members': totalMembers,
      'created_at': createdAt.toIso8601String(),
      'is_active': isActive,
      'payment_interval_days': paymentIntervalDays,
      'is_archived': isArchived,
      'archived_at': archivedAt?.toIso8601String(),
      'total_cycles': totalCycles,
    };
  }

  factory Committee.fromJson(Map<String, dynamic> json) {
    return Committee(
      id: json['id'],
      code: json['code'] ?? '', // Handle missing code if any
      name: json['name'],
      // Support both snake_case (Supabase) and camelCase (Legacy/Internal)
      hostId: json['host_id'] ?? json['hostId'],
      contributionAmount: (json['contribution_amount'] ?? json['contributionAmount'] as num).toDouble(),
      frequency: json['frequency'],
      startDate: DateTime.parse(json['start_date'] ?? json['startDate']),
      totalMembers: json['total_members'] ?? json['totalMembers'],
      createdAt: DateTime.parse(json['created_at'] ?? json['createdAt']),
      isActive: json['is_active'] ?? json['isActive'] ?? true,
      paymentIntervalDays: json['payment_interval_days'] ?? json['paymentIntervalDays'] ?? 30,
      isArchived: json['is_archived'] ?? json['isArchived'] ?? false,
      archivedAt: (json['archived_at'] ?? json['archivedAt']) != null
          ? DateTime.tryParse(json['archived_at'] ?? json['archivedAt'])
          : null,
      totalCycles: json['total_cycles'] ?? json['totalCycles'] ?? 0,
    );
  }

  Committee copyWith({
    String? name,
    String? hostId,
    double? contributionAmount,
    String? frequency,
    DateTime? startDate,
    int? totalMembers,
    bool? isActive,
    int? paymentIntervalDays,
    bool? isArchived,
    DateTime? archivedAt,
    int? totalCycles,
  }) {
    return Committee(
      id: id,
      code: code,
      name: name ?? this.name,
      hostId: hostId ?? this.hostId,
      contributionAmount: contributionAmount ?? this.contributionAmount,
      frequency: frequency ?? this.frequency,
      startDate: startDate ?? this.startDate,
      totalMembers: totalMembers ?? this.totalMembers,
      createdAt: createdAt,
      isActive: isActive ?? this.isActive,
      paymentIntervalDays: paymentIntervalDays ?? this.paymentIntervalDays,
      isArchived: isArchived ?? this.isArchived,
      archivedAt: archivedAt ?? this.archivedAt,
      totalCycles: totalCycles ?? this.totalCycles,
    );
  }
}
