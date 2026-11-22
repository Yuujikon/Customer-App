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
import './notification_service.dart';

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
  /// atomically decrements physical stock and increments reservedStock,
  /// and saves the order.
  /// Note: Firestore transactions require ALL reads to be executed before ANY writes.
  Future<void> submitOrderTransactional(PreOrder order) {
    return _db.runTransaction((transaction) async {
      // 1. ALL READS FIRST: Read product snapshots for all items in order
      final List<Map<String, dynamic>> itemReadData = [];

      for (final item in order.items) {
        final productRef = _products.doc(item.productId);
        final productSnap = await transaction.get(productRef);

        if (!productSnap.exists) {
          throw 'Product ${item.name} not found.';
        }

        final data = productSnap.data() as Map<String, dynamic>;
        itemReadData.add({
          'ref': productRef,
          'item': item,
          'data': data,
        });
      }

      // 2. ALL VALIDATIONS & PREPARATIONS
      final List<Map<String, dynamic>> pendingUpdates = [];

      for (final read in itemReadData) {
        final DocumentReference productRef = read['ref'];
        final CartItem item = read['item'];
        final Map<String, dynamic> data = read['data'];

        final hasVariantsOnServer =
            data['variants'] != null && (data['variants'] as Map).isNotEmpty;

        if (item.variantId != null) {
          final variants = data['variants'] as Map<String, dynamic>?;
          final variant = variants?[item.variantId] as Map<String, dynamic>?;
          if (variant == null) {
            throw 'Flavor ${item.variantName} for ${item.name} is no longer available.';
          }

          final currentStock = (variant['stock'] as num? ?? 0).toInt();
          final reservedStock = (variant['reservedStock'] as num? ?? 0).toInt();
          final availableStock = currentStock - reservedStock;

          if (availableStock < item.qty) {
            throw 'Insufficient stock for ${item.name} (${item.variantName}). Only ${availableStock < 0 ? 0 : availableStock} available.';
          }

          pendingUpdates.add({
            'ref': productRef,
            'update': {
              'variants.${item.variantId}.reservedStock':
                  FieldValue.increment(item.qty),
            },
          });
        } else {
          if (hasVariantsOnServer) {
            throw 'Please select a flavor for ${item.name}.';
          }

          final currentStock = (data['stock'] as num? ?? 0).toInt();
          final reservedStock = (data['reservedStock'] as num? ?? 0).toInt();
          final availableStock = currentStock - reservedStock;

          if (availableStock < item.qty) {
            throw 'Insufficient stock for ${item.name}. Only ${availableStock < 0 ? 0 : availableStock} available.';
          }

          pendingUpdates.add({
            'ref': productRef,
            'update': {
              'reservedStock': FieldValue.increment(item.qty),
            },
          });
        }
      }

      // 3. ALL WRITES AT THE END: Apply product stock updates & create order document
      for (final pUpdate in pendingUpdates) {
        final ref = pUpdate['ref'] as DocumentReference;
        final updateData = pUpdate['update'] as Map<String, dynamic>;
        transaction.update(ref, updateData);
      }

      // Save the order
      final orderRef = _orders.doc(order.id);
      transaction.set(orderRef, order.toFirestore());
    });
  }

  /// Cancels an active order without restoring or incrementing available stock.
  Future<void> cancelOrder(String orderId, List<CartItem> items) {
    final batch = _db.batch();

    // Mark as cancelled (do not alter stock or reservedStock)
    batch.update(_orders.doc(orderId), {'status': OrderStatus.cancelled.name});

    return batch.commit();
  }

  /// Fulfills/collects an order and clears reserved stock tracking.
  Future<void> collectOrder(String orderId, List<CartItem> items) {
    final batch = _db.batch();

    batch.update(_orders.doc(orderId), {'status': OrderStatus.collected.name});

    for (final item in items) {
      final docRef = _products.doc(item.productId);
      if (item.variantId != null) {
        batch.update(docRef, {
          'variants.${item.variantId}.reservedStock':
              FieldValue.increment(-item.qty),
        });
      } else {
        batch.update(docRef, {
          'reservedStock': FieldValue.increment(-item.qty),
        });
      }
    }

    return batch.commit();
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

    // 2. Restock items
    for (final item in items) {
      final docRef = _products.doc(item.productId);
      if (item.variantId != null) {
        batch.update(docRef, {
          'variants.${item.variantId}.stock': FieldValue.increment(item.qty),
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

    // 2. Restock items
    for (final item in items) {
      final docRef = _products.doc(item.productId);
      if (item.variantId != null) {
        batch.update(docRef, {
          'variants.${item.variantId}.stock': FieldValue.increment(item.qty),
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
      batch.delete(_refundQueue.doc(refundRequestId));
    } else {
      final snap = await _refundQueue
          .where('transactionId', isEqualTo: transactionId)
          .where('status', isEqualTo: RefundStatus.pending.name)
          .get();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
    }

    final orderSnap =
        await _orders.where('orderId', isEqualTo: transactionId).get();
    for (final doc in orderSnap.docs) {
      batch.update(doc.reference, {'status': OrderStatus.collected.name});
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

  /// Records a ghosting offense for a customer when an order expires uncollected.
  /// Penalty ladder:
  /// - 1st Offense: 2-hour order restriction
  /// - 2nd Offense: 24-hour order restriction
  /// - 3rd Offense: 72-hour (3-day) order restriction
  /// - 4th Offense: Permanent lock
  Future<void> recordGhostingOffense({
    String? userId,
    required String userEmail,
    required String orderId,
    required String sixCharOrderId,
  }) async {
    DocumentReference? userRef;
    Map<String, dynamic> userData = {};

    if (userId != null && userId.isNotEmpty) {
      userRef = _db.collection('users').doc(userId);
      final snap = await userRef.get();
      if (snap.exists) {
        userData = snap.data() as Map<String, dynamic>;
      } else {
        userRef = null;
      }
    }

    if (userRef == null && userEmail.isNotEmpty) {
      final query = await _db
          .collection('users')
          .where('email', isEqualTo: userEmail)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        userRef = query.docs.first.reference;
        userData = query.docs.first.data();
      }
    }

    if (userRef == null) {
      debugPrint('No user found for ghosting offense (email: $userEmail)');
      return;
    }

    final String targetUid = userRef.id;

    final List ghostedOrders = userData['ghostedOrders'] as List? ?? [];
    if (ghostedOrders.contains(orderId) ||
        ghostedOrders.contains(sixCharOrderId)) {
      return;
    }

    final currentOffenses = (userData['offenseCount'] as num? ?? 0).toInt();
    final newOffenseCount = currentOffenses + 1;

    DateTime? restrictionUntil;
    bool isPermanentlyLocked = false;
    String restrictionMsg = '';

    if (newOffenseCount == 1) {
      restrictionUntil = TimeService.now.add(const Duration(hours: 2));
      restrictionMsg = '2-hour order restriction';
    } else if (newOffenseCount == 2) {
      restrictionUntil = TimeService.now.add(const Duration(hours: 24));
      restrictionMsg = '24-hour order restriction';
    } else if (newOffenseCount == 3) {
      restrictionUntil = TimeService.now.add(const Duration(hours: 72));
      restrictionMsg = '72-hour (3-day) order restriction';
    } else {
      isPermanentlyLocked = true;
      restrictionMsg = 'Permanent account lock';
    }

    await userRef.update({
      'offenseCount': newOffenseCount,
      'restrictedUntil': restrictionUntil != null
          ? Timestamp.fromDate(restrictionUntil)
          : null,
      'restrictionUntil': restrictionUntil != null
          ? Timestamp.fromDate(restrictionUntil)
          : null,
      'isPermanentlyLocked': isPermanentlyLocked,
      'lastOffenseAt': FieldValue.serverTimestamp(),
      'ghostedOrders': FieldValue.arrayUnion([orderId, sixCharOrderId]),
    });

    final String title = isPermanentlyLocked
        ? '⛔ Account Permanently Locked'
        : '⚠️ Ghosted Order Penalty ($newOffenseCount/4 Offenses)';
    final String body = isPermanentlyLocked
        ? 'Your order #$sixCharOrderId expired without collection. Your account is permanently locked from placing orders ($newOffenseCount offenses). You may submit an appeal.'
        : 'Your order #$sixCharOrderId expired without collection. Penalty: $restrictionMsg. You cannot place pre-orders during this period.';

    await addCustomerNotification(
      userId: targetUid,
      title: title,
      body: body,
      type: 'offense',
      relatedId: orderId,
    );

    NotificationService.showSmsNotificationPopUp(
      title: title,
      body: body,
    );
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

    // 1. Update appeal document
    final appealRef = _appeals.doc(appeal.id);
    batch.update(appealRef, {
      'status': 'approved',
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

  /// Fixes/syncs any existing approved appeals where the user's restriction was not cleared yet.
  Future<void> syncApprovedAppeals() async {
    try {
      final approvedDocs =
          await _appeals.where('status', isEqualTo: 'approved').get();
      for (final doc in approvedDocs.docs) {
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
