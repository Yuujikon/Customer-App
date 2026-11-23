import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';
import 'dart:math' as math;
import 'reorder_preview.dart';
import '../../../shared/models/order.dart';
import '../../../shared/models/product.dart';
import '../../../shared/models/refund_request.dart';
import '../../../shared/models/store_settings.dart';
import '../../../shared/services/firestore_service.dart';
import '../../../shared/services/notification_service.dart';
import '../../../shared/services/time_service.dart';
import '../../../core/utils/pricing_engine.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/store_hours.dart';

class OrderProvider extends ChangeNotifier {
  final _fs = FirestoreService();
  bool _isDisposed = false;

  final List<PreOrder> _orders = [];
  final List<CartItem> _preCart = [];
  final Map<String, OrderStatus> _lastOrderStatusMap = {};
  final Map<String, RefundStatus> _lastRefundStatusMap = {};
  StoreSettings _settings = const StoreSettings(isClosed: false);

  List<PreOrder> get orders => _orders;
  List<CartItem> get preCart => _preCart;

  PreOrder? get recentOrder => _orders.isNotEmpty ? _orders.first : null;
  List<PreOrder> get recentOrders => _orders
      .where((o) =>
          o.status == OrderStatus.collected || o.status == OrderStatus.ready)
      .take(3)
      .toList();

  // Stream that auto-updates for admin view
  Stream<List<PreOrder>> get ordersStream => _fs.ordersStream().map((list) {
        return _processAndCancelExpired(list);
      });

  // Stream for a specific customer
  Stream<List<PreOrder>>? _cachedStream;
  String? _cachedEmail;
  StreamSubscription? _ordersSub;
  StreamSubscription? _settingsSub;
  Timer? _expirationTimer;

  Stream<List<PreOrder>> ordersStreamForEmail(String email, {int limit = 50}) {
    if (_cachedStream != null && _cachedEmail == email) {
      return _cachedStream!;
    }

    _ordersSub?.cancel();
    _cachedEmail = email;
    _cachedStream = _fs
        .ordersStreamForEmail(email, limit: limit)
        .map((list) => _processAndCancelExpired(list))
        .asBroadcastStream();

    _ordersSub = _cachedStream!.listen((list) {
      if (_isDisposed) return;
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
    }, onError: (e) {
      debugPrint('Error listening to customer orders stream: $e');
    });

    _startExpirationTimer();

    return _cachedStream!;
  }

  OrderProvider() {
    TimeService.instance.addListener(_onTimeServiceChanged);
  }

  void _onTimeServiceChanged() {
    if (_isDisposed) return;
    _checkAndProcessExpirations();
    notifyListeners();
  }

  final Set<String> _processedExpiredOrderIds = {};

  void _handleExpiredAwaitingPayment(PreOrder order) {
    if (order.status != OrderStatus.awaitingPayment) return;
    if (_processedExpiredOrderIds.contains(order.id)) return;
    _processedExpiredOrderIds.add(order.id);

    _fs.cancelOrder(order.id, order.items).catchError((e) {
      debugPrint(
          'Failed to auto-release expired awaitingPayment order ${order.orderId}: $e');
    });
  }

  void _checkAndProcessExpirations() {
    bool hasExpiredChange = false;
    for (int i = 0; i < _orders.length; i++) {
      final order = _orders[i];
      if (order.isExpired && order.status == OrderStatus.awaitingPayment) {
        _handleExpiredAwaitingPayment(order);
        _orders[i] = order.copyWith(
          status: OrderStatus.cancelled,
          reservationReleased: true,
        );
        hasExpiredChange = true;
      }
    }
    if (hasExpiredChange) {
      notifyListeners();
    }
  }

  void _startExpirationTimer() {
    _expirationTimer?.cancel();
    _expirationTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _checkAndProcessExpirations();
    });
  }

  void _notifyCustomerOrderStatusChange(
      PreOrder order, OrderStatus oldStatus, OrderStatus newStatus) {
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
        body:
            'Your order ${order.orderId} has been collected. Thank you for shopping!',
      );
    } else if (newStatus == OrderStatus.cancelled ||
        newStatus == OrderStatus.refundRejected) {
      NotificationService.showSmsNotificationPopUp(
        title: '⚠️ Order Cancelled/Rejected',
        body: 'Your order ${order.orderId} was cancelled or rejected.',
      );
    }
  }

  /// Automatically cancels expired `awaitingPayment` reservations from the client side.
  /// Uncollected pickup orders (`pending`/`staging`/`ready`) are expired & penalized by Admin-App.
  List<PreOrder> _processAndCancelExpired(List<PreOrder> list) {
    return list.map((order) {
      if (order.isExpired && order.status == OrderStatus.awaitingPayment) {
        _handleExpiredAwaitingPayment(order);
        debugPrint(
            'Auto-cancelled unpaid awaitingPayment order: ${order.orderId}');
        return order.copyWith(
          status: OrderStatus.cancelled,
          reservationReleased: true,
        );
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
            final storeNote =
                (req.adminNotes != null && req.adminNotes!.trim().isNotEmpty)
                    ? ' Store note: "${req.adminNotes!.trim()}"'
                    : '';

            if (req.status == RefundStatus.approved) {
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid != null) {
                _fs.addCustomerNotification(
                  userId: uid,
                  title: '💸 Refund Successful',
                  body:
                      'Your refund request for #${req.transactionId} (${formatPeso(req.total)}) was approved.$storeNote',
                  type: 'order',
                  relatedId: req.transactionId,
                );
              }
              NotificationService.showSmsNotificationPopUp(
                title: '💸 Refund Approved',
                body:
                    'Your refund for #${req.transactionId} has been approved.$storeNote',
              );
            } else if (req.status == RefundStatus.rejected) {
              final uid = FirebaseAuth.instance.currentUser?.uid;
              if (uid != null) {
                _fs.addCustomerNotification(
                  userId: uid,
                  title: '❌ Refund Rejected',
                  body:
                      'Your refund request for #${req.transactionId} was rejected.$storeNote',
                  type: 'order',
                  relatedId: req.transactionId,
                );
              }
              NotificationService.showSmsNotificationPopUp(
                title: '❌ Refund Rejected',
                body:
                    'Your refund request for #${req.transactionId} was rejected.$storeNote',
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
    _settingsSub?.cancel();
    _settingsSub = _fs.settingsStream().listen((s) {
      if (_isDisposed) return;
      _settings = s;
      notifyListeners();
    }, onError: (e) {
      debugPrint('Error listening to store settings stream: $e');
    });
  }

  /// Adds items from a previous order to the cart, validating current stock.
  /// Returns a map with 'added', 'unavailable', and 'partial' counts.
  List<ReorderItemPreview> previewReorder(
      List<CartItem> items, List<Product> allProducts) {
    List<ReorderItemPreview> previews = [];

    for (final item in items) {
      Product? p;
      try {
        p = allProducts.firstWhere((prod) => prod.id == item.productId);
      } catch (_) {}

      if (p == null) {
        previews.add(ReorderItemPreview(
          originalItem: item,
          product: null,
          toAddQty: 0,
          availableStock: 0,
          isUnavailable: true,
          isAdjusted: false,
        ));
        continue;
      }

      int maxStock = p.maxPurchasableStock;
      if (item.variantId != null && p.variants != null) {
        final v = p.variants![item.variantId];
        if (v == null || v.isOutOfStockForCustomer) {
          previews.add(ReorderItemPreview(
            originalItem: item,
            product: p,
            toAddQty: 0,
            availableStock: 0,
            isUnavailable: true,
            isAdjusted: false,
          ));
          continue;
        }
        maxStock = v.maxPurchasableStock;
      } else if (p.isOutOfStockForCustomer) {
        previews.add(ReorderItemPreview(
          originalItem: item,
          product: p,
          toAddQty: 0,
          availableStock: 0,
          isUnavailable: true,
          isAdjusted: false,
        ));
        continue;
      }

      if (maxStock <= 0) {
        previews.add(ReorderItemPreview(
          originalItem: item,
          product: p,
          toAddQty: 0,
          availableStock: 0,
          isUnavailable: true,
          isAdjusted: false,
        ));
        continue;
      }

      final existingIdx = _preCart.indexWhere(
          (i) => i.productId == p!.id && i.variantId == item.variantId);
      int currentInCart = existingIdx >= 0 ? _preCart[existingIdx].qty : 0;

      int desiredToBatch = item.qty;
      int availableSpace = maxStock - currentInCart;

      if (availableSpace <= 0) {
        previews.add(ReorderItemPreview(
          originalItem: item,
          product: p,
          toAddQty: 0,
          availableStock: availableSpace,
          isUnavailable: true,
          isAdjusted: false,
        ));
        continue;
      }

      int toAdd = desiredToBatch.clamp(0, availableSpace);
      bool isAdjusted = toAdd < desiredToBatch;

      previews.add(ReorderItemPreview(
        originalItem: item,
        product: p,
        toAddQty: toAdd,
        availableStock: availableSpace,
        isUnavailable: false,
        isAdjusted: isAdjusted,
      ));
    }

    return previews;
  }

  void applyReorder(List<ReorderItemPreview> previews) {
    for (final preview in previews) {
      if (preview.isUnavailable || preview.toAddQty <= 0) continue;

      final variantId = preview.originalItem.variantId;
      double currentPrice = preview.originalItem.price;
      if (preview.product != null) {
        if (variantId != null && preview.product!.variants?[variantId] != null) {
          currentPrice = preview.product!.variants![variantId]!.price;
        } else {
          currentPrice = preview.product!.price;
        }
      }

      final existingIdx = _preCart.indexWhere((i) =>
          i.productId == preview.originalItem.productId &&
          i.variantId == variantId);

      if (existingIdx >= 0) {
        _preCart[existingIdx] = _preCart[existingIdx].copyWith(
          qty: _preCart[existingIdx].qty + preview.toAddQty,
          price: currentPrice,
        );
      } else {
        _preCart.add(preview.originalItem.copyWith(
          qty: preview.toAddQty,
          price: currentPrice,
        ));
      }
    }
    notifyListeners();
  }

  // ── Pre-order cart ─────────────────────────────────────────────────────────

  void addToPreCart(Product p,
      {int quantity = 1,
      String? variantId,
      String? variantName,
      bool replace = false}) {
    final idx = _preCart
        .indexWhere((i) => i.productId == p.id && i.variantId == variantId);

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
      _preCart[idx] = _preCart[idx].copyWith(
        qty: newQty.clamp(1, maxStock),
        barcode: p.barcode ?? '',
      );
    } else {
      _preCart.add(CartItem(
        productId: p.id,
        name: p.name,
        barcode: p.barcode ?? '',
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
      _preCart.removeWhere(
          (i) => i.productId == productId && i.variantId == variantId);
    } else {
      _preCart.removeWhere((i) => i.productId == productId);
    }
    notifyListeners();
  }

  void clearPreCart() {
    _preCart.clear();
    notifyListeners();
  }

  void adjustPreCartQty(String productId, int delta, int stock,
      {String? variantId}) {
    final idx = _preCart.indexWhere((i) =>
        i.productId == productId &&
        (variantId == null || i.variantId == variantId));
    if (idx < 0) return;
    final maxStock = stock <= 0 ? 0 : stock;
    if (maxStock <= 0) {
      _preCart.removeAt(idx);
      notifyListeners();
      return;
    }
    final newQty = (_preCart[idx].qty + delta).clamp(1, maxStock);
    _preCart[idx] = _preCart[idx].copyWith(qty: newQty);
    notifyListeners();
  }

  void setPreCartQty(String productId, int qty, int stock,
      {String? variantId}) {
    final idx = _preCart.indexWhere((i) =>
        i.productId == productId &&
        (variantId == null || i.variantId == variantId));
    if (idx < 0) return;
    final maxStock = stock <= 0 ? 0 : stock;
    if (maxStock <= 0) {
      _preCart.removeAt(idx);
      notifyListeners();
      return;
    }
    final newQty = qty.clamp(1, maxStock);
    _preCart[idx] = _preCart[idx].copyWith(qty: newQty);
    notifyListeners();
  }

  /// Calculates available extension minutes up to 20 minutes max.
  /// Only available during the final 10 minutes before the order's allocated expiration time.
  /// Disabled (returns 0) if order was already extended once, or if current time/expiration is at/past closing cutoff.
  static int getAvailableExtensionMinutes(DateTime? currentExpiry,
      {bool isExtended = false, StoreSettings? settings}) {
    if (currentExpiry == null || isExtended) return 0;
    final now = TimeService.now;

    // Only allow extension when within 10 minutes before pickup expiration
    final secondsRemaining = currentExpiry.difference(now).inSeconds;
    if (secondsRemaining > 600 || secondsRemaining <= 0) {
      return 0;
    }

    final closeH = StoreHours.effectiveCloseHour(settings);
    final cutoff = DateTime(now.year, now.month, now.day, closeH, 0);

    if (!now.isBefore(cutoff)) {
      return 0;
    }

    if (!currentExpiry.isBefore(cutoff)) {
      return 0;
    }

    final minutesToCutoff = cutoff.difference(currentExpiry).inMinutes;
    if (minutesToCutoff <= 0) return 0;

    return minutesToCutoff.clamp(0, 20);
  }

  /// Extends an active order's pickup expiration time by up to 20 minutes max (1-time extension allowed per order).
  /// Strictly persists to Firestore before updating local state and surfaces any failure to the caller.
  Future<int> extendOrderPickupTime(String orderId) async {
    final idx =
        _orders.indexWhere((o) => o.id == orderId || o.orderId == orderId);
    if (idx < 0) return 0;

    final order = _orders[idx];
    if (order.expiresAt == null || order.isExtended) return 0;

    final availableMinutes = getAvailableExtensionMinutes(
      order.expiresAt!,
      isExtended: order.isExtended,
      settings: _settings,
    );
    if (availableMinutes <= 0) return 0;

    final newExpiry = order.expiresAt!.add(Duration(minutes: availableMinutes));
    final newExtensionCount = order.extensionCount + 1;

    await FirebaseFirestore.instance.collection('orders').doc(order.id).update({
      'expiresAt': Timestamp.fromDate(newExpiry),
      'pickupEnd': Timestamp.fromDate(newExpiry),
      'isExtended': true,
      'extensionCount': newExtensionCount,
    });

    _orders[idx] = order.copyWith(
      expiresAt: newExpiry,
      pickupEnd: newExpiry,
      isExtended: true,
      extensionCount: newExtensionCount,
    );
    notifyListeners();
    return availableMinutes;
  }

  String _generate6CharAlphanumericId() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = math.Random();
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  int _computeReminderHours(List<CartItem> items, DateTime expiresAt) {
    final now = TimeService.now;
    final hoursUntilExpiry = expiresAt.difference(now).inHours;
    if (hoursUntilExpiry > 0) return hoursUntilExpiry;

    final hasPerishable = items.any((i) => i.isPerishable);
    final hasStandard = items.any((i) => !i.isPerishable);
    if (hasPerishable && hasStandard) return _settings.mixedWindowHours;
    if (hasPerishable) return _settings.perishableWindowHours;
    return _settings.standardWindowHours;
  }

  // ── Submit order (Reserve-Then-Pay) ────────────────────────────────────────

  /// Step 1 of Reserve-Then-Pay: atomically validates stock, reserves `reservedStock`,
  /// and writes an `awaitingPayment` order with a 15-minute payment timeout.
  Future<({PreOrder order, DateTime pickupExpiresAt})> reserveOrderForPayment({
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    required String location,
    required String pickupSlot,
    required List<Product> allProducts,
    String paymentMethod = 'GCash',
    String? notes,
  }) async {
    final now = TimeService.now;
    final parsedRange = StoreHours.parseSlotRange(pickupSlot, nowTime: now);
    final pickupStart = parsedRange?.start ??
        StoreHours.parseSlotTargetDateTime(pickupSlot, nowTime: now);
    final parsedEnd = parsedRange?.end ??
        StoreHours.parseSlotEndDateTime(pickupSlot, nowTime: now);
    final pickupExpiresAt = parsedEnd.isBefore(now)
        ? now.add(const Duration(minutes: StoreHours.prepBufferMinutes))
        : parsedEnd;

    final paymentDeadline = now.add(const Duration(minutes: 15));
    final sixCharOrderId = _generate6CharAlphanumericId();
    final breakdown = PricingEngine.calculate(
      items: _preCart,
      allProducts: allProducts,
    );
    final uid = FirebaseAuth.instance.currentUser?.uid;

    final reservedOrder = PreOrder(
      id: const Uuid().v4(),
      orderId: sixCharOrderId,
      customerId: uid,
      customerName: customerName,
      customerEmail: customerEmail,
      customerPhone: customerPhone,
      items: List.from(_preCart),
      tax: 0,
      total: breakdown.total,
      status: OrderStatus.awaitingPayment,
      paymentMethod: paymentMethod,
      paymentStatus: 'unpaid',
      isPaid: false,
      location: location,
      pickupTime: pickupSlot,
      pickupStart: pickupStart,
      pickupEnd: pickupExpiresAt,
      createdAt: now,
      expiresAt: paymentDeadline,
      notes: notes,
      reservationReleased: false,
    );

    await _fs.submitOrderTransactional(reservedOrder);
    return (order: reservedOrder, pickupExpiresAt: pickupExpiresAt);
  }

  /// Step 2 of Reserve-Then-Pay: transitions the reserved `awaitingPayment` order
  /// to `pending` (paid), schedules the reminder, and clears the cart.
  Future<PreOrder> confirmReservedOrderPayment({
    required PreOrder reservedOrder,
    required String paymentReference,
    required DateTime pickupExpiresAt,
  }) async {
    await _fs.confirmOrderPayment(
      orderId: reservedOrder.id,
      paymentReference: paymentReference,
      pickupExpiresAt: pickupExpiresAt,
    );

    final confirmedOrder = reservedOrder.copyWith(
      status: OrderStatus.pending,
      paymentStatus: 'paid',
      isPaid: true,
      paymentReference: paymentReference,
      expiresAt: pickupExpiresAt,
    );

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await _fs.addCustomerNotification(
        userId: uid,
        title: '🛍️ Purchase Successful',
        body:
            'Your pre-order ${confirmedOrder.orderId} (${formatPeso(confirmedOrder.total)}) was submitted successfully. Pickup time: ${confirmedOrder.pickupTime}.',
        type: 'order',
        relatedId: confirmedOrder.orderId,
      );
    }

    final reminderHours =
        _computeReminderHours(confirmedOrder.items, pickupExpiresAt);
    await NotificationService.schedulePerishableReminder(
      confirmedOrder.id,
      confirmedOrder.orderId,
      hours: reminderHours,
    );

    _preCart.clear();
    notifyListeners();
    return confirmedOrder;
  }

  /// Releases a reserved `awaitingPayment` order when payment fails or is cancelled,
  /// keeping the customer's cart intact so they can retry.
  Future<void> releaseUnpaidReservation(PreOrder reservedOrder) async {
    _lastOrderStatusMap[reservedOrder.id] = OrderStatus.cancelled;
    await _fs.cancelOrder(reservedOrder.id, reservedOrder.items);
  }

  Future<PreOrder> submitOrder({
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    required String location,
    required String pickupSlot,
    required List<Product> allProducts,
    String paymentMethod = 'GCash',
    String? paymentReference,
    String? notes,
  }) async {
    final now = TimeService.now;
    final parsedRange = StoreHours.parseSlotRange(pickupSlot, nowTime: now);
    final pickupStart = parsedRange?.start ??
        StoreHours.parseSlotTargetDateTime(pickupSlot, nowTime: now);
    final parsedEnd = parsedRange?.end ??
        StoreHours.parseSlotEndDateTime(pickupSlot, nowTime: now);
    final expiresAt = parsedEnd.isBefore(now)
        ? now.add(const Duration(minutes: StoreHours.prepBufferMinutes))
        : parsedEnd;

    final sixCharOrderId = _generate6CharAlphanumericId();
    final breakdown = PricingEngine.calculate(
      items: _preCart,
      allProducts: allProducts,
    );
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final hasPaidRef =
        paymentReference != null && paymentReference.trim().isNotEmpty;

    final order = PreOrder(
      id: const Uuid().v4(),
      orderId: sixCharOrderId,
      customerId: uid,
      customerName: customerName,
      customerEmail: customerEmail,
      customerPhone: customerPhone,
      items: List.from(_preCart),
      tax: 0,
      total: breakdown.total,
      status: OrderStatus.pending,
      paymentMethod: paymentMethod,
      paymentStatus: hasPaidRef ? 'paid' : 'unpaid',
      isPaid: hasPaidRef,
      paymentReference: paymentReference,
      location: location,
      pickupTime: pickupSlot,
      pickupStart: pickupStart,
      pickupEnd: expiresAt,
      createdAt: now,
      expiresAt: expiresAt,
      notes: notes,
      reservationReleased: false,
    );

    await _fs.submitOrderTransactional(order);

    if (uid != null) {
      await _fs.addCustomerNotification(
        userId: uid,
        title: '🛍️ Purchase Successful',
        body:
            'Your pre-order ${order.orderId} (${formatPeso(order.total)}) was submitted successfully. Pickup time: ${order.pickupTime}.',
        type: 'order',
        relatedId: order.orderId,
      );
    }

    final reminderHours = _computeReminderHours(order.items, expiresAt);
    await NotificationService.schedulePerishableReminder(
      order.id,
      order.orderId,
      hours: reminderHours,
    );

    _preCart.clear();
    notifyListeners();
    return order;
  }

  // ── Admin actions ──────────────────────────────────────────────────────────

  Future<void> advanceStatus(String orderId) async {
    throw UnsupportedError(
        'Order fulfillment transitions are handled exclusively by store staff in Admin-App.');
  }

  Future<void> refundOrder(String orderId) async {
    final order = _orders.firstWhere((o) => o.id == orderId);
    if (order.status == OrderStatus.refunded) return;

    await _fs.refundOrder(orderId, order.items);
    notifyListeners();
  }

  Future<void> requestRefund(
      String orderId, String reason, List<CartItem> itemsToRefund) async {
    final order = _orders.firstWhere((o) => o.id == orderId);

    // 1. Avoid Duplication (ignore previously cancelled or rejected requests)
    final existingRequests =
        await _fs.getRefundRequestsForTransaction(order.orderId);
    final hasActiveRequest = existingRequests.any(
      (r) =>
          r.status == RefundStatus.pending || r.status == RefundStatus.approved,
    );
    if (hasActiveRequest) {
      throw 'A refund request for this order is already being processed.';
    }

    final refundTotal =
        itemsToRefund.fold(0.0, (sum, item) => sum + (item.price * item.qty));
    final uid = order.customerId ?? FirebaseAuth.instance.currentUser?.uid;

    final req = RefundRequest(
      id: '',
      transactionId: order.orderId,
      customerId: uid,
      customerEmail: order.customerEmail,
      customerName: order.customerName,
      items: itemsToRefund,
      total: refundTotal,
      reason: reason,
      status: RefundStatus.pending,
      createdAt: TimeService.now,
    );

    await _fs.requestRefund(req);

    // 2. Notification after refund request
    await NotificationService.notifyAdminRefundRequest(
        order.orderId, order.customerName);

    // Update order status using standardized camelCase `refundRequested`
    await _fs.updateOrderStatus(orderId, OrderStatus.refundRequested);

    notifyListeners();
  }

  Future<void> cancelRefundRequest(
      {required String transactionId, String? requestId}) async {
    String reqId = requestId ?? '';
    if (reqId.isEmpty) {
      final reqs = await _fs.getRefundRequestsForTransaction(transactionId);
      final pending = reqs.where((r) => r.status == RefundStatus.pending);
      if (pending.isNotEmpty) {
        reqId = pending.first.id;
      }
    }

    await _fs.cancelRefundRequest(
        refundRequestId: reqId, transactionId: transactionId);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await _fs.addCustomerNotification(
        userId: uid,
        title: '🚫 Refund Request Cancelled',
        body:
            'Your refund request for #$transactionId was cancelled successfully.',
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

  /// Cancels an active order manually (by the user).
  Future<void> cancelOrder(PreOrder order) async {
    // Pre-set the status map to cancelled to prevent duplicate notification from stream listener
    _lastOrderStatusMap[order.id] = OrderStatus.cancelled;
    await _fs.cancelOrder(order.id, order.items);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await _fs.addCustomerNotification(
        userId: uid,
        title: '🚫 Order Cancelled',
        body: 'Your order ${order.orderId} has been cancelled successfully.',
        type: 'order',
        relatedId: order.orderId,
      );
    }

    await NotificationService.showSmsNotificationPopUp(
      title: '🚫 Order Cancelled',
      body: 'Your order ${order.orderId} has been cancelled.',
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    TimeService.instance.removeListener(_onTimeServiceChanged);
    _ordersSub?.cancel();
    _settingsSub?.cancel();
    _expirationTimer?.cancel();
    super.dispose();
  }
}
