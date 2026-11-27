import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../../core/utils/inventory_allocation.dart';
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

  Future<List<Product>> fetchProductsFromServer() async {
    try {
      final snap = await _products
          .orderBy('name')
          .get(const GetOptions(source: Source.server));
      return snap.docs.map(Product.fromFirestore).toList();
    } catch (_) {
      final snap = await _products.orderBy('name').get();
      return snap.docs.map(Product.fromFirestore).toList();
    }
  }

  Future<void> addProduct(Product p) => _products.add(p.toFirestore());

  Future<void> updateProduct(Product p) =>
      _products.doc(p.id).update(p.toFirestore());

  Future<void> updateStock(
    String productId,
    int newStock, {
    int? physicalReserve,
  }) =>
      _products.doc(productId).update({
        'stock': newStock,
        if (physicalReserve != null) 'physicalReserve': physicalReserve,
      });

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
  /// atomically increments reservedStock (aggregated per product doc),
  /// and saves the order.
  /// Note: Firestore transactions require ALL reads to be executed before ANY writes.
  Future<void> submitOrderTransactional(PreOrder order) {
    return _db.runTransaction((transaction) async {
      // 1. ALL READS FIRST: Deduplicate product document reads by productId
      final Map<String, DocumentReference> productRefs = {};
      final Map<String, Map<String, dynamic>> productDataById = {};

      for (final item in order.items) {
        if (productDataById.containsKey(item.productId)) continue;
        final productRef = _products.doc(item.productId);
        final productSnap = await transaction.get(productRef);

        if (!productSnap.exists) {
          throw 'Product ${item.name} not found.';
        }

        productRefs[item.productId] = productRef;
        productDataById[item.productId] =
            productSnap.data() as Map<String, dynamic>;
      }

      // 2. ALL VALIDATIONS & AGGREGATED PREPARATIONS
      // Aggregate requested quantities per (productId, variantId) so duplicate
      // items or multiple variants on the same product are validated accurately
      // and written in a single transaction.update() per product document.
      final Map<String, int> requestedByKey = {};
      final Map<String, CartItem> representativeItemByKey = {};

      for (final item in order.items) {
        final key = '${item.productId}::${item.variantId ?? ''}';
        requestedByKey[key] = (requestedByKey[key] ?? 0) + item.qty;
        representativeItemByKey[key] = item;
      }

      final Map<String, Map<String, dynamic>> updatesByProductId = {};

      for (final entry in requestedByKey.entries) {
        final totalQty = entry.value;
        final item = representativeItemByKey[entry.key]!;
        final data = productDataById[item.productId]!;

        if (data['isQuarantined'] == true) {
          throw '${item.name} is currently unavailable.';
        }

        final hasVariantsOnServer =
            data['variants'] != null && (data['variants'] as Map).isNotEmpty;

        final productUpdates =
            updatesByProductId.putIfAbsent(item.productId, () => {});

        if (item.variantId != null && item.variantId!.isNotEmpty) {
          final variants = data['variants'] as Map<String, dynamic>?;
          final variant = variants?[item.variantId] as Map<String, dynamic>?;
          if (variant == null) {
            throw 'Flavor ${item.variantName} for ${item.name} is no longer available.';
          }

          final currentStock = (variant['stock'] as num? ?? 0).toInt();
          final reservedStock =
              ((variant['reservedStock'] as num? ?? 0).toInt())
                  .clamp(0, currentStock > 0 ? currentStock : 0);
          final int? storedReserve =
              (variant['physicalReserve'] as num?)?.toInt();
          final int physicalReserve =
              InventoryAllocation.resolvePhysicalReserve(
            totalStock: currentStock,
            storedPhysicalReserve: storedReserve,
          );
          final int onlineAvailable =
              InventoryAllocation.calculateOnlineAvailable(
            totalStock: currentStock,
            physicalReserve: physicalReserve,
            reservedStock: reservedStock,
          );

          if (onlineAvailable <= 0) {
            throw '${item.name} (${item.variantName}) is currently out of stock.';
          }

          if (onlineAvailable < totalQty) {
            throw 'Only $onlineAvailable left in stock for ${item.name} (${item.variantName}).';
          }

          productUpdates['variants.${item.variantId}.reservedStock'] =
              FieldValue.increment(totalQty);
        } else {
          if (hasVariantsOnServer) {
            throw 'Please select a flavor for ${item.name}.';
          }

          final currentStock = (data['stock'] as num? ?? 0).toInt();
          final reservedStock = ((data['reservedStock'] as num? ?? 0).toInt())
              .clamp(0, currentStock > 0 ? currentStock : 0);
          final int? storedReserve = (data['physicalReserve'] as num?)?.toInt();
          final int physicalReserve =
              InventoryAllocation.resolvePhysicalReserve(
            totalStock: currentStock,
            storedPhysicalReserve: storedReserve,
          );
          final int onlineAvailable =
              InventoryAllocation.calculateOnlineAvailable(
            totalStock: currentStock,
            physicalReserve: physicalReserve,
            reservedStock: reservedStock,
          );

          if (onlineAvailable <= 0) {
            throw '${item.name} is currently out of stock.';
          }

          if (onlineAvailable < totalQty) {
            throw 'Only $onlineAvailable left in stock for ${item.name}.';
          }

          productUpdates['reservedStock'] = FieldValue.increment(totalQty);
        }
      }

      // 3. ALL WRITES AT THE END: One update per product document + order document
      for (final entry in updatesByProductId.entries) {
        transaction.update(productRefs[entry.key]!, entry.value);
      }

      final orderRef = _orders.doc(order.id);
      transaction.set(orderRef, order.toFirestore());
    });
  }

  /// Cancels an active order and releases reserved stock tracking safely (never going below 0).
  Future<void> cancelOrder(String orderId, List<CartItem> items) {
    return _db.runTransaction((transaction) async {
      final orderRef = _orders.doc(orderId);
      final orderSnap = await transaction.get(orderRef);

      // Deduplicate product document reads first (Firestore requires all reads before writes)
      final Map<String, DocumentReference> productRefs = {};
      final Map<String, Map<String, dynamic>> productDataById = {};
      for (final item in items) {
        if (productDataById.containsKey(item.productId)) continue;
        final ref = _products.doc(item.productId);
        final snap = await transaction.get(ref);
        if (snap.exists) {
          productRefs[item.productId] = ref;
          productDataById[item.productId] =
              snap.data() as Map<String, dynamic>? ?? {};
        }
      }

      if (orderSnap.exists) {
        final currentStatus =
            (orderSnap.data() as Map<String, dynamic>?)?['status']?.toString();
        if (currentStatus == OrderStatus.cancelled.name) {
          return; // Already cancelled — avoid double-releasing reservedStock
        }
        transaction.update(orderRef, {'status': OrderStatus.cancelled.name});
      }

      // Aggregate quantities per (productId, variantId)
      final Map<String, int> stdQtyByProduct = {};
      final Map<String, Map<String, int>> varQtyByProduct = {};
      for (final item in items) {
        if (!productDataById.containsKey(item.productId)) continue;
        if (item.variantId != null && item.variantId!.isNotEmpty) {
          varQtyByProduct.putIfAbsent(item.productId, () => {}).update(
              item.variantId!, (v) => v + item.qty,
              ifAbsent: () => item.qty);
        } else {
          stdQtyByProduct.update(item.productId, (v) => v + item.qty,
              ifAbsent: () => item.qty);
        }
      }

      for (final entry in productDataById.entries) {
        final productId = entry.key;
        final data = entry.value;
        final Map<String, dynamic> updates = {};

        final stdRelease = stdQtyByProduct[productId] ?? 0;
        if (stdRelease > 0) {
          final currentReserved = (data['reservedStock'] as num? ?? 0).toInt();
          final nextReserved = (currentReserved - stdRelease);
          updates['reservedStock'] = nextReserved < 0 ? 0 : nextReserved;
        }

        final varReleases = varQtyByProduct[productId];
        if (varReleases != null && varReleases.isNotEmpty) {
          final variants = data['variants'] as Map<String, dynamic>?;
          if (variants != null) {
            for (final vEntry in varReleases.entries) {
              final variantData = variants[vEntry.key] as Map<String, dynamic>?;
              if (variantData == null) continue;
              final currentVarReserved =
                  (variantData['reservedStock'] as num? ?? 0).toInt();
              final nextVarReserved = currentVarReserved - vEntry.value;
              updates['variants.${vEntry.key}.reservedStock'] =
                  nextVarReserved < 0 ? 0 : nextVarReserved;
            }
          }
        }

        if (updates.isNotEmpty) {
          transaction.update(productRefs[productId]!, updates);
        }
      }
    });
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
    final user = FirebaseAuth.instance.currentUser;
    Query query = _refundQueue.where('transactionId', isEqualTo: txId);
    if (user?.email != null && user!.email!.isNotEmpty) {
      query = query.where('customerEmail', isEqualTo: user.email);
    } else if (user?.uid != null) {
      query = query.where('customerId', isEqualTo: user!.uid);
    }
    final snap = await query.get();
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
    final user = FirebaseAuth.instance.currentUser;

    if (refundRequestId.isNotEmpty) {
      batch.delete(_refundQueue.doc(refundRequestId));
    } else {
      Query refundQuery = _refundQueue
          .where('transactionId', isEqualTo: transactionId)
          .where('status', isEqualTo: RefundStatus.pending.name);
      if (user?.email != null && user!.email!.isNotEmpty) {
        refundQuery = refundQuery.where('customerEmail', isEqualTo: user.email);
      } else if (user?.uid != null) {
        refundQuery = refundQuery.where('customerId', isEqualTo: user!.uid);
      }
      final snap = await refundQuery.get();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
    }

    Query orderQuery = _orders.where('orderId', isEqualTo: transactionId);
    if (user?.email != null && user!.email!.isNotEmpty) {
      orderQuery = orderQuery.where('customerEmail', isEqualTo: user.email);
    } else if (user?.uid != null) {
      orderQuery = orderQuery.where('customerId', isEqualTo: user!.uid);
    }
    final orderSnap = await orderQuery.get();
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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return _watches.doc(id).set({
      'productId': productId,
      'email': email,
      if (uid != null) 'userId': uid,
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

    await NotificationService.showSmsNotificationPopUp(
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
