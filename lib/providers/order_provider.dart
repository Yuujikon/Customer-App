import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../models/refund_request.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';

class OrderProvider extends ChangeNotifier {
  final _fs = FirestoreService();

  final List<PreOrder> _orders  = [];
  final List<CartItem> _preCart = [];

  List<PreOrder> get orders  => _orders;
  List<CartItem> get preCart => _preCart;

  // Stream that auto-updates for admin view
  Stream<List<PreOrder>> get ordersStream => _fs.ordersStream();

  // Stream for a specific customer
  Stream<List<PreOrder>> ordersStreamForEmail(String email) =>
      _fs.ordersStreamForEmail(email).map((list) {
        _orders.clear();
        _orders.addAll(list);
        return list;
      });

  Stream<List<RefundRequest>> refundRequestsStreamForEmail(String email) =>
      _fs.refundRequestsStreamForEmail(email);

  void initialize() {
    // In the customer app, we don't listen to ALL orders at startup.
    // Individual screens use ordersStreamForEmail()
  }

  // ── Pre-order cart ─────────────────────────────────────────────────────────

  void addToPreCart(Product p) {
    final idx = _preCart.indexWhere((i) => i.productId == p.id);
    if (idx >= 0) {
      _preCart[idx] = _preCart[idx].copyWith(qty: (_preCart[idx].qty + 1).clamp(1, p.stock));
    } else {
      _preCart.add(CartItem(
        productId: p.id,
        name: p.name,
        price: p.price,
        qty: 1,
        isPerishable: p.isPerishable,
      ));
    }
    notifyListeners();
  }

  void removeFromPreCart(String productId) {
    _preCart.removeWhere((i) => i.productId == productId);
    notifyListeners();
  }

  void adjustPreCartQty(String productId, int delta, int stock) {
    final idx = _preCart.indexWhere((i) => i.productId == productId);
    if (idx < 0) return;
    _preCart[idx] = _preCart[idx].copyWith(qty: (_preCart[idx].qty + delta).clamp(1, stock));
    notifyListeners();
  }

  void setPreCartQty(String productId, int qty, int stock) {
    final idx = _preCart.indexWhere((i) => i.productId == productId);
    if (idx < 0) return;
    _preCart[idx] = _preCart[idx].copyWith(qty: qty.clamp(1, stock));
    notifyListeners();
  }

  // ── Submit order ───────────────────────────────────────────────────────────

  Future<PreOrder> submitOrder({
    required String customerName,
    required String customerEmail,
    required String notes,
    required String location,
    required String pickupSlot,
    required List<Product> allProducts,
  }) async {
    // Determine expiration based on items
    final hasPerishables = _preCart.any((i) => i.isPerishable);
    final onlyPerishables = _preCart.every((i) => i.isPerishable);
    
    DateTime expiresAt;
    if (onlyPerishables) {
      expiresAt = DateTime.now().add(const Duration(hours: 2));
    } else if (hasPerishables) {
      expiresAt = DateTime.now().add(const Duration(days: 1));
    } else {
      expiresAt = DateTime.now().add(const Duration(days: 3));
    }

    // Generate a human-readable order ID using timestamp to avoid needing a full orders listener
    final ts = DateTime.now().millisecondsSinceEpoch.toString();
    final shortId = ts.substring(ts.length - 4);
    
    final order = PreOrder(
      id:            const Uuid().v4(),
      orderId:       'GDC-$shortId',
      customerName:  customerName,
      customerEmail: customerEmail,
      items:         List.from(_preCart),
      total:         _preCart.fold(0.0, (s, i) => s + i.price * i.qty),
      status:        OrderStatus.pending,
      notes:         notes,
      location:      location,
      pickupTime:    pickupSlot,
      createdAt:     DateTime.now(),
      expiresAt:     expiresAt,
    );

    await _fs.addOrder(order);

    // Schedule perishable auto-cancel via Firebase Cloud Functions
    // (see Cloud Functions section below)
    final hasPerishable = _preCart.any((ci) =>
        allProducts.any((p) => p.id == ci.productId && p.isPerishable));
    if (hasPerishable) {
      await NotificationService.schedulePerishableReminder(order.id, order.orderId);
    }

    _preCart.clear();
    notifyListeners();
    return order;
  }

  // ── Admin actions ──────────────────────────────────────────────────────────

  Future<void> advanceStatus(String orderId) async {
    final order = _orders.firstWhere((o) => o.id == orderId);
    final next  = switch (order.status) {
      OrderStatus.pending  => OrderStatus.staging,
      OrderStatus.staging  => OrderStatus.ready,
      OrderStatus.ready    => OrderStatus.collected,
      _ => null,
    };
    if (next == null) return;
    await _fs.updateOrderStatus(orderId, next);

    // Notify customer when order is ready
    if (next == OrderStatus.ready) {
      await NotificationService.sendOrderReady(order.orderId);
    }
  }

  Future<void> refundOrder(String orderId) async {
    final order = _orders.firstWhere((o) => o.id == orderId);
    if (order.status == OrderStatus.refunded) return;

    await _fs.refundOrder(orderId, order.items);
    notifyListeners();
  }

  Future<void> requestRefund(String orderId, String reason) async {
    final order = _orders.firstWhere((o) => o.id == orderId);
    
    // 1. Avoid Duplication
    final existingRequests = await _fs.getRefundRequestsForTransaction(order.orderId);
    if (existingRequests.isNotEmpty) {
      throw 'A refund request for this order is already being processed.';
    }

    final req = RefundRequest(
      id: '',
      transactionId: order.orderId,
      customerEmail: order.customerEmail,
      customerName: order.customerName,
      items: order.items,
      total: order.total,
      reason: reason,
      status: RefundStatus.pending,
      createdAt: DateTime.now(),
    );

    await _fs.requestRefund(req);
    
    // 2. Notification after refund request
    await NotificationService.notifyAdminRefundRequest(order.orderId, order.customerName);
    
    // Update order status to show it's being reviewed
    await _fs.updateOrderStatus(orderId, OrderStatus.refund_requested);

    notifyListeners();
  }
}
