import 'package:cloud_firestore/cloud_firestore.dart';
import 'order.dart';

enum RefundStatus { pending, approved, rejected }
enum RefundCondition { good, expired, damaged }

class RefundRequest {
  final String id;
  final String transactionId;
  final String customerEmail;
  final String customerName;
  final List<CartItem> items;
  final double total;
  final String reason;
  final String? rejectionReason;
  final String? adminNotes;
  final RefundStatus status;
  final RefundCondition? condition; 
  final DateTime createdAt;
  final String? processedByEmail;

  const RefundRequest({
    required this.id,
    required this.transactionId,
    required this.customerEmail,
    required this.customerName,
    required this.items,
    required this.total,
    required this.reason,
    this.rejectionReason,
    this.adminNotes,
    required this.status,
    this.condition,
    required this.createdAt,
    this.processedByEmail,
  });

  factory RefundRequest.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    
    RefundStatus status = RefundStatus.pending;
    try {
      status = RefundStatus.values.byName(d['status'] ?? 'pending');
    } catch (_) {}

    RefundCondition? condition;
    if (d['condition'] != null) {
      try {
        condition = RefundCondition.values.byName(d['condition']);
      } catch (_) {}
    }

    final txId = d['transactionId']?.toString() ?? d['orderId']?.toString() ?? '';

    return RefundRequest(
      id: doc.id,
      transactionId: txId,
      customerEmail: d['customerEmail']?.toString() ?? '',
      customerName: d['customerName']?.toString() ?? '',
      items: (d['items'] as List? ?? []).map((e) => CartItem.fromMap(e)).toList(),
      total: (d['total'] as num? ?? 0).toDouble(),
      reason: d['reason']?.toString() ?? '',
      rejectionReason: d['rejectionReason']?.toString(),
      adminNotes: d['adminNotes']?.toString(),
      status: status,
      condition: condition,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      processedByEmail: d['processedByEmail']?.toString(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'orderId': transactionId,
    'transactionId': transactionId,
    'customerEmail': customerEmail,
    'customerName': customerName,
    'items': items.map((i) => i.toMap()).toList(),
    'total': total,
    'reason': reason,
    if (rejectionReason != null) 'rejectionReason': rejectionReason,
    if (adminNotes != null) 'adminNotes': adminNotes,
    'status': status.name,
    if (condition != null) 'condition': condition!.name,
    'createdAt': FieldValue.serverTimestamp(),
    if (processedByEmail != null) 'processedByEmail': processedByEmail,
  };
}
