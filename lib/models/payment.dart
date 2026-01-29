import 'package:hive/hive.dart';

part 'payment.g.dart';

@HiveType(typeId: 2)
class Payment extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String memberId;

  @HiveField(2)
  final String committeeId;

  @HiveField(3)
  final DateTime date;

  @HiveField(4)
  bool isPaid;

  @HiveField(5)
  final String markedBy; // Host ID who marked this payment

  @HiveField(6)
  DateTime? markedAt;

  Payment({
    required this.id,
    required this.memberId,
    required this.committeeId,
    required this.date,
    this.isPaid = false,
    required this.markedBy,
    this.markedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'memberId': memberId,
      'committeeId': committeeId,
      'date': date.toIso8601String(),
      'isPaid': isPaid,
      'markedBy': markedBy,
      'markedAt': markedAt?.toIso8601String(),
    };
  }

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: json['id'],
      memberId: json['memberId'],
      committeeId: json['committeeId'],
      date: DateTime.parse(json['date']),
      isPaid: json['isPaid'] ?? false,
      markedBy: json['markedBy'],
      markedAt:
          json['markedAt'] != null ? DateTime.parse(json['markedAt']) : null,
    );
  }

  Payment copyWith({
    bool? isPaid,
    DateTime? markedAt,
  }) {
    return Payment(
      id: id,
      memberId: memberId,
      committeeId: committeeId,
      date: date,
      isPaid: isPaid ?? this.isPaid,
      markedBy: markedBy,
      markedAt: markedAt ?? this.markedAt,
    );
  }
}
