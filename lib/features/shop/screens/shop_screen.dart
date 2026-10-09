import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../shared/models/product.dart';
import '../../auth/providers/auth_provider.dart';
import '../../orders/providers/order_provider.dart';
import '../providers/inventory_provider.dart';
import '../widgets/basket_summary_section.dart';
import '../widgets/shop_widgets.dart';
import 'out_of_stock_dashboard.dart';
import 'product_details_screen.dart';

class ShopScreen extends StatefulWidget {
  final VoidCallback onViewCart;

  const ShopScreen({super.key, required this.onViewCart});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  String _cat = 'All';
  bool _inStockOnly = true;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<InventoryProvider>();
    final products = inventory.sortedProducts.isNotEmpty
        ? inventory.sortedProducts
        : _defaultCatalog;
    final orderProvider = context.watch<OrderProvider>();
    final auth = context.watch<AppAuthProvider>();

    final preCart = orderProvider.preCart;
    final buyAgainRaw = orderProvider.getBuyItAgainItems();

    // Filter buyAgain to strictly in-stock products
    final buyAgain = buyAgainRaw.where((item) {
      try {
        final p =
            inventory.products.firstWhere((prod) => prod.id == item.productId);
        return !p.isOutOfStockForCustomer;
      } catch (_) {
        return false;
      }
    }).toList();

    final bundles = inventory.bundles.where((b) => b.isActive).toList();
    final effectivelyClosed = inventory.settings.effectivelyClosed;

    final cats = [
      'All',
      ...inventory.products.map((p) => p.category).toSet().toList()..sort()
    ];

    // Main catalog grid filtering
    final filtered = products
        .where((p) => p.status == ProductStatus.published)
        .where((p) {
          if (_inStockOnly) return !p.isOutOfStockForCustomer;
          return true;
        })
        .where((p) =>
            _cat == 'All' ||
            p.category.toLowerCase().contains(_cat.toLowerCase()))
        .where((p) =>
            _search.isEmpty ||
            p.name.toLowerCase().contains(_search.toLowerCase()))
        .toList();

    final cartTotal = preCart.fold(0.0, (s, i) => s + i.price * i.qty);
    final cartCount = preCart.fold(0, (s, i) => s + i.qty);

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await inventory.refreshData();
            await Future.delayed(const Duration(milliseconds: 300));
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'GDC MARKET',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: AppColors.sage,
                          letterSpacing: 1.2,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Browse the catalog',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryText,
                          letterSpacing: -0.4,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Fresh essentials and everyday favorites, ready for pickup.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.mutedText,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Offline Connectivity Alert
              SliverToBoxAdapter(
                child: StreamBuilder<List<ConnectivityResult>>(
                  stream: Connectivity().onConnectivityChanged,
                  builder: (context, snapshot) {
                    final results = snapshot.data ?? [];
                    final isOffline = results.contains(ConnectivityResult.none);

                    if (!isOffline) return const SizedBox.shrink();

                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 16),
                      color: AppColors.error.withValues(alpha: 0.9),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.wifi_off_rounded,
                              color: Colors.white, size: 16),
                          SizedBox(width: 8),
                          Text(
                            'You are offline. Inventory data might be stale.',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              // Search & Filters Section
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Search Input
                          Expanded(
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(100),
                                border: Border.all(color: AppColors.border),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: TextField(
                                controller: _searchCtrl,
                                decoration: const InputDecoration(
                                  hintText: 'Search groceries...',
                                  prefixIcon: Icon(Icons.search_rounded,
                                      color: AppColors.mutedText, size: 20),
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 12),
                                ),
                                onChanged: (v) => setState(() => _search = v),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Restock Radar Shortcut Button
                          Tooltip(
                            message: 'Restock Notifications Hub',
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const OutOfStockDashboardScreen()),
                                );
                              },
                              child: Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: AppColors.orangeCTA
                                      .withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: AppColors.orangeCTA
                                          .withValues(alpha: 0.3)),
                                ),
                                child: const Icon(
                                    Icons.notifications_active_rounded,
                                    color: AppColors.orangeCTA,
                                    size: 22),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      // Filter Chips Row
                      SizedBox(
                        height: 40,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            FilterChip(
                              label: const Text('In Stock Only'),
                              selected: _inStockOnly,
                              onSelected: (val) => setState(() {
                                _inStockOnly = val;
                              }),
                              selectedColor: AppColors.sageTint,
                              labelStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _inStockOnly
                                    ? AppColors.forest
                                    : AppColors.mutedText,
                              ),
                              showCheckmark: true,
                              checkmarkColor: AppColors.forest,
                              side: BorderSide(
                                color: _inStockOnly
                                    ? AppColors.forest.withValues(alpha: 0.3)
                                    : AppColors.border,
                              ),
                            ),
                            const SizedBox(width: 8),
                            ...cats.map((catName) => Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(catName),
                                    selected: _cat == catName,
                                    onSelected: (selected) {
                                      if (selected)
                                        setState(() => _cat = catName);
                                    },
                                    selectedColor: AppColors.forest,
                                    backgroundColor: Colors.white,
                                    showCheckmark: false,
                                    labelStyle: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: _cat == catName
                                          ? Colors.white
                                          : AppColors.mutedText,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(100),
                                      side: BorderSide(
                                        color: _cat == catName
                                            ? AppColors.forest
                                            : AppColors.border,
                                      ),
                                    ),
                                  ),
                                )),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (inventory.settings.announcement?.isNotEmpty ?? false)
                SliverToBoxAdapter(
                    child: AnnouncementTicker(
                        text: inventory.settings.announcement!)),

              // Active Basket Summary
              if (preCart.isNotEmpty)
                SliverToBoxAdapter(
                  child: BasketSummarySection(
                    items: preCart,
                    allProducts: inventory.products,
                    onRemove: (id, variantId) => orderProvider
                        .removeFromPreCart(id, variantId: variantId),
                    onClearAll: () => orderProvider.clearPreCart(),
                  ),
                ),

              // Your Usual Items Section
              if (buyAgain.isNotEmpty)
                SliverToBoxAdapter(
                  child: UsualBasketSection(
                    items: buyAgain,
                    allProducts: inventory.products,
                    inCart: (id) => preCart.any((c) => c.productId == id),
                    onAdd: (p) => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => ProductDetailsScreen(product: p))),
                    onAddAll: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final result = await orderProvider.reorderItems(
                          buyAgain, inventory.products);
                      if (mounted) {
                        messenger.showSnackBar(SnackBar(
                          content:
                              Text('${result['added']} items added to basket.'),
                          backgroundColor: AppColors.forest,
                        ));
                      }
                    },
                  ),
                ),

              // Sulit Bundles Section
              if (bundles.isNotEmpty)
                SliverToBoxAdapter(
                  child: BundlesSection(
                    bundles: bundles,
                    allProducts: inventory.products,
                    currentCategory: _cat,
                    onAdd: (bundle) {
                      for (final pid in bundle.productIds) {
                        try {
                          final p = inventory.products
                              .firstWhere((prod) => prod.id == pid);
                          if (!p.hasVariants && p.stock > 0) {
                            orderProvider.addToPreCart(p);
                          } else if (p.hasVariants) {
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        ProductDetailsScreen(product: p)));
                          }
                        } catch (_) {}
                      }
                    },
                  ),
                ),

              // Store Closure Notice
              if (effectivelyClosed)
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: const Color(0xFFFDECEA),
                        borderRadius: BorderRadius.circular(16)),
                    child: Text(
                      inventory.settings.closureMessage ?? 'STORE CLOSED',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: AppColors.error),
                    ),
                  ),
                ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _cat == 'All'
                            ? 'Products (${filtered.length})'
                            : '$_cat (${filtered.length})',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryText),
                      ),
                      if (!_inStockOnly)
                        const Text(
                          'Including Out of Stock',
                          style: TextStyle(
                              fontSize: 11,
                              color: AppColors.forest,
                              fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                ),
              ),

              // Product Grid
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                sliver: filtered.isEmpty
                    ? SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Column(
                            children: [
                              const Icon(Icons.shopping_bag_outlined,
                                  size: 48, color: AppColors.mutedText),
                              const SizedBox(height: 12),
                              const Text(
                                  'No in-stock items found in this section',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryText)),
                              const SizedBox(height: 4),
                              TextButton(
                                onPressed: () => setState(() {
                                  _inStockOnly = false;
                                  _cat = 'All';
                                  _search = '';
                                  _searchCtrl.clear();
                                }),
                                child: const Text(
                                    'Show all items or reset filters'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 200,
                          childAspectRatio: 0.58,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 14,
                        ),
                        delegate: SliverChildBuilderDelegate((context, i) {
                          final p = filtered[i];
                          final inCart =
                              preCart.any((c) => c.productId == p.id);
                          return ProductCard(
                            product: p,
                            inCart: inCart,
                            isFavorite: auth.favorites.contains(p.id),
                            isOutOfStock: p.isOutOfStockForCustomer,
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        ProductDetailsScreen(product: p))),
                            onToggleFavorite: () => auth.toggleFavorite(p.id),
                          );
                        }, childCount: filtered.length),
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: (preCart.isNotEmpty && !effectivelyClosed)
          ? FloatingActionButton.extended(
              onPressed: widget.onViewCart,
              backgroundColor: AppColors.orangeCTA,
              foregroundColor: Colors.white,
              elevation: 8,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100)),
              label: Text('$cartCount items · ${formatPeso(cartTotal)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, letterSpacing: 0.5)),
              icon: const Icon(Icons.shopping_basket_rounded),
            )
          : null,
    );
  }

  static const List<Product> _defaultCatalog = [
    Product(
      id: 'p1',
      name: 'Fresh Red Tomatoes',
      unit: '500g',
      price: 68.00,
      stock: 25,
      category: 'Fresh Produce',
      shelfDays: 5,
    ),
    Product(
      id: 'p2',
      name: 'Creamy Avocados',
      unit: '2 pieces',
      price: 95.00,
      stock: 18,
      category: 'Fresh Produce',
      shelfDays: 4,
    ),
    Product(
      id: 'p3',
      name: 'Garden Veggie Box',
      unit: '1 basket',
      price: 249.00,
      stock: 10,
      category: 'Fresh Produce',
      shelfDays: 7,
    ),
    Product(
      id: 'p4',
      name: 'Farm Fresh Mix',
      unit: '1 bundle',
      price: 189.00,
      stock: 12,
      category: 'Fresh Produce',
      shelfDays: 3,
    ),
  ];
}
