import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../shared/models/product.dart';
import '../../../shared/models/bundle.dart';
import '../../../shared/models/order.dart';
import '../../../shared/models/transaction.dart';
import '../../../shared/models/store_settings.dart';
export '../../../shared/models/store_settings.dart';
import '../../../shared/services/firestore_service.dart';
import '../../../shared/services/time_service.dart';

class InventoryProvider extends ChangeNotifier {
  final _fs = FirestoreService();
  bool _isDisposed = false;
  final List<StreamSubscription> _subscriptions = [];

  List<Product> _products = [];
  List<StoreTransaction> _transactions = [];
  List<ProductBundle> _bundles = [];
  StoreSettings _settings = const StoreSettings(isClosed: false);
  DateTime? _lastProductUpdate;

  List<Product> get products => _products;
  List<StoreTransaction> get transactions => _transactions;
  List<ProductBundle> get bundles => _bundles;
  StoreSettings get settings => _settings;
  DateTime? get lastProductUpdate => _lastProductUpdate;

  // ── Enterprise Inventory Automation & Analytics Telemetry ─────────────────

  /// Calculates total inventory market retail valuation
  double get totalRetailValuation =>
      _products.fold(0.0, (sum, p) => sum + p.totalInventoryAssetValue);

  /// Calculates total inventory cost valuation (COGS basis)
  double get totalCostValuation =>
      _products.fold(0.0, (sum, p) => sum + p.totalInventoryCostValue);

  /// Calculates overall gross profit margin percentage across catalog
  double get grossMarginPercentage {
    final retail = totalRetailValuation;
    if (retail <= 0) return 0.0;
    return ((retail - totalCostValuation) / retail) * 100;
  }

  /// Automated Reorder Queue: Products requiring stock replenishment
  List<Product> get autoReorderQueue =>
      _products.where((p) => p.isAutoReorderRequired).toList();

  /// Automated Expiry Queue: Products that have passed expiry date
  List<Product> get expiredQueue => _products
      .where((p) => p.expiryStatus == ExpiryStatus.expired && !p.isQuarantined)
      .toList();

  /// Critical Expiry Queue: Perishables expiring within 48 hours
  List<Product> get criticalExpiryQueue => _products
      .where((p) => p.expiryStatus == ExpiryStatus.critical && !p.isQuarantined)
      .toList();

  /// Quarantined Inventory Queue: Items isolated from public procurement
  List<Product> get quarantinedQueue =>
      _products.where((p) => p.isQuarantined).toList();

  /// Map of product 30-day sales volume
  Map<String, int> get product30DaySales {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    final sales = <String, int>{};
    for (final tx in _transactions) {
      if (tx.createdAt.isAfter(thirtyDaysAgo)) {
        for (final item in tx.items) {
          sales[item.productId] = (sales[item.productId] ?? 0) + item.qty;
        }
      }
    }
    return sales;
  }

  /// ABC Inventory Classification (A: Top 20% movers, B: Next 30%, C: Remaining)
  InventoryAbcCategory getProductAbcCategory(String productId) {
    if (_products.isEmpty) return InventoryAbcCategory.categoryC;
    final salesMap = product30DaySales;
    final sortedBySales = List<Product>.from(_products)
      ..sort((a, b) => (salesMap[b.id] ?? 0).compareTo(salesMap[a.id] ?? 0));
    final index = sortedBySales.indexWhere((p) => p.id == productId);
    if (index < 0) return InventoryAbcCategory.categoryC;

    final double percentile = index / sortedBySales.length;
    if (percentile <= 0.20) return InventoryAbcCategory.categoryA;
    if (percentile <= 0.50) return InventoryAbcCategory.categoryB;
    return InventoryAbcCategory.categoryC;
  }

  /// Automated Bulk Replenishment Execution
  Future<int> executeBulkAutoReplenishment() async {
    final queue = autoReorderQueue;
    if (queue.isEmpty) return 0;

    int restockedCount = 0;
    for (final product in queue) {
      final recommendedRestock = product.effectiveReorderQuantity;
      final newStock = product.stock + recommendedRestock;

      final updated = product.copyWith(stock: newStock);
      await _fs.updateProduct(updated);
      await _fs.logStockAudit(
        productId: product.id,
        productName: product.name,
        previousStock: product.stock,
        newStock: newStock,
        reason:
            'Automated Reorder Trigger (ROP: ${product.effectiveReorderPoint})',
      );
      restockedCount++;
    }
    notifyListeners();
    return restockedCount;
  }

  /// Automated Quarantine Execution for Expired Inventory
  Future<int> executeAutoQuarantineExpired() async {
    final expired = expiredQueue;
    if (expired.isEmpty) return 0;

    int quarantinedCount = 0;
    for (final product in expired) {
      final updated = product.copyWith(isQuarantined: true);
      await _fs.updateProduct(updated);
      await _fs.logStockAudit(
        productId: product.id,
        productName: product.name,
        previousStock: product.stock,
        newStock: product.stock,
        reason: 'Automated Expiry Quarantine (Expired: ${product.expiryDate})',
      );
      quarantinedCount++;
    }
    notifyListeners();
    return quarantinedCount;
  }

  /// Manual Stock Adjustment with Automated Audit Logging
  Future<void> updateStockWithAuditLog({
    required String productId,
    required int newStock,
    required String reason,
    String? operatorEmail,
  }) async {
    final product = _products.firstWhere((p) => p.id == productId);
    final previousStock = product.stock;
    final updated = product.copyWith(stock: newStock);

    await _fs.updateProduct(updated);
    await _fs.logStockAudit(
      productId: productId,
      productName: product.name,
      previousStock: previousStock,
      newStock: newStock,
      reason: reason,
      operatorEmail: operatorEmail,
    );
    notifyListeners();
  }

  /// Update Store Operational Settings
  Future<void> updateSettings(StoreSettings settings) async {
    await _fs.updateSettings(settings);
    _settings = settings;
    notifyListeners();
  }

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
          recentCounts[item.productId] =
              (recentCounts[item.productId] ?? 0) + item.qty;
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
    _cancelSubscriptions();
    _subscriptions.add(_fs.productsStream().listen((list) {
      if (_isDisposed) return;
      _products = list;
      _lastProductUpdate = TimeService.now;
      notifyListeners();
    }, onError: (e) {
      debugPrint('Error listening to products stream: $e');
    }));

    _subscriptions.add(_fs.transactionsStream().listen((list) {
      if (_isDisposed) return;
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _transactions = list;
      notifyListeners();
    }, onError: (e) {
      debugPrint('Error listening to transactions stream: $e');
    }));

    _subscriptions.add(_fs.bundlesStream().listen((list) {
      if (_isDisposed) return;
      _bundles = list;
      notifyListeners();
    }, onError: (e) {
      debugPrint('Error listening to bundles stream: $e');
    }));

    _subscriptions.add(_fs.settingsStream().listen((settings) {
      if (_isDisposed) return;
      _settings = settings;
      notifyListeners();
    }, onError: (e) {
      debugPrint('Error listening to settings stream: $e');
    }));
  }

  void _cancelSubscriptions() {
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _cancelSubscriptions();
    super.dispose();
  }

  Future<void> refreshData() async {
    // Firestore streams keep data updated in real-time.
    // Instant completion for zero-latency pull-to-refresh UX.
    return;
  }

  Future<void> saveProduct(Product product) {
    if (product.id.isEmpty) return _fs.addProduct(product);
    return _fs.updateProduct(product);
  }

  Future<void> completeSale(List<CartItem> cart, double cash) async {
    final total = cart.fold(0.0, (s, i) => s + i.price * i.qty);
    final change = cash - total;

    final tx = StoreTransaction(
      id: const Uuid().v4(),
      items: cart,
      total: total,
      cash: cash,
      change: change,
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

  // ── Out-of-Stock & Restock Notifications ─────────────────────────────────

  /// Filtered list of products currently out of stock for customer
  List<Product> get outOfStockProducts =>
      _products.where((p) => p.isOutOfStockForCustomer).toList();

  /// Gets out-of-stock products that match user favorites or buy-again history
  List<Product> getOutOfStockWishlist({
    required List<String> favoriteIds,
    required List<String> buyAgainProductIds,
  }) {
    return _products.where((p) {
      final isOos = p.isOutOfStockForCustomer;
      final isFav = favoriteIds.contains(p.id);
      final isBuyAgain = buyAgainProductIds.contains(p.id);
      return isOos && (isFav || isBuyAgain);
    }).toList();
  }

  /// Toggles restock notification subscription for a customer using FieldValue.arrayUnion/arrayRemove
  Future<void> toggleRestockNotification(
      String productId, String userId) async {
    if (productId.isEmpty || userId.isEmpty) return;
    try {
      final p = _products.firstWhere((prod) => prod.id == productId);
      final isCurrentlyNotifying = p.notifyUserIds.contains(userId);

      await _fs.toggleRestockNotification(
        productId: productId,
        userId: userId,
        isCurrentlyNotifying: isCurrentlyNotifying,
      );

      // Update local product copy for instant reactive UI feedback before stream fires
      final updatedList = p.notifyUserIds.contains(userId)
          ? p.notifyUserIds.where((id) => id != userId).toList()
          : [...p.notifyUserIds, userId];

      final idx = _products.indexWhere((prod) => prod.id == productId);
      if (idx != -1) {
        _products[idx] = p.copyWith(notifyUserIds: updatedList);
        notifyListeners();
      }
    } catch (e) {
      debugPrint(
          'Error toggling restock notification for product $productId: $e');
      rethrow;
    }
  }
}
