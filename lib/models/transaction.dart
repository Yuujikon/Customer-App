import 'package:cloud_firestore/cloud_firestore.dart';
import 'order.dart';

class StoreTransaction {
  final String         id;
  final List<CartItem> items;
  final double         total;
  final double         cash;
  final double         change;
  final bool           isRefunded;
  final DateTime       createdAt;

  const StoreTransaction({
    required this.id,
    required this.items,
    required this.total,
    required this.cash,
    required this.change,
    this.isRefunded = false,
    required this.createdAt,
  });

  factory StoreTransaction.fromFirestore(DocumentSnapshot doc) {
    try {
      final d = doc.data() as Map<String, dynamic>? ?? {};
      return StoreTransaction(
        id:        doc.id,
        items:     (d['items'] as List? ?? []).map((e) {
          if (e is Map) return CartItem.fromMap(Map<String, dynamic>.from(e));
          return const CartItem(productId: 'err', name: 'Invalid Item', price: 0, qty: 0);
        }).toList(),
        total:     (d['total'] as num? ?? 0).toDouble(),
        cash:      (d['cash'] as num? ?? 0).toDouble(),
        change:    (d['change'] as num? ?? 0).toDouble(),
        isRefunded: d['isRefunded'] ?? false,
        createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
    } catch (e) {
      print('Error parsing transaction ${doc.id}: $e');
      return StoreTransaction(
        id: doc.id, items: [], total: 0, cash: 0, change: 0,
        createdAt: DateTime.now(),
      );
    }
  }

  Map<String, dynamic> toFirestore() => {
    'items':     items.map((i) => i.toMap()).toList(),
    'total':     total,
    'cash':      cash,
    'change':    change,
    'isRefunded': isRefunded,
    'createdAt': FieldValue.serverTimestamp(),
  };

  StoreTransaction copyWith({bool? isRefunded}) => StoreTransaction(
    id: id,
    items: items,
    total: total,
    cash: cash,
    change: change,
    isRefunded: isRefunded ?? this.isRefunded,
    createdAt: createdAt,
  );
}