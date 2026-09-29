import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/models/product.dart';
import '../providers/inventory_provider.dart';
import '../../orders/providers/order_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/common/shimmer_loading.dart';
import 'product_details_screen.dart';
import '../widgets/basket_summary_section.dart';
import '../widgets/favorites_section.dart';
import '../widgets/shop_widgets.dart';
import '../../../shared/widgets/common/brand_logo.dart';

import '../../notifications/providers/notification_provider.dart';
import '../../notifications/screens/notification_history_screen.dart';

class ShopScreen extends StatefulWidget {
  final VoidCallback onViewCart;
  const ShopScreen({super.key, required this.onViewCart});
  @override State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  String _cat    = 'All';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<InventoryProvider>();
    final products  = inventory.sortedProducts;
    final orderProvider = context.watch<OrderProvider>();
    final auth      = context.watch<AppAuthProvider>();

    // Initialize orders stream for the current user to populate Recent Orders and Usual Items
    if (auth.email.isNotEmpty) {
      orderProvider.ordersStreamForEmail(auth.email);
    }

    final preCart   = orderProvider.preCart;
    final buyAgainRaw = orderProvider.getBuyItAgainItems();
    // Filter buyAgain to only show items that exist in inventory and are in stock
    final buyAgain = buyAgainRaw.where((item) {
      try {
        final p = inventory.products.firstWhere((prod) => prod.id == item.productId);
        return p.totalStock > 0;
      } catch (_) {
        return false;
      }
    }).toList();

    final favorites = products.where((p) => auth.favorites.contains(p.id)).toList();
    final bundles = inventory.bundles.where((b) => b.isActive).toList();
    final effectivelyClosed = inventory.settings.effectivelyClosed;
    final isOpen    = !effectivelyClosed;

    final cats = ['All', ...inventory.products.map((p) => p.category).toSet().toList()..sort()];
    final filtered = products
        .where((p) => p.status == ProductStatus.published)
        .where((p) => _cat == 'All' || p.category == _cat)
        .where((p) => _search.isEmpty || p.name.toLowerCase().contains(_search.toLowerCase()))
        .toList();

    final cartTotal = preCart.fold(0.0, (s, i) => s + i.price * i.qty);
    final cartCount = preCart.fold(0, (s, i) => s + i.qty);

    final bool isLargeScreen = Responsive.isLargeScreen(context);
    final bool isDesktop = Responsive.isDesktop(context);
    final bool isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final int crossAxisCount = isDesktop ? 4 : (isLargeScreen || isLandscape ? 3 : 2);
    final double childAspectRatio = (isLargeScreen || isLandscape) ? 0.75 : 0.65;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: RefreshIndicator(
        onRefresh: () async {
          await inventory.refreshData();
          await Future.delayed(const Duration(milliseconds: 300));
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              floating: false, pinned: true,
              backgroundColor: Theme.of(context).colorScheme.surface,
              elevation: 0, scrolledUnderElevation: 0,
              toolbarHeight: 80,
              title: Row(
                children: [
                  const BrandLogo(size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Good day,', 
                          style: TextStyle(fontSize: 14, color: GdcColors.textSecondary, fontWeight: FontWeight.w600)),
                        Text('${auth.displayName.split(' ').first} 👋', 
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: GdcColors.textPrimary),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  StoreStatusChip(isOpen: isOpen),
                  const SizedBox(width: 8),
                  Consumer<NotificationProvider?>(
                    builder: (context, provider, _) {
                      final unread = provider?.unreadCount ?? 0;
                      return IconButton(
                        iconSize: 32,
                        icon: Badge(
                          label: Text('$unread', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white)),
                          isLabelVisible: unread > 0,
                          backgroundColor: Colors.redAccent,
                          largeSize: 22,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: const Icon(Icons.notifications_outlined, color: GdcColors.textPrimary, size: 32),
                        ),
                        onPressed: () {
                          if (context.mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const NotificationHistoryScreen()),
                            );
                          }
                        },
                      );
                    },
                  ),
                ],
              ),
            ),

            SliverToBoxAdapter(
              child: StreamBuilder<List<ConnectivityResult>>(
                stream: Connectivity().onConnectivityChanged,
                builder: (context, snapshot) {
                  final results = snapshot.data ?? [];
                  final isOffline = results.contains(ConnectivityResult.none);
                  
                  if (!isOffline) return const SizedBox.shrink();
                  
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    color: GdcColors.error.withValues(alpha: 0.9),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'You are offline. Inventory data might be stale.',
                          style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Search Bar
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(100),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Search items...',
                          prefixIcon: Padding(
                            padding: EdgeInsets.only(left: 8.0),
                            child: Icon(Icons.search_rounded, color: GdcColors.textMuted, size: 24),
                          ),
                          filled: true, 
                          fillColor: Colors.transparent,
                          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                        onChanged: (v) => setState(() => _search = v),
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // 3. Categories
                    SizedBox(
                      height: 44,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: cats.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (_, i) => ChoiceChip(
                          label: Text(cats[i]),
                          selected: _cat == cats[i],
                          onSelected: (selected) => setState(() => _cat = cats[i]),
                          showCheckmark: false,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (inventory.settings.announcement?.isNotEmpty ?? false)
              SliverToBoxAdapter(child: AnnouncementTicker(text: inventory.settings.announcement!)),

            // 0. Active Basket
            if (preCart.isNotEmpty)
              SliverToBoxAdapter(
                child: BasketSummarySection(
                  items: preCart,
                  allProducts: inventory.products,
                  onRemove: (id, variantId) => orderProvider.removeFromPreCart(id, variantId: variantId),
                  onClearAll: () => orderProvider.clearPreCart(),
                ),
              ),

            // 4. Your Usual Items
            if (buyAgain.isNotEmpty)
              SliverToBoxAdapter(
                child: UsualBasketSection(
                  items: buyAgain,
                  allProducts: inventory.products,
                  inCart: (id) => preCart.any((c) => c.productId == id),
                  onAdd: (p) => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailsScreen(product: p))),
                  onAddAll: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final result = await orderProvider.reorderItems(buyAgain, inventory.products);
                    if (mounted) {
                      messenger.showSnackBar(SnackBar(
                        content: Text('${result['added']} items added to basket.'),
                        backgroundColor: GdcColors.success,
                      ));
                    }
                  },
                ),
              ),

            // 5. Recent Orders
            if (orderProvider.recentOrder != null)
              SliverToBoxAdapter(
                child: RecentOrderSection(
                  order: orderProvider.recentOrder,
                  onReorder: () async {
                    if (orderProvider.recentOrder != null) {
                      final messenger = ScaffoldMessenger.of(context);
                      final result = await orderProvider.reorderItems(orderProvider.recentOrder!.items, inventory.products);
                      if (mounted) {
                        messenger.showSnackBar(SnackBar(
                          content: Text('Order items added. ${result['added']} successful.'),
                          backgroundColor: GdcColors.success,
                        ));
                      }
                    }
                  },
                ),
              ),

            // 6. Bundles
            if (bundles.isNotEmpty)
              SliverToBoxAdapter(
                child: BundlesSection(
                  bundles: bundles,
                  allProducts: inventory.products,
                  currentCategory: _cat,
                  onAdd: (bundle) {
                    // Bundles could have items with variants. 
                    // Best to navigate to a bundle detail or product details.
                    // For now, only auto-add if NO variants exist.
                    for (final pid in bundle.productIds) {
                      try {
                        final p = inventory.products.firstWhere((prod) => prod.id == pid);
                        if (!p.hasVariants && p.stock > 0) {
                          orderProvider.addToPreCart(p);
                        } else if (p.hasVariants) {
                           // Prompt selection if variant needed
                           Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailsScreen(product: p)));
                        }
                      } catch (_) {}
                    }
                  },
                ),
              ),

            // 7. Favorites
            if (favorites.isNotEmpty)
              SliverToBoxAdapter(
                child: FavoritesSection(
                  products: favorites,
                  onTap: (p) => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailsScreen(product: p))),
                  onAdd: (p) {
                    if (p.hasVariants) {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailsScreen(product: p)));
                    } else {
                      orderProvider.addToPreCart(p);
                    }
                  },
                  onRemove: (id) => auth.toggleFavorite(id),
                ),
              ),

            if (effectivelyClosed)
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: const Color(0xFFFDECEA), borderRadius: BorderRadius.circular(16)),
                  child: Text(inventory.settings.closureMessage ?? 'STORE CLOSED', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold, color: GdcColors.error)),
                ),
              ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: Text(_cat == 'All' ? 'Recommended for You' : 'Items in $_cat', 
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: GdcColors.textPrimary)),
              ),
            ),
            
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
              sliver: inventory.products.isEmpty 
                ? SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount, 
                      childAspectRatio: childAspectRatio, 
                      crossAxisSpacing: 16, 
                      mainAxisSpacing: 16,
                    ),
                    delegate: SliverChildBuilderDelegate((_, __) => const ShimmerLoading(width: double.infinity, height: 200), childCount: crossAxisCount * 2),
                  )
                : SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount, 
                      childAspectRatio: childAspectRatio, 
                      crossAxisSpacing: 12, 
                      mainAxisSpacing: 12,
                    ),
                    delegate: SliverChildBuilderDelegate((context, i) {
                      final p = filtered[i];
                      final inCart = preCart.any((c) => c.productId == p.id);
                      return ProductTile(
                        product: p,
                        inCart: inCart,
                        isFavorite: auth.favorites.contains(p.id),
                        isOutOfStock: p.stock <= 0,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailsScreen(product: p))),
                        onToggleFavorite: () => auth.toggleFavorite(p.id),
                      );
                    }, childCount: filtered.length),
                  ),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: (preCart.isNotEmpty && !effectivelyClosed)
        ? FloatingActionButton.extended(
            onPressed: widget.onViewCart,
            backgroundColor: GdcColors.terracotta,
            foregroundColor: Colors.white,
            elevation: 8,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
            label: Text('$cartCount items · ${formatPeso(cartTotal)}', style: const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
            icon: const Icon(Icons.shopping_basket_rounded),
          )
        : null,
    );
  }
}
