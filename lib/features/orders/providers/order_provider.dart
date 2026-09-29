import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';
import '../../../shared/models/order.dart';
import '../../../shared/models/product.dart';
import '../../../shared/models/refund_request.dart';
import '../../../shared/models/store_settings.dart';
import '../../../shared/services/firestore_service.dart';
import '../../../shared/services/notification_service.dart';
import '../../../core/utils/pricing_engine.dart';
import '../../../core/utils/format.dart';

class OrderProvider extends ChangeNotifier {
  final _fs = FirestoreService();

  final List<PreOrder> _orders  = [];
  final List<CartItem> _preCart = [];
  final Map<String, OrderStatus> _lastOrderStatusMap = {};
  final Map<String, RefundStatus> _lastRefundStatusMap = {};
  StoreSettings _settings = const StoreSettings(isClosed: false);

  List<PreOrder> get orders  => _orders;
  List<CartItem> get preCart => _preCart;

  PreOrder? get recentOrder => _orders.isNotEmpty ? _orders.first : null;

  // Stream that auto-updates for admin view
  Stream<List<PreOrder>> get ordersStream => _fs.ordersStream().map((list) {
    return _processAndCancelExpired(list);
  });

  // Stream for a specific customer
  Stream<List<PreOrder>>? _cachedStream;
  String? _cachedEmail;
  StreamSubscription? _ordersSub;
  Timer? _expirationTimer;

  Stream<List<PreOrder>> ordersStreamForEmail(String email, {int limit = 50}) {
    if (_cachedStream != null && _cachedEmail == email) {
      return _cachedStream!;
    }
    
    _ordersSub?.cancel();
    _cachedEmail = email;
    _cachedStream = _fs.ordersStreamForEmail(email, limit: limit)
        .map((list) => _processAndCancelExpired(list))
        .asBroadcastStream();
    
    _ordersSub = _cachedStream!.listen((list) {
      for (final order in list) {
        final previousStatus = _lastOrderStatusMap[order.id];
        if (previousStatus != null && previousStatus != order.status) {
          _notifyCustomerOrderStatusChange(order, previousStatus, order.status);
        }
        _lastOrderStatusMap[order.id] = order.status;
      }

      _orders.clear();
      _orders.addAll(list);
      notifyListeners();
    });

    _startExpirationTimer();
    
    return _cachedStream!;
  }

  void _startExpirationTimer() {
    _expirationTimer?.cancel();
    _expirationTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      bool hasExpiredChange = false;
      for (int i = 0; i < _orders.length; i++) {
        if (_orders[i].isExpired) {
          _fs.cancelOrder(_orders[i].id, _orders[i].items);
          _orders[i] = _orders[i].copyWith(status: OrderStatus.cancelled);
          hasExpiredChange = true;
        }
      }
      if (hasExpiredChange) {
        notifyListeners();
      }
    });
  }

  void _notifyCustomerOrderStatusChange(PreOrder order, OrderStatus oldStatus, OrderStatus newStatus) {
    if (newStatus == OrderStatus.staging) {
      NotificationService.showSmsNotificationPopUp(
        title: '✅ Pre-Order Accepted!',
        body: 'Your order ${order.orderId} was accepted and is being prepared.',
      );
    } else if (newStatus == OrderStatus.ready) {
      NotificationService.sendOrderReady(order.orderId);
    } else if (newStatus == OrderStatus.collected) {
      NotificationService.showSmsNotificationPopUp(
        title: '🎉 Order Collected!',
        body: 'Your order ${order.orderId} has been collected. Thank you for shopping!',
      );
    } else if (newStatus == OrderStatus.cancelled || newStatus == OrderStatus.refundRejected) {
      NotificationService.showSmsNotificationPopUp(
        title: '⚠️ Order Cancelled/Rejected',
        body: 'Your order ${order.orderId} was cancelled or rejected.',
      );
    }
  }

  /// Automatically cancels orders that have passed their expiresAt timestamp.
  /// Cancels in Firestore and returns copies with cancelled status for UI consistency.
  List<PreOrder> _processAndCancelExpired(List<PreOrder> list) {
    return list.map((order) {
      if (order.isExpired) {
        _fs.cancelOrder(order.id, order.items);
        debugPrint('Auto-cancelled expired order: ${order.orderId}');
        return order.copyWith(status: OrderStatus.cancelled);
      }
      return order;
    }).toList();
  }

  Stream<List<RefundRequest>> refundRequestsStreamForEmail(String email) =>
      _fs.refundRequestsStreamForEmail(email).map((list) {
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        for (final req in list) {
          final previousStatus = _lastRefundStatusMap[req.id];
          if (previousStatus != null && previousStatus != req.status) {
            final storeNote = (req.adminNotes != null && req.adminNotes!.trim().isNotEmpty)
                ? ' Store note: "${req.adminNotes!.trim()}"'
                : '';

            if (req.status == RefundStatus.approved) {
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid != null) {
                _fs.addCustomerNotification(
                  userId: uid,
                  title: '💸 Refund Successful',
                  body: 'Your refund request for #${req.transactionId} (${formatPeso(req.total)}) was approved.$storeNote',
                  type: 'order',
                  relatedId: req.transactionId,
                );
              }
              NotificationService.showSmsNotificationPopUp(
                title: '💸 Refund Approved',
                body: 'Your refund for #${req.transactionId} has been approved.$storeNote',
              );
            } else if (req.status == RefundStatus.rejected) {
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid != null) {
                _fs.addCustomerNotification(
                  userId: uid,
                  title: '❌ Refund Rejected',
                  body: 'Your refund request for #${req.transactionId} was rejected.$storeNote',
                  type: 'order',
                  relatedId: req.transactionId,
                );
              }
              NotificationService.showSmsNotificationPopUp(
                title: '❌ Refund Rejected',
                body: 'Your refund request for #${req.transactionId} was rejected.$storeNote',
              );
            }
          }
          _lastRefundStatusMap[req.id] = req.status;
        }
        return list;
      });

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
  }

  /// Adds items from a previous order to the cart, validating current stock.
  /// Returns a map with 'added', 'unavailable', and 'partial' counts.
  Future<Map<String, int>> reorderItems(List<CartItem> items, List<Product> allProducts) async {
    int addedCount = 0;
    int unavailableCount = 0;
    int partialCount = 0;

    for (final item in items) {
      try {
        final p = allProducts.firstWhere((prod) => prod.id == item.productId);
        
        int maxStock = p.maxPurchasableStock;
        if (item.variantId != null && p.variants != null) {
          final v = p.variants![item.variantId];
          if (v == null || v.isOutOfStockForCustomer) {
            unavailableCount++;
            continue;
          }
          maxStock = v.maxPurchasableStock;
        } else if (p.isOutOfStockForCustomer) {
          unavailableCount++;
          continue;
        }

        if (maxStock <= 0) {
          unavailableCount++;
          continue;
        }

        final existingIdx = _preCart.indexWhere((i) => i.productId == p.id && i.variantId == item.variantId);
        int currentInCart = existingIdx >= 0 ? _preCart[existingIdx].qty : 0;
        
        int desiredToBatch = item.qty;
        int availableSpace = maxStock - currentInCart;

        if (availableSpace <= 0) {
          unavailableCount++;
          continue;
        }

        int toAdd = desiredToBatch.clamp(0, availableSpace);
        if (toAdd < desiredToBatch) {
          partialCount++;
        }

        if (existingIdx >= 0) {
          _preCart[existingIdx] = _preCart[existingIdx].copyWith(qty: currentInCart + toAdd);
        } else {
          _preCart.add(item.copyWith(qty: toAdd, price: item.price));
        }
        addedCount++;
      } catch (_) {
        unavailableCount++;
      }
    }

    notifyListeners();
    return {
      'added': addedCount,
      'unavailable': unavailableCount,
      'partial': partialCount,
    };
  }

  // ── Pre-order cart ─────────────────────────────────────────────────────────

  void addToPreCart(Product p, {int quantity = 1, String? variantId, String? variantName, bool replace = false}) {
    final idx = _preCart.indexWhere((i) => i.productId == p.id && i.variantId == variantId);
    
    int maxStock = p.maxPurchasableStock;
    double itemPrice = p.price;
    
    if (variantId != null && p.variants != null) {
      final v = p.variants![variantId];
      if (v != null) {
        maxStock = v.maxPurchasableStock;
        itemPrice = v.price;
      }
    }

    if (maxStock <= 0) return;

    if (idx >= 0) {
      final newQty = replace ? quantity : (_preCart[idx].qty + quantity);
      _preCart[idx] = _preCart[idx].copyWith(qty: newQty.clamp(1, maxStock));
    } else {
      _preCart.add(CartItem(
        productId: p.id,
        name: p.name,
        price: itemPrice,
        qty: quantity.clamp(1, maxStock),
        isPerishable: p.isPerishable,
        variantId: variantId,
        variantName: variantName,
      ));
    }
    notifyListeners();
  }

  void removeFromPreCart(String productId, {String? variantId}) {
    if (variantId != null) {
      _preCart.removeWhere((i) => i.productId == productId && i.variantId == variantId);
    } else {
      _preCart.removeWhere((i) => i.productId == productId);
    }
    notifyListeners();
  }

  void clearPreCart() {
    _preCart.clear();
    notifyListeners();
  }

  void adjustPreCartQty(String productId, int delta, int stock, {String? variantId}) {
    final idx = _preCart.indexWhere((i) => i.productId == productId && (variantId == null || i.variantId == variantId));
    if (idx < 0) return;
    _preCart[idx] = _preCart[idx].copyWith(qty: (_preCart[idx].qty + delta).clamp(1, stock));
    notifyListeners();
  }

  void setPreCartQty(String productId, int qty, int stock, {String? variantId}) {
    final idx = _preCart.indexWhere((i) => i.productId == productId && (variantId == null || i.variantId == variantId));
    if (idx < 0) return;
    _preCart[idx] = _preCart[idx].copyWith(qty: qty.clamp(1, stock));
    notifyListeners();
  }

  // ── Submit order ───────────────────────────────────────────────────────────

  Future<PreOrder> submitOrder({
    required String customerName,
    required String customerEmail,
    required String customerPhone,
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
    
    final breakdown = PricingEngine.calculate(
      items: _preCart, 
      allProducts: allProducts,
    );
    
    final order = PreOrder(
      id:            const Uuid().v4(),
      orderId:       'GDC-$shortId',
      customerName:  customerName,
      customerEmail: customerEmail,
      customerPhone: customerPhone,
      items:         List.from(_preCart),
      tax:           0,
      total:         breakdown.total,
      status:        OrderStatus.pending,
      location:      location,
      pickupTime:    pickupSlot,
      createdAt:     DateTime.now(),
      expiresAt:     expiresAt,
    );

    // Atomic submission: checks stock and decrements in one transaction
    await _fs.submitOrderTransactional(order);

    // Record in-store notification for customer
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await _fs.addCustomerNotification(
        userId: uid,
        title: '🛍️ Purchase Successful',
        body: 'Your pre-order ${order.orderId} (${formatPeso(order.total)}) was submitted successfully. Pickup time: ${order.pickupTime}.',
        type: 'order',
        relatedId: order.orderId,
      );
    }

    // Schedule local reminder
    await NotificationService.schedulePerishableReminder(
      order.id, 
      order.orderId, 
      hours: minWindow,
    );

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
    await _fs.updateOrderStatus(orderId, OrderStatus.refundRequested);

    notifyListeners();
  }

  Future<void> cancelRefundRequest({required String transactionId, String? requestId}) async {
    String reqId = requestId ?? '';
    if (reqId.isEmpty) {
      final reqs = await _fs.getRefundRequestsForTransaction(transactionId);
      final pending = reqs.where((r) => r.status == RefundStatus.pending);
      if (pending.isNotEmpty) {
        reqId = pending.first.id;
      }
    }

    await _fs.cancelRefundRequest(refundRequestId: reqId, transactionId: transactionId);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await _fs.addCustomerNotification(
        userId: uid,
        title: '🚫 Refund Request Cancelled',
        body: 'Your refund request for #$transactionId was cancelled successfully.',
        type: 'order',
        relatedId: transactionId,
      );
    }

    await NotificationService.showSmsNotificationPopUp(
      title: '🚫 Refund Cancelled',
      body: 'Refund request for #$transactionId has been cancelled.',
    );

    notifyListeners();
  }

  @override
  void dispose() {
    _ordersSub?.cancel();
    _expirationTimer?.cancel();
    super.dispose();
  }
}
