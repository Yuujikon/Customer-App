import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/product.dart';
import '../models/order.dart';
import '../models/transaction.dart';
import '../models/store_settings.dart';
import '../services/firestore_service.dart';

class InventoryProvider extends ChangeNotifier {
  final _fs = FirestoreService();

  List<Product>          _products     = [];
  List<StoreTransaction> _transactions = [];
  StoreSettings          _settings     = const StoreSettings(isClosed: false);

  List<Product>          get products     => _products;
  List<StoreTransaction> get transactions => _transactions;
  StoreSettings          get settings     => _settings;

  // ── Sorting Logic ──────────────────────────────────────────────────────────

  /// Returns products sorted by sales volume (Last 30 Days)
  /// Fast-moving first, slow-moving later.
  List<Product> get sortedProducts {
    if (_products.isEmpty) return [];
    if (_transactions.isEmpty) return _products;

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
      notifyListeners();
    });
    _fs.transactionsStream().listen((list) {
      _transactions = list;
      notifyListeners();
    });
    _fs.settingsStream().listen((settings) {
      _settings = settings;
      notifyListeners();
    });
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
}