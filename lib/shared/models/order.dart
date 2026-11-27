import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../services/time_service.dart';

enum OrderStatus {
  pending,
  staging,
  ready,
  collected,
  cancelled,
  refunded,
  refundRequested,
  refundRejected
}

class CartItem {
  final String productId;
  final String name;
  final String barcode;
  final double price;
  final int qty;
  final int returnedQty;
  final bool isPerishable;
  final String? variantId;
  final String? variantName;
  final List<Map<String, dynamic>> batchAllocations;

  const CartItem({
    required this.productId,
    required this.name,
    this.barcode = '',
    required this.price,
    required this.qty,
    this.returnedQty = 0,
    this.isPerishable = false,
    this.variantId,
    this.variantName,
    this.batchAllocations = const [],
  });

  factory CartItem.fromMap(dynamic m) {
    if (m is! Map) {
      return const CartItem(
          productId: '', name: 'Unknown Item', price: 0, qty: 0);
    }
    final rawAlloc = m['batchAllocations'] is List
        ? m['batchAllocations'] as List
        : (m['depletedBatches'] is List ? m['depletedBatches'] as List : null);
    final List<Map<String, dynamic>> allocations = rawAlloc != null
        ? rawAlloc
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : const [];

    return CartItem(
      productId: m['productId'] ?? '',
      name: m['name'] ?? '',
      barcode: m['barcode']?.toString() ?? '',
      price: (m['price'] as num? ?? 0).toDouble(),
      qty: m['qty'] ?? 1,
      returnedQty: (m['returnedQty'] as num? ?? 0).toInt(),
      isPerishable: m['isPerishable'] ?? false,
      variantId: m['variantId']?.toString(),
      variantName: m['variantName']?.toString(),
      batchAllocations: allocations,
    );
  }

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'name': name,
        'barcode': barcode,
        'price': price,
        'qty': qty,
        'returnedQty': returnedQty,
        'isPerishable': isPerishable,
        if (variantId != null) 'variantId': variantId,
        if (variantName != null) 'variantName': variantName,
        if (batchAllocations.isNotEmpty) 'batchAllocations': batchAllocations,
      };

  CartItem copyWith({
    int? qty,
    int? returnedQty,
    double? price,
    String? barcode,
    String? variantId,
    String? variantName,
    List<Map<String, dynamic>>? batchAllocations,
  }) =>
      CartItem(
        productId: productId,
        name: name,
        barcode: barcode ?? this.barcode,
        price: price ?? this.price,
        qty: qty ?? this.qty,
        returnedQty: returnedQty ?? this.returnedQty,
        isPerishable: isPerishable,
        variantId: variantId ?? this.variantId,
        variantName: variantName ?? this.variantName,
        batchAllocations: batchAllocations ?? this.batchAllocations,
      );
}

class PreOrder {
  final String id;
  final String orderId; // 6-character alphanumeric Order ID (e.g., A8K2M9)
  final String? customerId;
  final String customerName;
  final String customerEmail;
  final String customerPhone;
  final List<CartItem> items;
  final double subtotal;
  final double tax;
  final double total;
  final OrderStatus status;
  final String paymentMethod; // 'GCash', 'Maya'
  final String? paymentReference; // Optional GCash/Maya Ref #
  final String location;
  final String pickupTime;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final String? rejectionReason;
  final String? notes;
  final bool isSeniorPWD;
  final bool isExtended;

  const PreOrder({
    required this.id,
    required this.orderId,
    this.customerId,
    required this.customerName,
    required this.customerEmail,
    required this.customerPhone,
    required this.items,
    this.subtotal = 0,
    this.tax = 0,
    required this.total,
    required this.status,
    this.paymentMethod = 'GCash',
    this.paymentReference,
    this.location = '',
    this.pickupTime = '',
    required this.createdAt,
    this.expiresAt,
    this.rejectionReason,
    this.notes,
    this.isSeniorPWD = false,
    this.isExtended = false,
  });

  static OrderStatus _parseStatus(dynamic rawStatus) {
    final str = rawStatus?.toString() ?? 'pending';
    switch (str) {
      case 'staging':
      case 'processing':
        return OrderStatus.staging;
      case 'ready':
        return OrderStatus.ready;
      case 'collected':
      case 'completed':
        return OrderStatus.collected;
      case 'cancelled':
      case 'rejected':
        return OrderStatus.cancelled;
      case 'refunded':
        return OrderStatus.refunded;
      case 'refundRequested':
      case 'refund_requested':
        return OrderStatus.refundRequested;
      case 'refundRejected':
      case 'refund_rejected':
        return OrderStatus.refundRejected;
      case 'pending':
      default:
        return OrderStatus.pending;
    }
  }

  factory PreOrder.fromFirestore(DocumentSnapshot doc) {
    try {
      final d = doc.data() as Map<String, dynamic>? ?? {};
      final double parsedTotal = (d['total'] as num? ?? 0).toDouble();
      final double parsedTax = (d['tax'] as num? ?? 0).toDouble();
      final double parsedSubtotal =
          (d['subtotal'] as num? ?? (parsedTotal - parsedTax)).toDouble();

      return PreOrder(
        id: doc.id,
        orderId: d['orderId']?.toString() ?? 'GDC-????',
        customerId: d['customerId']?.toString(),
        customerName: d['customerName']?.toString() ?? 'Unknown Customer',
        customerEmail: d['customerEmail']?.toString() ?? '',
        customerPhone: d['customerPhone']?.toString() ?? '',
        items: (d['items'] as List? ?? [])
            .map((e) => CartItem.fromMap(e))
            .toList(),
        subtotal: parsedSubtotal < 0 ? 0 : parsedSubtotal,
        tax: parsedTax < 0 ? 0 : parsedTax,
        total: parsedTotal,
        status: _parseStatus(d['status']),
        paymentMethod: d['paymentMethod']?.toString() ?? 'GCash',
        paymentReference: d['paymentReference']?.toString(),
        location: d['location']?.toString() ?? '',
        pickupTime: d['pickupTime']?.toString() ?? '',
        createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        expiresAt: (d['expiresAt'] as Timestamp?)?.toDate(),
        rejectionReason: d['rejectionReason']?.toString(),
        notes:
            (d['notes'] ?? d['pickupNotes'] ?? d['customerNotes'])?.toString(),
        isSeniorPWD: d['isSeniorPWD'] ?? false,
        isExtended: d['isExtended'] ?? false,
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
          paymentMethod: 'GCash',
          createdAt: DateTime.now());
    }
  }

  Map<String, dynamic> toFirestore() => {
        'orderId': orderId,
        'customerId': customerId ?? FirebaseAuth.instance.currentUser?.uid,
        'customerName': customerName,
        'customerEmail': customerEmail,
        'customerPhone': customerPhone,
        'items': items.map((i) => i.toMap()).toList(),
        'subtotal':
            subtotal > 0 ? subtotal : (total - tax).clamp(0.0, double.infinity),
        'tax': tax,
        'total': total,
        'status': status.name,
        'paymentMethod': paymentMethod,
        if (paymentReference != null) 'paymentReference': paymentReference,
        'location': location,
        'pickupTime': pickupTime,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
        'isSeniorPWD': isSeniorPWD,
        'isExtended': isExtended,
        if (rejectionReason != null) 'rejectionReason': rejectionReason,
        if (notes != null && notes!.trim().isNotEmpty) 'notes': notes!.trim(),
        if (notes != null && notes!.trim().isNotEmpty)
          'pickupNotes': notes!.trim(),
      };

  bool get isExpired {
    if (expiresAt == null) return false;
    final isActive = status == OrderStatus.pending ||
        status == OrderStatus.staging ||
        status == OrderStatus.ready;
    return isActive && TimeService.now.isAfter(expiresAt!);
  }

  PreOrder copyWith({
    OrderStatus? status,
    String? paymentMethod,
    String? paymentReference,
    DateTime? expiresAt,
    bool? isExtended,
    String? notes,
  }) =>
      PreOrder(
        id: id,
        orderId: orderId,
        customerId: customerId,
        customerName: customerName,
        customerEmail: customerEmail,
        customerPhone: customerPhone,
        items: items,
        subtotal: subtotal,
        tax: tax,
        total: total,
        status: status ?? this.status,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        paymentReference: paymentReference ?? this.paymentReference,
        location: location,
        pickupTime: pickupTime,
        createdAt: createdAt,
        expiresAt: expiresAt ?? this.expiresAt,
        rejectionReason: rejectionReason,
        notes: notes ?? this.notes,
        isSeniorPWD: isSeniorPWD,
        isExtended: isExtended ?? this.isExtended,
      );
}
