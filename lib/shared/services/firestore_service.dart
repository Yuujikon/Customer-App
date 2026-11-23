import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../models/order.dart';
import '../models/transaction.dart';
import '../models/expense.dart';
import '../models/refund_request.dart';
import '../models/bundle.dart';
import '../models/store_settings.dart';
import '../models/customer_appeal.dart';
import './time_service.dart';

class FirestoreService {
  final FirebaseFirestore _db;

  FirestoreService() : _db = FirebaseFirestore.instance {
    try {
      _db.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes:
            10485760, // 10MB bounded cache to prevent Binder IPC buffer overflow
      );
    } catch (_) {
      // Settings can only be set before any Firestore operations or if already configured
    }
  }

  // ── Collections ────────────────────────────────────────────────────────────
  CollectionReference get _products => _db.collection('products');
  CollectionReference get _orders => _db.collection('orders');
  CollectionReference get _transactions => _db.collection('transactions');
  CollectionReference get _expenses => _db.collection('expenses');
  CollectionReference get _refundQueue => _db.collection('refund_requests');
  CollectionReference get _watches => _db.collection('watched_products');
  CollectionReference get _bundles => _db.collection('bundles');
  CollectionReference get _appeals => _db.collection('appeals');
  DocumentReference get _settings =>
      _db.collection('settings').doc('store_settings');

  // ── Store Settings ─────────────────────────────────────────────────────────

  Stream<StoreSettings> settingsStream() =>
      _settings.snapshots().map(StoreSettings.fromFirestore);

  Future<void> updateSettings(StoreSettings s) =>
      _settings.set(s.toFirestore(), SetOptions(merge: true));

  Future<void> logStockAudit({
    required String productId,
    required String productName,
    required int previousStock,
    required int newStock,
    required String reason,
    String? operatorEmail,
  }) {
    return _db.collection('stock_audits').add({
      'productId': productId,
      'productName': productName,
      'previousStock': previousStock,
      'newStock': newStock,
      'delta': newStock - previousStock,
      'reason': reason,
      'operatorEmail': operatorEmail ?? 'system_automation',
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // ── Products ───────────────────────────────────────────────────────────────

  // Real-time stream — widgets rebuild automatically on changes
  Stream<List<Product>> productsStream() => _products
      .orderBy('name')
      .snapshots()
      .map((s) => s.docs.map(Product.fromFirestore).toList());

  Future<void> addProduct(Product p) => _products.add(p.toFirestore());

  Future<void> updateProduct(Product p) =>
      _products.doc(p.id).update(p.toFirestore());

  Future<void> updateStock(String productId, int newStock) =>
      _products.doc(productId).update({'stock': newStock});

  // Atomic batch: decrement stock for all cart items at once
  Future<void> decrementStockBatch(List<CartItem> items) {
    final batch = _db.batch();
    for (final item in items) {
      final docRef = _products.doc(item.productId);
      if (item.variantId != null) {
        batch.update(docRef, {
          'variants.${item.variantId}.stock': FieldValue.increment(-item.qty),
        });
      } else {
        batch.update(docRef, {
          'stock': FieldValue.increment(-item.qty),
        });
      }
    }
    return batch.commit();
  }

  // ── Orders ─────────────────────────────────────────────────────────────────

  Stream<List<PreOrder>> ordersStream() => _orders
      .snapshots()
      .map((s) => s.docs.map(PreOrder.fromFirestore).toList());

  Stream<List<PreOrder>> ordersStreamForEmail(String email, {int limit = 50}) =>
      _orders
          .where('customerEmail', isEqualTo: email)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((s) => s.docs.map(PreOrder.fromFirestore).toList());

  /// Atomic checkout transaction:
  /// Verifies available stock (stock - reservedStock),
  /// atomically increments reservedStock (on variant or top-level product),
  /// and saves the order with `reservationReleased: false`.
  /// Note: Firestore transactions require ALL reads to be executed before ANY writes.
  Future<void> submitOrderTransactional(PreOrder order) {
    return _db.runTransaction((transaction) async {
      // 1. ALL READS FIRST: Deduplicate product doc reads
      final Map<String, DocumentReference> productRefs = {};
      final Map<String, Map<String, dynamic>> productDataById = {};

      for (final item in order.items) {
        if (!productRefs.containsKey(item.productId)) {
          final productRef = _products.doc(item.productId);
          final productSnap = await transaction.get(productRef);
          if (!productSnap.exists) {
            throw 'Product ${item.name} not found.';
          }
          productRefs[item.productId] = productRef;
          productDataById[item.productId] =
              productSnap.data() as Map<String, dynamic>;
        }
      }

      // 2. ALL VALIDATIONS & AGGREGATED PREPARATIONS
      // Aggregate requested quantities per (productId, variantId)
      final Map<String, Map<String, int>> requestedByProductField = {};
      final Map<String, Map<String, String>> labelByProductField = {};

      for (final item in order.items) {
        final data = productDataById[item.productId]!;
        if ((data['status']?.toString() ?? 'published') == 'archived') {
          throw '${item.name} is no longer available.';
        }
        if (data['isQuarantined'] == true) {
          throw '${item.name} is temporarily unavailable.';
        }

        final hasVariantsOnServer =
            data['variants'] != null && (data['variants'] as Map).isNotEmpty;

        if (item.variantId != null) {
          final variants = data['variants'] as Map<String, dynamic>?;
          final variant = variants?[item.variantId] as Map<String, dynamic>?;
          if (variant == null) {
            throw 'Flavor ${item.variantName} for ${item.name} is no longer available.';
          }
          final fieldKey = 'variants.${item.variantId}.reservedStock';
          requestedByProductField.putIfAbsent(item.productId, () => {});
          requestedByProductField[item.productId]![fieldKey] =
              (requestedByProductField[item.productId]![fieldKey] ?? 0) +
                  item.qty;
          labelByProductField.putIfAbsent(item.productId, () => {});
          labelByProductField[item.productId]![fieldKey] =
              '${item.name} (${item.variantName ?? item.variantId})';
        } else {
          if (hasVariantsOnServer) {
            throw 'Please select a flavor for ${item.name}.';
          }
          const fieldKey = 'reservedStock';
          requestedByProductField.putIfAbsent(item.productId, () => {});
          requestedByProductField[item.productId]![fieldKey] =
              (requestedByProductField[item.productId]![fieldKey] ?? 0) +
                  item.qty;
          labelByProductField.putIfAbsent(item.productId, () => {});
          labelByProductField[item.productId]![fieldKey] = item.name;
        }
      }

      final Map<DocumentReference, Map<String, dynamic>> pendingUpdates = {};

      for (final entry in requestedByProductField.entries) {
        final productId = entry.key;
        final data = productDataById[productId]!;
        final productRef = productRefs[productId]!;
        final updates = <String, dynamic>{};

        for (final fieldEntry in entry.value.entries) {
          final fieldKey = fieldEntry.key;
          final totalQty = fieldEntry.value;
          final label = labelByProductField[productId]![fieldKey]!;

          if (fieldKey == 'reservedStock') {
            final currentStock = (data['stock'] as num? ?? 0).toInt();
            final reservedStock = (data['reservedStock'] as num? ?? 0).toInt();
            final availableStock = currentStock - reservedStock;
            if (availableStock < totalQty) {
              throw 'Insufficient stock for $label. Only ${availableStock < 0 ? 0 : availableStock} available.';
            }
          } else {
            // variants.<id>.reservedStock
            final variantId = fieldKey.split('.')[1];
            final variants = data['variants'] as Map<String, dynamic>;
            final variant = variants[variantId] as Map<String, dynamic>;
            final currentStock = (variant['stock'] as num? ?? 0).toInt();
            final reservedStock =
                (variant['reservedStock'] as num? ?? 0).toInt();
            final availableStock = currentStock - reservedStock;
            if (availableStock < totalQty) {
              throw 'Insufficient stock for $label. Only ${availableStock < 0 ? 0 : availableStock} available.';
            }
          }

          updates[fieldKey] = FieldValue.increment(totalQty);
        }

        pendingUpdates[productRef] = updates;
      }

      // 3. ALL WRITES AT THE END: Apply product reservations & create order document
      for (final entry in pendingUpdates.entries) {
        transaction.update(entry.key, entry.value);
      }

      final orderRef = _orders.doc(order.id);
      transaction.set(orderRef, order.toFirestore());
    });
  }

  /// Confirms payment on a reserved `awaitingPayment` order, transitioning it to `pending`
  /// with the scheduled pickup expiration time.
  Future<void> confirmOrderPayment({
    required String orderId,
    required String paymentReference,
    required DateTime pickupExpiresAt,
  }) {
    return _db.runTransaction((transaction) async {
      final orderRef = _orders.doc(orderId);
      final orderSnap = await transaction.get(orderRef);
      if (!orderSnap.exists) {
        throw 'Order not found.';
      }
      final data = orderSnap.data() as Map<String, dynamic>;
      final status = data['status']?.toString() ?? '';
      if (status == OrderStatus.cancelled.name ||
          data['reservationReleased'] == true) {
        throw 'This order reservation expired or was cancelled before payment completed.';
      }
      if (status != OrderStatus.awaitingPayment.name) {
        return; // Already confirmed
      }

      transaction.update(orderRef, {
        'status': OrderStatus.pending.name,
        'paymentStatus': 'paid',
        'isPaid': true,
        'paymentReference': paymentReference,
        'expiresAt': Timestamp.fromDate(pickupExpiresAt),
      });
    });
  }

  /// Cancels an active order and idempotently releases its reservedStock once inside a transaction.
  Future<void> cancelOrder(String orderId, List<CartItem> items) {
    return _db.runTransaction((transaction) async {
      final orderRef = _orders.doc(orderId);
      final orderSnap = await transaction.get(orderRef);
      if (!orderSnap.exists) return;

      final orderData = orderSnap.data() as Map<String, dynamic>;
      final currentStatus = orderData['status']?.toString() ?? '';
      if (currentStatus == OrderStatus.collected.name ||
          currentStatus == OrderStatus.refunded.name) {
        return; // Never cancel or release stock for collected/refunded orders
      }
      if (orderData['reservationReleased'] == true) {
        if (currentStatus != OrderStatus.cancelled.name) {
          transaction.update(orderRef, {'status': OrderStatus.cancelled.name});
        }
        return;
      }

      final rawItems = (orderData['items'] as List?)
              ?.map((e) => CartItem.fromMap(e))
              .toList() ??
          items;

      // Aggregate quantities to release per product/variant
      final Map<String, Map<String, int>> releaseByProductField = {};
      for (final item in rawItems) {
        if (item.productId.isEmpty || item.qty <= 0) continue;
        final fieldKey = item.variantId != null
            ? 'variants.${item.variantId}.reservedStock'
            : 'reservedStock';
        releaseByProductField.putIfAbsent(item.productId, () => {});
        releaseByProductField[item.productId]![fieldKey] =
            (releaseByProductField[item.productId]![fieldKey] ?? 0) + item.qty;
      }

      // ALL READS BEFORE WRITES
      final Map<String, DocumentSnapshot> productSnaps = {};
      for (final productId in releaseByProductField.keys) {
        productSnaps[productId] = await transaction.get(_products.doc(productId));
      }

      // ALL WRITES
      for (final entry in releaseByProductField.entries) {
        final productSnap = productSnaps[entry.key];
        if (productSnap == null || !productSnap.exists) continue;
        final pData = productSnap.data() as Map<String, dynamic>? ?? {};
        final updates = <String, dynamic>{};

        for (final fieldEntry in entry.value.entries) {
          final fieldKey = fieldEntry.key;
          final qtyToRelease = fieldEntry.value;
          int currentReserved = 0;

          if (fieldKey == 'reservedStock') {
            currentReserved = (pData['reservedStock'] as num? ?? 0).toInt();
          } else {
            final variantId = fieldKey.split('.')[1];
            final variants = pData['variants'] as Map<String, dynamic>?;
            final variant = variants?[variantId] as Map<String, dynamic>?;
            if (variant == null) continue;
            currentReserved = (variant['reservedStock'] as num? ?? 0).toInt();
          }

          final safeRelease =
              currentReserved >= qtyToRelease ? qtyToRelease : currentReserved;
          if (safeRelease > 0) {
            updates[fieldKey] = FieldValue.increment(-safeRelease);
          }
        }

        if (updates.isNotEmpty) {
          transaction.update(productSnap.reference, updates);
        }
      }

      transaction.update(orderRef, {
        'status': OrderStatus.cancelled.name,
        'reservationReleased': true,
      });
    });
  }

  /// Order collection and physical stock fulfillment are owned exclusively by Admin-App.
  Future<void> collectOrder(String orderId, List<CartItem> items) {
    throw UnsupportedError(
        'Order collection is handled exclusively by store staff in Admin-App.');
  }

  Future<void> updateOrderStatus(String orderId, OrderStatus status) =>
      _orders.doc(orderId).update({'status': status.name});

  // ── Transactions ───────────────────────────────────────────────────────────

  Stream<List<StoreTransaction>> transactionsStream() => _transactions
      .snapshots()
      .map((s) => s.docs.map(StoreTransaction.fromFirestore).toList());

  Future<void> addTransaction(StoreTransaction tx) =>
      _transactions.add(tx.toFirestore());

  Future<void> refundTransaction(String transactionId, List<CartItem> items) {
    final batch = _db.batch();

    // 1. Mark transaction as refunded
    batch.update(_transactions.doc(transactionId), {'isRefunded': true});

    // 2. Restock items (including top-level stock for variant products)
    for (final item in items) {
      final docRef = _products.doc(item.productId);
      if (item.variantId != null) {
        batch.update(docRef, {
          'variants.${item.variantId}.stock': FieldValue.increment(item.qty),
          'stock': FieldValue.increment(item.qty),
        });
      } else {
        batch.update(docRef, {
          'stock': FieldValue.increment(item.qty),
        });
      }
    }

    return batch.commit();
  }

  Future<void> refundOrder(String orderId, List<CartItem> items) {
    final batch = _db.batch();

    // 1. Update order status to refunded
    batch.update(_orders.doc(orderId), {'status': OrderStatus.refunded.name});

    // 2. Restock items (including top-level stock for variant products)
    for (final item in items) {
      final docRef = _products.doc(item.productId);
      if (item.variantId != null) {
        batch.update(docRef, {
          'variants.${item.variantId}.stock': FieldValue.increment(item.qty),
          'stock': FieldValue.increment(item.qty),
        });
      } else {
        batch.update(docRef, {
          'stock': FieldValue.increment(item.qty),
        });
      }
    }

    return batch.commit();
  }

  // ── Expenses ───────────────────────────────────────────────────────────────

  Stream<List<Expense>> expensesStream() => _expenses
      .snapshots()
      .map((s) => s.docs.map(Expense.fromFirestore).toList());

  Future<void> addExpense(Expense e) => _expenses.add(e.toFirestore());

  // ── Refund Queue ───────────────────────────────────────────────────────────

  Future<void> requestRefund(RefundRequest req) {
    return _refundQueue.add(req.toFirestore());
  }

  Future<List<RefundRequest>> getRefundRequestsForTransaction(
      String txId) async {
    final snap =
        await _refundQueue.where('transactionId', isEqualTo: txId).get();
    return snap.docs.map(RefundRequest.fromFirestore).toList();
  }

  Stream<List<RefundRequest>> refundRequestsStreamForEmail(String email) =>
      _refundQueue
          .where('customerEmail', isEqualTo: email)
          .snapshots()
          .map((s) => s.docs.map(RefundRequest.fromFirestore).toList());

  Future<void> cancelRefundRequest(
      {required String refundRequestId, required String transactionId}) async {
    final batch = _db.batch();

    if (refundRequestId.isNotEmpty) {
      batch.update(_refundQueue.doc(refundRequestId), {
        'status': RefundStatus.cancelled.name,
      });
    } else {
      final snap = await _refundQueue
          .where('transactionId', isEqualTo: transactionId)
          .where('status', isEqualTo: RefundStatus.pending.name)
          .get();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {
          'status': RefundStatus.cancelled.name,
        });
      }
    }

    final orderSnap =
        await _orders.where('orderId', isEqualTo: transactionId).get();
    for (final doc in orderSnap.docs) {
      final d = doc.data() as Map<String, dynamic>? ?? {};
      final status = d['status']?.toString() ?? '';
      if (status == OrderStatus.refundRequested.name ||
          status == 'refund_requested') {
        batch.update(doc.reference, {'status': OrderStatus.collected.name});
      }
    }

    return batch.commit();
  }

  // ── Product Watches & Restock Notifications ─────────────────────────────────

  /// Toggles customer ID/email in product's notifyUserIds array using FieldValue.arrayUnion/arrayRemove
  Future<void> toggleRestockNotification({
    required String productId,
    required String userId,
    required bool isCurrentlyNotifying,
  }) {
    final docRef = _products.doc(productId);
    if (isCurrentlyNotifying) {
      return docRef.update({
        'notifyUserIds': FieldValue.arrayRemove([userId]),
      });
    } else {
      return docRef.update({
        'notifyUserIds': FieldValue.arrayUnion([userId]),
      });
    }
  }

  Future<void> watchProduct(String productId, String email) {
    final id =
        '${productId}_${email.replaceAll('@', '_').replaceAll('.', '_')}';
    return _watches.doc(id).set({
      'productId': productId,
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<bool> isWatching(String productId, String email) async {
    final id =
        '${productId}_${email.replaceAll('@', '_').replaceAll('.', '_')}';
    final doc = await _watches.doc(id).get();
    return doc.exists;
  }

  // ── Bundles ────────────────────────────────────────────────────────────────

  Stream<List<ProductBundle>> bundlesStream() => _bundles
      .where('isActive', isEqualTo: true)
      .snapshots()
      .map((s) => s.docs.map(ProductBundle.fromFirestore).toList());

  // ── In-Store Customer Notifications ───────────────────────────────────────

  Future<void> addCustomerNotification({
    required String userId,
    required String title,
    required String body,
    required String type,
    String? relatedId,
  }) {
    return _db.collection('users').doc(userId).collection('notifications').add({
      'title': title,
      'body': body,
      'timestamp': FieldValue.serverTimestamp(),
      'type': type,
      'isRead': false,
      if (relatedId != null) 'relatedId': relatedId,
    });
  }

  // ── Ghosting Offenses & Appeals ───────────────────────────────────────────

  /// Ghosting offense penalties are recorded exclusively by Admin-App
  /// (customer clients are blocked by Firestore rules from mutating offense fields).
  Future<void> recordGhostingOffense({
    String? userId,
    required String userEmail,
    required String orderId,
    required String sixCharOrderId,
  }) async {
    debugPrint(
        'Skipping client-side ghosting offense write for order $sixCharOrderId (managed by Admin-App).');
  }

  Future<void> submitAppeal(CustomerAppeal appeal) {
    return _appeals.add(appeal.toFirestore());
  }

  Stream<List<CustomerAppeal>> appealsStreamForUser(String userId) {
    return _appeals
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((s) => s.docs.map(CustomerAppeal.fromFirestore).toList());
  }

  Stream<List<CustomerAppeal>> allPendingAppealsStream() {
    return _appeals
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((s) => s.docs.map(CustomerAppeal.fromFirestore).toList());
  }

  Future<void> approveAppeal(CustomerAppeal appeal, String adminEmail) async {
    final batch = _db.batch();

    // 1. Update appeal document and mark applied
    final appealRef = _appeals.doc(appeal.id);
    batch.update(appealRef, {
      'status': 'approved',
      'applied': true,
      'reviewedAt': Timestamp.fromDate(TimeService.now),
      'reviewedByEmail': adminEmail,
    });

    // 2. Locate user document (try by userId first, then email)
    DocumentReference? userRef;
    Map<String, dynamic> userData = {};

    if (appeal.userId.isNotEmpty) {
      final snap = await _db.collection('users').doc(appeal.userId).get();
      if (snap.exists) {
        userRef = snap.reference;
        userData = snap.data() as Map<String, dynamic>;
      }
    }

    if (userRef == null && appeal.customerEmail.isNotEmpty) {
      final query = await _db
          .collection('users')
          .where('email', isEqualTo: appeal.customerEmail)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        userRef = query.docs.first.reference;
        userData = query.docs.first.data();
      }
    }

    if (userRef != null) {
      final currentOffenses =
          (userData['offenseCount'] as num? ?? appeal.offenseCount).toInt();
      final newOffenseCount = currentOffenses > 0 ? currentOffenses - 1 : 0;

      // Decrement offense count by 1 AND lift restriction immediately
      batch.update(userRef, {
        'offenseCount': newOffenseCount,
        'restrictedUntil': null,
        'restrictionUntil': null,
        'isPermanentlyLocked': false,
      });

      // Send customer notification
      await addCustomerNotification(
        userId: userRef.id,
        title: '🎉 Appeal Approved & Restriction Lifted',
        body:
            'Your appeal has been approved by store management. Your offense tier has been reduced to $newOffenseCount and your restriction has been lifted!',
        type: 'appeal_approved',
      );
    }

    await batch.commit();
  }

  /// Fixes/syncs any existing approved appeals not yet marked `applied: true`.
  Future<void> syncApprovedAppeals() async {
    try {
      final approvedDocs =
          await _appeals.where('status', isEqualTo: 'approved').get();
      for (final doc in approvedDocs.docs) {
        final raw = doc.data() as Map<String, dynamic>? ?? {};
        if (raw['applied'] == true) continue;

        final appeal = CustomerAppeal.fromFirestore(doc);
        DocumentReference? userRef;
        Map<String, dynamic> userData = {};

        if (appeal.userId.isNotEmpty) {
          final snap = await _db.collection('users').doc(appeal.userId).get();
          if (snap.exists) {
            userRef = snap.reference;
            userData = snap.data() as Map<String, dynamic>;
          }
        }

        if (userRef == null && appeal.customerEmail.isNotEmpty) {
          final query = await _db
              .collection('users')
              .where('email', isEqualTo: appeal.customerEmail)
              .limit(1)
              .get();
          if (query.docs.isNotEmpty) {
            userRef = query.docs.first.reference;
            userData = query.docs.first.data();
          }
        }

        if (userRef != null) {
          final rawUntil =
              userData['restrictedUntil'] ?? userData['restrictionUntil'];
          final isLocked = userData['isPermanentlyLocked'] == true;

          if (rawUntil != null || isLocked) {
            final currentOffenses =
                (userData['offenseCount'] as num? ?? appeal.offenseCount)
                    .toInt();
            final newOffenseCount =
                currentOffenses > 0 ? currentOffenses - 1 : 0;

            await userRef.update({
              'offenseCount': newOffenseCount,
              'restrictedUntil': null,
              'restrictionUntil': null,
              'isPermanentlyLocked': false,
            });
          }
        }

        await doc.reference.update({'applied': true});
      }
    } catch (e) {
      debugPrint('Error syncing approved appeals: $e');
    }
  }

  Future<void> rejectAppeal(String appealId, String adminEmail,
      {String? adminNotes}) {
    return _appeals.doc(appealId).update({
      'status': 'rejected',
      'reviewedAt': Timestamp.fromDate(TimeService.now),
      'reviewedByEmail': adminEmail,
      if (adminNotes != null) 'adminNotes': adminNotes,
    });
  }
}
