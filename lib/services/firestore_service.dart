import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product.dart';
import '../models/order.dart';
import '../models/transaction.dart';
import '../models/expense.dart';
import '../models/refund_request.dart';
import '../models/bundle.dart';
import '../models/promotion.dart';
import '../models/store_settings.dart';

class FirestoreService {
  final _db = FirebaseFirestore.instance;

  // ── Collections ────────────────────────────────────────────────────────────
  CollectionReference get _products     => _db.collection('products');
  CollectionReference get _orders       => _db.collection('orders');
  CollectionReference get _transactions => _db.collection('transactions');
  CollectionReference get _expenses     => _db.collection('expenses');
  CollectionReference get _refundQueue  => _db.collection('refund_requests');
  CollectionReference get _watches      => _db.collection('watched_products');
  CollectionReference get _bundles      => _db.collection('bundles');
  CollectionReference get _promotions   => _db.collection('promotions');
  DocumentReference   get _settings     => _db.collection('settings').doc('store_settings');

  // ── Store Settings ─────────────────────────────────────────────────────────

  Stream<StoreSettings> settingsStream() =>
      _settings.snapshots().map(StoreSettings.fromFirestore);

  // ── Products ───────────────────────────────────────────────────────────────

  // Real-time stream — widgets rebuild automatically on changes
  Stream<List<Product>> productsStream() =>
      _products.orderBy('name').snapshots().map(
              (s) => s.docs.map(Product.fromFirestore).toList());

  Future<void> addProduct(Product p) =>
      _products.add(p.toFirestore());

  Future<void> updateProduct(Product p) =>
      _products.doc(p.id).update(p.toFirestore());

  Future<void> updateStock(String productId, int newStock) =>
      _products.doc(productId).update({'stock': newStock});

  // Atomic batch: decrement stock for all cart items at once
  Future<void> decrementStockBatch(List<CartItem> items) {
    final batch = _db.batch();
    for (final item in items) {
      batch.update(_products.doc(item.productId), {
        'stock': FieldValue.increment(-item.qty),
      });
    }
    return batch.commit();
  }

  // ── Orders ─────────────────────────────────────────────────────────────────

  Stream<List<PreOrder>> ordersStream() =>
      _orders.orderBy('createdAt', descending: true).snapshots().map(
              (s) => s.docs.map(PreOrder.fromFirestore).toList());

  Stream<List<PreOrder>> ordersStreamForEmail(String email, {int limit = 20}) =>
      _orders
          .where('customerEmail', isEqualTo: email)
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((s) => s.docs.map(PreOrder.fromFirestore).toList());

  Future<DocumentReference> addOrder(PreOrder order) =>
      _orders.add(order.toFirestore());

  Future<void> updateOrderStatus(String orderId, OrderStatus status) =>
      _orders.doc(orderId).update({'status': status.name});

  // ── Transactions ───────────────────────────────────────────────────────────

  Stream<List<StoreTransaction>> transactionsStream() =>
      _transactions.orderBy('createdAt', descending: true).snapshots().map(
              (s) => s.docs.map(StoreTransaction.fromFirestore).toList());

  Future<void> addTransaction(StoreTransaction tx) =>
      _transactions.add(tx.toFirestore());

  Future<void> refundTransaction(String transactionId, List<CartItem> items) {
    final batch = _db.batch();

    // 1. Mark transaction as refunded
    batch.update(_transactions.doc(transactionId), {'isRefunded': true});

    // 2. Restock items
    for (final item in items) {
      batch.update(_products.doc(item.productId), {
        'stock': FieldValue.increment(item.qty),
      });
    }

    return batch.commit();
  }

  Future<void> refundOrder(String orderId, List<CartItem> items) {
    final batch = _db.batch();

    // 1. Update order status to refunded
    batch.update(_orders.doc(orderId), {'status': OrderStatus.refunded.name});

    // 2. Restock items
    for (final item in items) {
      batch.update(_products.doc(item.productId), {
        'stock': FieldValue.increment(item.qty),
      });
    }

    return batch.commit();
  }

  // ── Expenses ───────────────────────────────────────────────────────────────

  Stream<List<Expense>> expensesStream() =>
      _expenses.orderBy('createdAt', descending: true).snapshots().map(
              (s) => s.docs.map(Expense.fromFirestore).toList());

  Future<void> addExpense(Expense e) =>
      _expenses.add(e.toFirestore());

  // ── Refund Queue ───────────────────────────────────────────────────────────

  Future<void> requestRefund(RefundRequest req) {
    return _refundQueue.add(req.toFirestore());
  }

  Future<List<RefundRequest>> getRefundRequestsForTransaction(String txId) async {
    final snap = await _refundQueue.where('transactionId', isEqualTo: txId).get();
    return snap.docs.map(RefundRequest.fromFirestore).toList();
  }

  Stream<List<RefundRequest>> refundRequestsStreamForEmail(String email) =>
      _refundQueue
          .where('customerEmail', isEqualTo: email)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((s) => s.docs.map(RefundRequest.fromFirestore).toList());

  // ── Product Watches ────────────────────────────────────────────────────────

  Future<void> watchProduct(String productId, String email) {
    final id = '${productId}_${email.replaceAll('@', '_').replaceAll('.', '_')}';
    return _watches.doc(id).set({
      'productId': productId,
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<bool> isWatching(String productId, String email) async {
    final id = '${productId}_${email.replaceAll('@', '_').replaceAll('.', '_')}';
    final doc = await _watches.doc(id).get();
    return doc.exists;
  }

  // ── Bundles ────────────────────────────────────────────────────────────────

  Stream<List<ProductBundle>> bundlesStream() =>
      _bundles.where('isActive', isEqualTo: true).snapshots().map((s) => s.docs.map(ProductBundle.fromFirestore).toList());

  // ── Promotions ─────────────────────────────────────────────────────────────

  Stream<List<Promotion>> promotionsStream() =>
      _promotions.where('isActive', isEqualTo: true).snapshots().map((s) => s.docs.map(Promotion.fromFirestore).toList());
}
