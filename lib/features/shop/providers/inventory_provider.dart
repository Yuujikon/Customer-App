import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../shared/models/product.dart';
import '../../../shared/models/bundle.dart';
import '../../../shared/models/order.dart';
import '../../../shared/models/transaction.dart';
import '../../../shared/models/store_settings.dart';
import '../../../shared/services/firestore_service.dart';

class InventoryProvider extends ChangeNotifier {
  final _fs = FirestoreService();

  List<Product>          _products     = [];
  List<StoreTransaction> _transactions = [];
  List<ProductBundle>    _bundles      = [];
  StoreSettings          _settings     = const StoreSettings(isClosed: false);
  DateTime?              _lastProductUpdate;

  List<Product>          get products     => _products;
  List<StoreTransaction> get transactions => _transactions;
  List<ProductBundle>    get bundles      => _bundles;
  StoreSettings          get settings     => _settings;
  DateTime?              get lastProductUpdate => _lastProductUpdate;

  // ── Sorting Logic ──────────────────────────────────────────────────────────

  /// Returns products sorted by sales volume (Last 30 Days)
  /// Fast-moving first, slow-moving later.
  List<Product> get sortedProducts {
    if (_products.isEmpty) return [];

    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    final recentCounts = <String, int>{};
    
    for (final tx in _transactions) {
      if (tx.createdAt.isAfter(thirtyDaysAgo)) {
        for (final item in tx.items) {
          recentCounts[item.productId] = (recentCounts[item.productId] ?? 0) + item.qty;
        }
      }
    }

    final sorted = List<Product>.from(_products);
    sorted.sort((a, b) {
      final aStock = a.totalStock;
      final bStock = b.totalStock;

      // 1. Prioritize Stocked items over Out of Stock items
      if (aStock > 0 && bStock <= 0) return -1;
      if (aStock <= 0 && bStock > 0) return 1;

      // 2. Secondary sort: By sales volume (Last 30 Days)
      final countA = recentCounts[a.id] ?? 0;
      final countB = recentCounts[b.id] ?? 0;
      return countB.compareTo(countA);
    });

    return sorted;
  }

  void initialize() {
    // Firestore streams keep state up-to-date automatically
    _fs.productsStream().listen((list) {
      _products = list;
      _lastProductUpdate = DateTime.now();
      notifyListeners();
    });
    _fs.transactionsStream().listen((list) {
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _transactions = list;
      notifyListeners();
    });
    _fs.bundlesStream().listen((list) {
      _bundles = list;
      notifyListeners();
    });
    _fs.settingsStream().listen((settings) {
      _settings = settings;
      notifyListeners();
    });
  }

  Future<void> refreshData() async {
    // Since we use streams, Firestore handles updates automatically.
    // This method can be used to force a small delay for UX in RefreshIndicator.
    await Future.delayed(const Duration(milliseconds: 800));
  }

  Future<void> saveProduct(Product product) {
    if (product.id.isEmpty) return _fs.addProduct(product);
    return _fs.updateProduct(product);
  }

  Future<void> completeSale(List<CartItem> cart, double cash) async {
    final total  = cart.fold(0.0, (s, i) => s + i.price * i.qty);
    final change = cash - total;

    final tx = StoreTransaction(
      id:        const Uuid().v4(),
      items:     cart,
      total:     total,
      cash:      cash,
      change:    change,
      createdAt: DateTime.now(),
    );

    // Write transaction and decrement stock in parallel
    await Future.wait([
      _fs.addTransaction(tx),
      _fs.decrementStockBatch(cart),
    ]);
    // No notifyListeners needed — Firestore streams handle it
  }

  Future<void> watchProduct(String productId, String email) =>
      _fs.watchProduct(productId, email);

  Future<bool> isWatching(String productId, String email) =>
      _fs.isWatching(productId, email);
}
