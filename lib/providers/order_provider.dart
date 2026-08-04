import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../models/promotion.dart';
import '../models/refund_request.dart';
import '../models/store_settings.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../utils/pricing_engine.dart';

class OrderProvider extends ChangeNotifier {
  final _fs = FirestoreService();

  final List<PreOrder> _orders  = [];
  final List<CartItem> _preCart = [];
  List<Promotion> _promotions = [];
  StoreSettings _settings = const StoreSettings(isClosed: false);

  List<PreOrder> get orders  => _orders;
  List<CartItem> get preCart => _preCart;

  // Stream that auto-updates for admin view
  Stream<List<PreOrder>> get ordersStream => _fs.ordersStream();

  // Stream for a specific customer
  Stream<List<PreOrder>>? _cachedStream;
  String? _cachedEmail;

  Stream<List<PreOrder>> ordersStreamForEmail(String email, {int limit = 20}) {
    if (_cachedStream != null && _cachedEmail == email) {
      return _cachedStream!;
    }
    
    _cachedEmail = email;
    _cachedStream = _fs.ordersStreamForEmail(email, limit: limit).map((list) {
      _orders.clear();
      _orders.addAll(list);
      return list;
    }).asBroadcastStream();
    
    return _cachedStream!;
  }

  Stream<List<RefundRequest>> refundRequestsStreamForEmail(String email) =>
      _fs.refundRequestsStreamForEmail(email);

  List<CartItem> getBuyItAgainItems() {
    if (_orders.isEmpty) return [];
    
    // Count occurrences of each product in the last 10 orders
    final counts = <String, int>{};
    final itemsMap = <String, CartItem>{};
    
    final recentOrders = _orders.take(10);
    for (final order in recentOrders) {
      if (order.status == OrderStatus.collected) {
        for (final item in order.items) {
          counts[item.productId] = (counts[item.productId] ?? 0) + 1;
          itemsMap[item.productId] = item;
        }
      }
    }

    final sortedIds = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));
      
    return sortedIds.take(5).map((id) => itemsMap[id]!).toList();
  }

  void initialize() {
    _fs.settingsStream().listen((s) {
      _settings = s;
      notifyListeners();
    });

    _fs.promotionsStream().listen((list) {
      _promotions = list;
      notifyListeners();
    });
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
    int minWindow = _settings.standardWindowHours;
    bool hasPerishables = false;

    for (final item in _preCart) {
      final p = allProducts.firstWhere((prod) => prod.id == item.productId);
      int itemWindow;
      
      if (p.pickupWindowHours != null) {
        itemWindow = p.pickupWindowHours!;
      } else if (p.isPerishable) {
        itemWindow = _settings.perishableWindowHours;
      } else {
        itemWindow = _settings.standardWindowHours;
      }

      if (p.isPerishable) hasPerishables = true;
      if (itemWindow < minWindow) minWindow = itemWindow;
    }

    // Special case for mixed orders if store has a specific mixed window policy
    if (hasPerishables && _preCart.any((i) => !i.isPerishable)) {
       if (_settings.mixedWindowHours < minWindow) minWindow = _settings.mixedWindowHours;
    }
    
    final expiresAt = DateTime.now().add(Duration(hours: minWindow));

    // Generate a human-readable order ID using timestamp to avoid needing a full orders listener
    final ts = DateTime.now().millisecondsSinceEpoch.toString();
    final shortId = ts.substring(ts.length - 4);
    
    // Calculate breakdown using PricingEngine
    final breakdown = PricingEngine.calculate(
      items: _preCart, 
      allProducts: allProducts, 
      activePromos: _promotions,
    );
    
    final order = PreOrder(
      id:            const Uuid().v4(),
      orderId:       'GDC-$shortId',
      customerName:  customerName,
      customerEmail: customerEmail,
      items:         List.from(_preCart),
      subtotal:      breakdown.subtotal,
      discount:      breakdown.promoDiscount + breakdown.seniorDiscount,
      tax:           breakdown.vAtAmount,
      total:         breakdown.total,
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
