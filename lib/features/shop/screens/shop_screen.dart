import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../shared/models/product.dart';
import '../../auth/providers/auth_provider.dart';
import '../../orders/providers/order_provider.dart';
import '../../orders/widgets/reorder_summary_dialog.dart';
import '../providers/inventory_provider.dart';
import '../widgets/basket_summary_section.dart';
import '../widgets/shop_widgets.dart';
import 'product_details_screen.dart';

class ShopScreen extends StatefulWidget {
  final VoidCallback onViewCart;
  final String initialCategory;

  const ShopScreen({
    super.key,
    required this.onViewCart,
    this.initialCategory = 'All',
  });

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final _searchCtrl = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  String _search = '';
  late String _cat;
  bool _showOutOfStock = false;
  bool _savedOnly = false;

  @override
  void initState() {
    super.initState();
    _cat = widget.initialCategory;
  }

  @override
  void didUpdateWidget(covariant ShopScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialCategory != widget.initialCategory) {
      setState(() {
        _cat = widget.initialCategory;
      });
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _openProductDetails(Product p, {String? heroTag}) async {
    final double savedOffset =
        _scrollController.hasClients ? _scrollController.offset : 0.0;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailsScreen(product: p, heroTag: heroTag),
      ),
    );
    if (_scrollController.hasClients && savedOffset > 0) {
      _scrollController.jumpTo(savedOffset);
    }
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

    final rawCats = inventory.products
        .map((p) => p.category.trim())
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();

    final bool hasOthers = rawCats.any((c) => c.toLowerCase() == 'others');
    final nonOthers = rawCats.where((c) => c.toLowerCase() != 'others').toList()
      ..sort();

    final cats = [
      'All',
      ...nonOthers,
      if (hasOthers) 'Others',
    ];

    // Main catalog grid filtering (Defaults to in-stock products only)
    final filtered = products
        .where((p) => p.status == ProductStatus.published)
        .where((p) {
          if (!_showOutOfStock) return !p.isOutOfStockForCustomer;
          return true;
        })
        .where((p) {
          if (_savedOnly) return auth.favorites.contains(p.id);
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
    final savedCount =
        inventory.products.where((p) => auth.favorites.contains(p.id)).length;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await inventory.refreshData();
            await Future.delayed(const Duration(milliseconds: 300));
          },
          child: CustomScrollView(
            controller: _scrollController,
            key: const PageStorageKey('shop_catalog_scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Header with Swapped Top-Right Actions (3-Dot Menu First, Notification Bell Second)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                            'Browse Catalog',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Theme.of(context).colorScheme.onSurface,
                              letterSpacing: -0.4,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Fresh essentials, ready for express pickup.',
                            style: TextStyle(
                              fontSize: 12,
                              color:
                                  Theme.of(context).textTheme.bodySmall?.color,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 1. 3-Dot Filter Options Menu (Swapped Position)
                          PopupMenuButton<String>(
                            tooltip: '',
                            icon: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: (_showOutOfStock || _savedOnly)
                                    ? AppColors.sageTint
                                    : Theme.of(context).cardColor,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: (_showOutOfStock || _savedOnly)
                                      ? AppColors.forest
                                      : Theme.of(context).dividerColor,
                                ),
                              ),
                              child: Icon(
                                Icons.more_vert_rounded,
                                color: (_showOutOfStock || _savedOnly)
                                    ? AppColors.forest
                                    : Theme.of(context).colorScheme.onSurface,
                                size: 20,
                              ),
                            ),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            onSelected: (val) {
                              setState(() {
                                if (val == 'oos') {
                                  _showOutOfStock = !_showOutOfStock;
                                } else if (val == 'saved') {
                                  _savedOnly = !_savedOnly;
                                } else if (val == 'reset') {
                                  _showOutOfStock = false;
                                  _savedOnly = false;
                                }
                              });
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem(
                                value: 'oos',
                                child: Row(
                                  children: [
                                    Icon(
                                      _showOutOfStock
                                          ? Icons.check_circle_rounded
                                          : Icons
                                              .radio_button_unchecked_rounded,
                                      size: 18,
                                      color: _showOutOfStock
                                          ? AppColors.forest
                                          : AppColors.mutedText,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text('Show Sold Out Items',
                                        style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'saved',
                                child: Row(
                                  children: [
                                    Icon(
                                      _savedOnly
                                          ? Icons.favorite_rounded
                                          : Icons.favorite_border_rounded,
                                      size: 18,
                                      color: _savedOnly
                                          ? Colors.red.shade600
                                          : AppColors.mutedText,
                                    ),
                                    const SizedBox(width: 8),
                                    Text('Saved Items ($savedCount)',
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                              if (_showOutOfStock || _savedOnly)
                                PopupMenuItem(
                                  value: 'reset',
                                  child: Row(
                                    children: const [
                                      Icon(Icons.refresh_rounded,
                                          size: 18, color: AppColors.mutedText),
                                      SizedBox(width: 8),
                                      Text('Reset Filters',
                                          style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: AppColors.mutedText)),
                                    ],
                                  ),
                                ),
                            ],
                          ),

                          // Removed Notification Bell Icon (Restock Radar)
                        ],
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

              // Professional Search Bar & Filters Section Card
              SliverToBoxAdapter(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: Theme.of(context).dividerColor, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.015),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Sleek Professional Full-Width Search Input
                        Container(
                          height: 44,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerLow,
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                                color: Theme.of(context).dividerColor),
                          ),
                          child: TextField(
                            controller: _searchCtrl,
                            focusNode: _searchFocusNode,
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                            decoration: InputDecoration(
                              filled: false,
                              fillColor: Colors.transparent,
                              hintText: 'Search groceries, produce, snacks...',
                              hintStyle: TextStyle(
                                  fontSize: 12.5,
                                  color: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.color,
                                  fontWeight: FontWeight.w500),
                              prefixIcon: const Icon(Icons.search_rounded,
                                  color: AppColors.forest, size: 20),
                              suffixIcon: _search.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(Icons.clear_rounded,
                                          size: 18,
                                          color: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.color),
                                      onPressed: () {
                                        _searchCtrl.clear();
                                        setState(() => _search = '');
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                            ),
                            onChanged: (v) => setState(() => _search = v),
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Category Filter Chips Row
                        SizedBox(
                          height: 38,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: cats.map((catName) {
                              final bool isSelected = _cat == catName;
                              return Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: ChoiceChip(
                                  label: Text(catName),
                                  selected: isSelected,
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                  onSelected: (selected) {
                                    if (selected)
                                      setState(() => _cat = catName);
                                  },
                                  selectedColor: AppColors.forest,
                                  labelStyle: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                  backgroundColor: Theme.of(context).cardColor,
                                  side: BorderSide(
                                    color: isSelected
                                        ? AppColors.forest
                                        : Theme.of(context).dividerColor,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Active Basket Summary Section Card (Stable Sliver Key)
              SliverToBoxAdapter(
                key: const ValueKey('basket_summary_sliver'),
                child: preCart.isNotEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Theme.of(context).dividerColor,
                                width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.015),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: BasketSummarySection(
                            items: preCart,
                            allProducts: inventory.products,
                            onRemove: (id, variantId) => orderProvider
                                .removeFromPreCart(id, variantId: variantId),
                            onClearAll: () => orderProvider.clearPreCart(),
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),

              // Your Usual Items Section Card (Stable Sliver Key)
              SliverToBoxAdapter(
                key: const ValueKey('usual_basket_sliver'),
                child: buyAgain.isNotEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Theme.of(context).dividerColor,
                                width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.015),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: UsualBasketSection(
                            items: buyAgain,
                            allProducts: inventory.products,
                            inCart: (id) =>
                                preCart.any((c) => c.productId == id),
                            onAdd: (p) => _openProductDetails(p),
                            onAddAll: () async {
                              final previews = orderProvider.previewReorder(
                                  buyAgain, inventory.products);
                              final bool hasIssues = previews
                                  .any((p) => p.isUnavailable || p.isAdjusted);

                              if (hasIssues) {
                                showDialog(
                                  context: context,
                                  builder: (ctx) => ReorderSummaryDialog(
                                    previews: previews,
                                    onConfirm: () {
                                      orderProvider.applyReorder(previews);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content:
                                              Text('Items added to basket.'),
                                          backgroundColor: AppColors.forest,
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    },
                                    onBrowseSimilar: (category) {
                                      // Ignore for dashboard
                                    },
                                  ),
                                );
                              } else {
                                orderProvider.applyReorder(previews);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('All items added to basket.'),
                                    backgroundColor: AppColors.forest,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),

              // Active Bundles Section Card (Stable Sliver Key)
              SliverToBoxAdapter(
                key: const ValueKey('bundles_section_sliver'),
                child: bundles.isNotEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: Theme.of(context).dividerColor,
                                width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.015),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: BundlesSection(
                            bundles: bundles,
                            allProducts: inventory.products,
                            currentCategory: _cat,
                            onAdd: (bundle) {
                              final messenger = ScaffoldMessenger.of(context);
                              for (final productId in bundle.productIds) {
                                try {
                                  final p = inventory.products.firstWhere(
                                      (prod) => prod.id == productId);
                                  orderProvider.addToPreCart(p);
                                } catch (_) {}
                              }
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Added "${bundle.name}" to pre-cart.'),
                                  backgroundColor: AppColors.forest,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),

              // Section Header
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
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Theme.of(context).colorScheme.onSurface),
                      ),
                      if (_showOutOfStock)
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

              // Moderate Product Grid
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
                              Text('No items found in this section',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface)),
                              const SizedBox(height: 4),
                              TextButton(
                                onPressed: () => setState(() {
                                  _showOutOfStock = true;
                                  _cat = 'All';
                                  _search = '';
                                  _searchCtrl.clear();
                                }),
                                child: const Text(
                                    'Include sold out items or reset filters'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 180,
                          mainAxisExtent: 260,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        delegate: SliverChildBuilderDelegate((context, i) {
                          final p = filtered[i];
                          final inCart =
                              preCart.any((c) => c.productId == p.id);
                          return ProductTile(
                            product: p,
                            inCart: inCart,
                            heroTag: 'catalog_${p.id}',
                            isFavorite: auth.favorites.contains(p.id),
                            isOutOfStock: p.isOutOfStockForCustomer,
                            onTap: () => _openProductDetails(p,
                                heroTag: 'catalog_${p.id}'),
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
      floatingActionButton: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: (preCart.isNotEmpty && !effectivelyClosed) ? 1.0 : 0.0,
        child: IgnorePointer(
          ignoring: preCart.isEmpty || effectivelyClosed,
          child: SafeArea(
            bottom: true,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              child: ElevatedButton(
                onPressed: widget.onViewCart,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orangeCTA,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                  ),
                  elevation: 6,
                  shadowColor: AppColors.orangeCTA.withValues(alpha: 0.3),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            '$cartCount',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'View Pre-Cart',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Text(
                      formatPeso(cartTotal),
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
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
  ];
}
