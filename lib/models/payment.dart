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
      'member_id': memberId,
      'committee_id': committeeId,
      'date': date.toIso8601String(),
      'is_paid': isPaid,
      'marked_by': markedBy,
      'marked_at': markedAt?.toIso8601String(),
    };
  }

  factory Payment.fromJson(Map<String, dynamic> json) {
    final rawDate = json['date'];
    final parsedDate =
        rawDate is String && rawDate.isNotEmpty
            ? DateTime.tryParse(rawDate)
            : null;

    return Payment(
      id: (json['id'] ?? '').toString(),
      memberId: (json['member_id'] ?? json['memberId'] ?? '').toString(),
      committeeId:
          (json['committee_id'] ?? json['committeeId'] ?? '').toString(),
      date: parsedDate ?? DateTime.fromMillisecondsSinceEpoch(0),
      isPaid: json['is_paid'] ?? json['isPaid'] ?? false,
      markedBy: (json['marked_by'] ?? json['markedBy'] ?? '').toString(),
      markedAt:
          (json['marked_at'] ?? json['markedAt']) != null
              ? DateTime.tryParse(
                (json['marked_at'] ?? json['markedAt']).toString(),
              )
              : null,
    );
  }

  Payment copyWith({bool? isPaid, DateTime? markedAt}) {
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
