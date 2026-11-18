import 'package:cloud_firestore/cloud_firestore.dart';

enum AppealStatus { pending, approved, rejected }

class CustomerAppeal {
  final String id;
  final String userId;
  final String customerEmail;
  final String customerName;
  final int offenseCount;
  final String reason;
  final AppealStatus status;
  final String? adminNotes;
  final DateTime createdAt;
  final DateTime? reviewedAt;
  final String? reviewedByEmail;

  const CustomerAppeal({
    required this.id,
    required this.userId,
    required this.customerEmail,
    required this.customerName,
    required this.offenseCount,
    required this.reason,
    required this.status,
    this.adminNotes,
    required this.createdAt,
    this.reviewedAt,
    this.reviewedByEmail,
  });

  factory CustomerAppeal.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};

    AppealStatus status = AppealStatus.pending;
    try {
      status = AppealStatus.values.byName(d['status'] ?? 'pending');
    } catch (_) {}

    return CustomerAppeal(
      id: doc.id,
      userId: d['userId']?.toString() ?? '',
      customerEmail: d['customerEmail']?.toString() ?? '',
      customerName: d['customerName']?.toString() ?? '',
      offenseCount: (d['offenseCount'] as num? ?? 0).toInt(),
      reason: d['reason']?.toString() ?? '',
      status: status,
      adminNotes: d['adminNotes']?.toString(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      reviewedAt: (d['reviewedAt'] as Timestamp?)?.toDate(),
      reviewedByEmail: d['reviewedByEmail']?.toString(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'userId': userId,
        'customerEmail': customerEmail,
        'customerName': customerName,
        'offenseCount': offenseCount,
        'reason': reason,
        'status': status.name,
        if (adminNotes != null) 'adminNotes': adminNotes,
        'createdAt': FieldValue.serverTimestamp(),
        if (reviewedAt != null) 'reviewedAt': Timestamp.fromDate(reviewedAt!),
        if (reviewedByEmail != null) 'reviewedByEmail': reviewedByEmail,
      };
}
