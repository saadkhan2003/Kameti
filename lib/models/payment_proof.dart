class PaymentProof {
  final String id;
  final String paymentId;
  final String committeeId;
  final String memberId;
  final String hostId;
  final String cloudinaryUrl;
  final String cloudinaryPublicId;
  final String status;
  final String? rejectionReason;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PaymentProof({
    required this.id,
    required this.paymentId,
    required this.committeeId,
    required this.memberId,
    required this.hostId,
    required this.cloudinaryUrl,
    required this.cloudinaryPublicId,
    required this.status,
    this.rejectionReason,
    this.reviewedBy,
    this.reviewedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  factory PaymentProof.fromJson(Map<String, dynamic> json) {
    return PaymentProof(
      id: json['id'] as String,
      paymentId: json['payment_id'] as String,
      committeeId: json['committee_id'] as String,
      memberId: json['member_id'] as String,
      hostId: json['host_id'] as String,
      cloudinaryUrl: json['cloudinary_url'] as String,
      cloudinaryPublicId: json['cloudinary_public_id'] as String,
      status: (json['status'] as String?) ?? 'pending',
      rejectionReason: json['rejection_reason'] as String?,
      reviewedBy: json['reviewed_by'] as String?,
      reviewedAt:
          json['reviewed_at'] != null
              ? DateTime.tryParse(json['reviewed_at'].toString())
              : null,
      createdAt: DateTime.parse(json['created_at'].toString()),
      updatedAt: DateTime.parse(json['updated_at'].toString()),
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'payment_id': paymentId,
      'committee_id': committeeId,
      'member_id': memberId,
      'host_id': hostId,
      'cloudinary_url': cloudinaryUrl,
      'cloudinary_public_id': cloudinaryPublicId,
      'status': status,
      'rejection_reason': rejectionReason,
      'reviewed_by': reviewedBy,
      'reviewed_at': reviewedAt?.toIso8601String(),
    };
  }

  PaymentProof copyWith({
    String? status,
    String? rejectionReason,
    String? reviewedBy,
    DateTime? reviewedAt,
  }) {
    return PaymentProof(
      id: id,
      paymentId: paymentId,
      committeeId: committeeId,
      memberId: memberId,
      hostId: hostId,
      cloudinaryUrl: cloudinaryUrl,
      cloudinaryPublicId: cloudinaryPublicId,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
