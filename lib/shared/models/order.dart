import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

enum OrderStatus { pending, staging, ready, collected, cancelled, refunded, refundRequested, refundRejected }

class CartItem {
  final String productId;
  final String name;
  final double price;
  final int    qty;
  final bool   isPerishable;
  final String? variantId;
  final String? variantName;

  const CartItem({
    required this.productId,
    required this.name,
    required this.price,
    required this.qty,
    this.isPerishable = false,
    this.variantId,
    this.variantName,
  });

  factory CartItem.fromMap(dynamic m) {
    if (m is! Map) {
      return const CartItem(productId: '', name: 'Unknown Item', price: 0, qty: 0);
    }
    return CartItem(
      productId:    m['productId'] ?? '',
      name:         m['name'] ?? '',
      price:        (m['price'] as num? ?? 0).toDouble(),
      qty:          m['qty'] ?? 1,
      isPerishable: m['isPerishable'] ?? false,
      variantId:    m['variantId']?.toString(),
      variantName:  m['variantName']?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
    'productId':    productId,
    'name':         name,
    'price':        price,
    'qty':          qty,
    'isPerishable': isPerishable,
    if (variantId != null) 'variantId': variantId,
    if (variantName != null) 'variantName': variantName,
  };

  CartItem copyWith({int? qty, double? price, String? variantId, String? variantName}) =>
      CartItem(
        productId: productId, 
        name: name, 
        price: price ?? this.price, 
        qty: qty ?? this.qty, 
        isPerishable: isPerishable,
        variantId: variantId ?? this.variantId,
        variantName: variantName ?? this.variantName,
      );
}

class PreOrder {
  final String         id;
  final String         orderId;
  final String         customerName;
  final String         customerEmail;
  final String         customerPhone;
  final List<CartItem> items;
  final double         tax;
  final double         total;
  final OrderStatus    status;
  final String         location;
  final String         pickupTime;
  final DateTime       createdAt;
  final DateTime?      expiresAt;
  final String?        rejectionReason;
  final bool           isSeniorPWD;

  const PreOrder({
    required this.id,
    required this.orderId,
    required this.customerName,
    required this.customerEmail,
    required this.customerPhone,
    required this.items,
    this.tax = 0,
    required this.total,
    required this.status,
    this.location   = '',
    this.pickupTime = '',
    required this.createdAt,
    this.expiresAt,
    this.rejectionReason,
    this.isSeniorPWD = false,
  });

  factory PreOrder.fromFirestore(DocumentSnapshot doc) {
    try {
      final d = doc.data() as Map<String, dynamic>? ?? {};
      return PreOrder(
        id:            doc.id,
        orderId:       d['orderId']?.toString() ?? 'GDC-????',
        customerName:  d['customerName']?.toString() ?? 'Unknown Customer',
        customerEmail: d['customerEmail']?.toString() ?? '',
        customerPhone: d['customerPhone']?.toString() ?? '',
        items:         (d['items'] as List? ?? []).map((e) => CartItem.fromMap(e)).toList(),
        tax:           (d['tax'] as num? ?? 0).toDouble(),
        total:         (d['total'] as num? ?? 0).toDouble(),
        status: OrderStatus.values.firstWhere(
          (e) => e.name == (d['status'] ?? 'pending'),
          orElse: () => OrderStatus.pending,
        ),
        location:      d['location']?.toString() ?? '',
        pickupTime:    d['pickupTime']?.toString() ?? '',
        createdAt:     (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        expiresAt:     (d['expiresAt'] as Timestamp?)?.toDate(),
        rejectionReason: d['rejectionReason']?.toString(),
        isSeniorPWD:   d['isSeniorPWD'] ?? false,
      );
    } catch (e) {
      debugPrint('Error parsing PreOrder ${doc.id}: $e');
      return PreOrder(
        id: doc.id, 
        orderId: 'ERROR', 
        customerName: 'Error Loading', 
        customerEmail: '', 
        customerPhone: '',
        items: [], 
        total: 0, 
        status: OrderStatus.cancelled, 
        createdAt: DateTime.now()
      );
    }
  }

  Map<String, dynamic> toFirestore() => {
    'orderId':       orderId,
    'customerName':  customerName,
    'customerEmail': customerEmail,
    'customerPhone': customerPhone,
    'items':         items.map((i) => i.toMap()).toList(),
    'tax':           tax,
    'total':         total,
    'status':        status.name,
    'location':      location,
    'pickupTime':    pickupTime,
    'createdAt':     FieldValue.serverTimestamp(),
    'expiresAt':     expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
    'isSeniorPWD':   isSeniorPWD,
    if (rejectionReason != null) 'rejectionReason': rejectionReason,
  };

  bool get isExpired {
    if (expiresAt == null) return false;
    final isActive = status == OrderStatus.pending || 
                     status == OrderStatus.staging || 
                     status == OrderStatus.ready;
    return isActive && DateTime.now().isAfter(expiresAt!);
  }

  PreOrder copyWith({OrderStatus? status}) => PreOrder(
    id: id, orderId: orderId,
    customerName: customerName, customerEmail: customerEmail,
    customerPhone: customerPhone,
    items: items, 
    tax: tax, total: total,
    status: status ?? this.status,
    location: location,
    pickupTime: pickupTime, createdAt: createdAt,
    expiresAt: expiresAt,
    rejectionReason: rejectionReason,
    isSeniorPWD: isSeniorPWD,
  );
}
