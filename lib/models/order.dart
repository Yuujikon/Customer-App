import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

enum OrderStatus { pending, staging, ready, collected, cancelled, refunded, refund_requested, refund_rejected }

class CartItem {
  final String productId;
  final String name;
  final double price;
  final int    qty;
  final bool   isPerishable;

  const CartItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.qty,
    this.isPerishable = false,
  });

  factory CartItem.fromMap(Map<String, dynamic> m) => CartItem(
    productId:    m['productId'] ?? '',
    name:         m['name'] ?? '',
    price:        (m['price'] as num).toDouble(),
    qty:          m['qty'] ?? 1,
    isPerishable: m['isPerishable'] ?? false,
  );

  Map<String, dynamic> toMap() => {
    'productId':    productId,
    'name':         name,
    'price':        price,
    'qty':          qty,
    'isPerishable': isPerishable,
  };

  CartItem copyWith({int? qty}) =>
      CartItem(productId: productId, name: name, price: price, qty: qty ?? this.qty, isPerishable: isPerishable);
}

class PreOrder {
  final String         id;
  final String         orderId;
  final String         customerName;
  final String         customerEmail;
  final List<CartItem> items;
  final double         total;
  final OrderStatus    status;
  final String         notes;
  final String         location;
  final String         pickupTime;
  final DateTime       createdAt;
  final DateTime?      expiresAt;
  final String?        rejectionReason;

  const PreOrder({
    required this.id,
    required this.orderId,
    required this.customerName,
    required this.customerEmail,
    required this.items,
    required this.total,
    required this.status,
    this.notes      = '',
    this.location   = '',
    this.pickupTime = '',
    required this.createdAt,
    this.expiresAt,
    this.rejectionReason,
  });

  factory PreOrder.fromFirestore(DocumentSnapshot doc) {
    try {
      final d = doc.data() as Map<String, dynamic>? ?? {};
      return PreOrder(
        id:            doc.id,
        orderId:       d['orderId'] ?? '',
        customerName:  d['customerName'] ?? '',
        customerEmail: d['customerEmail'] ?? '',
        items:         (d['items'] as List? ?? []).map((e) {
          if (e is Map) return CartItem.fromMap(Map<String, dynamic>.from(e));
          return const CartItem(productId: 'err', name: 'Invalid Item', price: 0, qty: 0);
        }).toList(),
        total:         (d['total'] as num? ?? 0).toDouble(),
        status: OrderStatus.values.firstWhere(
          (e) => e.name == (d['status'] ?? 'pending'),
          orElse: () => OrderStatus.pending,
        ),
        notes:         d['notes'] ?? '',
        location:      d['location'] ?? '',
        pickupTime:    d['pickupTime'] ?? '',
        createdAt:     (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        expiresAt:     (d['expiresAt'] as Timestamp?)?.toDate(),
        rejectionReason: d['rejectionReason'],
      );
    } catch (e) {
      debugPrint('Error parsing order ${doc.id}: $e');
      // Return a dummy order so the whole screen doesn't crash
      return PreOrder(
        id: doc.id, orderId: 'ERROR', customerName: 'Error Loading',
        customerEmail: '', items: [], total: 0, status: OrderStatus.cancelled,
        createdAt: DateTime.now(),
      );
    }
  }

  Map<String, dynamic> toFirestore() => {
    'orderId':       orderId,
    'customerName':  customerName,
    'customerEmail': customerEmail,
    'items':         items.map((i) => i.toMap()).toList(),
    'total':         total,
    'status':        status.name,
    'notes':         notes,
    'location':      location,
    'pickupTime':    pickupTime,
    'createdAt':     FieldValue.serverTimestamp(),
    'expiresAt':     expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
    if (rejectionReason != null) 'rejectionReason': rejectionReason,
  };

  PreOrder copyWith({OrderStatus? status}) => PreOrder(
    id: id, orderId: orderId,
    customerName: customerName, customerEmail: customerEmail,
    items: items, total: total,
    status: status ?? this.status,
    notes: notes, location: location,
    pickupTime: pickupTime, createdAt: createdAt,
    expiresAt: expiresAt,
    rejectionReason: rejectionReason,
  );
}
