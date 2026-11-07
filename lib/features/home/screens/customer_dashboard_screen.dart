import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../shared/models/order.dart';
import '../../../shared/models/product.dart';
import '../../../shared/widgets/common/pickup_banner.dart';
import '../../../shared/widgets/common/status_badge.dart';
import '../../auth/providers/auth_provider.dart';
import '../../orders/providers/order_provider.dart';
import '../../shop/providers/inventory_provider.dart';
import '../../shop/screens/out_of_stock_dashboard.dart';
import '../../shop/screens/product_details_screen.dart';
import '../../shop/screens/saved_items_screen.dart';
import '../../shop/widgets/shop_widgets.dart';

class CustomerDashboardScreen extends StatelessWidget {
  final VoidCallback onBrowseCatalog;
  final Function(String category)? onSelectCategory;
  final VoidCallback onViewCart;
  final VoidCallback onViewOrders;

  const CustomerDashboardScreen({
    super.key,
    required this.onBrowseCatalog,
    this.onSelectCategory,
    required this.onViewCart,
    required this.onViewOrders,
  });

  void _showQrCode(BuildContext context, PreOrder order) {
    if (order.status == OrderStatus.pending) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order is still at the pending stage.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final qrData = order.orderId.trim().isNotEmpty ? order.orderId : order.id;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Colors.white,
        title: Column(
          children: [
            const Text('Pickup QR Code',
                style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(order.orderId,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.forest)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Show this QR code to the store attendant when picking up your order.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SizedBox(
                width: 200,
                height: 200,
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 200.0,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square, color: Colors.black),
                  dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Colors.black),
                  errorStateBuilder: (c, err) => Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.qr_code_2_rounded,
                          size: 80, color: AppColors.forest),
                      const SizedBox(height: 8),
                      Text(order.orderId,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CLOSE',
                  style: TextStyle(fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AppAuthProvider>();
    final inventory = context.watch<InventoryProvider>();
    final orderProvider = context.watch<OrderProvider>();

    if (auth.email.isNotEmpty) {
      orderProvider.ordersStreamForEmail(auth.email);
    }

    final preCart = orderProvider.preCart;
    final allOrders = orderProvider.orders;

    final activeOrders = allOrders
        .where((o) =>
            o.status != OrderStatus.collected &&
            o.status != OrderStatus.cancelled &&
            o.status != OrderStatus.refunded &&
            o.status != OrderStatus.refundRejected &&
            !o.isExpired)
        .toList()
      ..sort((a, b) {
        final aReady = a.status == OrderStatus.ready;
        final bReady = b.status == OrderStatus.ready;
        if (aReady && !bReady) return -1;
        if (!aReady && bReady) return 1;
        return a.createdAt.compareTo(b.createdAt);
      });

    final collectedOrders =
        allOrders.where((o) => o.status == OrderStatus.collected).toList();
    final totalSpent = collectedOrders.fold(0.0, (sum, o) => sum + o.total);

    final cartTotal = preCart.fold(0.0, (s, i) => s + i.price * i.qty);
    final cartItemCount = preCart.fold(0, (s, i) => s + i.qty);

    final allFavorites =
        inventory.products.where((p) => auth.favorites.contains(p.id)).toList();
    final favoriteOosCount =
        allFavorites.where((p) => p.isOutOfStockForCustomer).length;

    final featuredProducts = inventory.products.isNotEmpty
        ? inventory.products
            .where((p) =>
                p.status == ProductStatus.published &&
                !p.isOutOfStockForCustomer)
            .take(6)
            .toList()
        : _sampleFreshPicks;

    final allOosCount = inventory.outOfStockProducts.length;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: RefreshIndicator(
        onRefresh: () async {
          await inventory.refreshData();
          await Future.delayed(const Duration(milliseconds: 400));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Announcement Ticker if available
              if (inventory.settings.announcement?.isNotEmpty ?? false) ...[
                AnnouncementTicker(text: inventory.settings.announcement!),
                const SizedBox(height: 16),
              ],

              // 1. Promotional Hero Banner
              _DashboardHeroCard(onBrowseCatalog: onBrowseCatalog),

              const SizedBox(height: 20),

              // 2. Quick Shortcut Launch Bar
              _QuickShortcutBar(
                onCatalog: onBrowseCatalog,
                onRestockRadar: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const OutOfStockDashboardScreen()),
                  );
                },
                onOrders: onViewOrders,
                onFavorites: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const SavedItemsScreen()),
                  );
                },
                activeOrdersCount: activeOrders.length,
                oosCount: allOosCount,
                favoriteCount: allFavorites.length,
              ),

              const SizedBox(height: 16),

              // 3. Restock Radar Alert Banner
              if (allOosCount > 0) ...[
                _RestockRadarBanner(
                  allOosCount: allOosCount,
                  favoriteOosCount: favoriteOosCount,
                ),
                const SizedBox(height: 16),
              ],

              // 4. Explore Categories (Left) & Recent Purchase (Right) Side-by-Side
              if (orderProvider.recentOrder != null)
                LayoutBuilder(
                  builder: (context, constraints) {
                    final bool isWide = constraints.maxWidth >= 480;
                    if (isWide) {
                      return IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              flex: 2,
                              child: _buildPremiumCategoryGridCard(context),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: _buildRecentPurchaseCard(
                                  context, orderProvider),
                            ),
                          ],
                        ),
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPremiumCategoryGridCard(context),
                        const SizedBox(height: 12),
                        _buildRecentPurchaseCard(context, orderProvider),
                      ],
                    );
                  },
                )
              else
                _buildPremiumCategoryGridCard(context),

              const SizedBox(height: 20),

              // 5. Active Order Flight Tracker
              if (activeOrders.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Active Order Status',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryText),
                    ),
                    TextButton(
                      onPressed: onViewOrders,
                      child: const Text('View All',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: AppColors.forest)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...activeOrders.take(2).map((order) => _ActiveOrderCard(
                      order: order,
                      onShowQr: () => _showQrCode(context, order),
                      onTrack: onViewOrders,
                    )),
                const SizedBox(height: 16),
              ],

              // 6. Personal Shopper Overview Card
              _ShopperOverviewCard(
                totalSpent: totalSpent,
                completedCount: collectedOrders.length,
                cartTotal: cartTotal,
                cartItemCount: cartItemCount,
                userEmail:
                    auth.email.isNotEmpty ? auth.email : 'andrea.m@email.com',
                onViewCart: onViewCart,
              ),

              const SizedBox(height: 24),

              // 8. Fresh Essentials Featured Row
              if (featuredProducts.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Fresh Essentials Today',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryText),
                    ),
                    TextButton(
                      onPressed: onBrowseCatalog,
                      child: const Text('See All →',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: AppColors.forest)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 270,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: featuredProducts.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 14),
                    itemBuilder: (_, i) {
                      final p = featuredProducts[i];
                      final inCart =
                          orderProvider.preCart.any((c) => c.productId == p.id);
                      return SizedBox(
                        width: 165,
                        child: ProductTile(
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
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // 9. Mobile Pickup Banner
              PickupBanner(onStartOrder: onBrowseCatalog),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Map<String, dynamic> _getCategoryVisuals(String catName) {
    final lower = catName.toLowerCase();
    if (lower.contains('fresh') ||
        lower.contains('veg') ||
        lower.contains('produce') ||
        lower.contains('fruit')) {
      return {
        'label': catName,
        'subtitle': 'Fresh produce & fruits',
        'icon': Icons.eco_rounded,
        'bgColor': const Color(0xFFE2F0D9),
        'iconColor': const Color(0xFF38662A),
      };
    }
    if (lower.contains('beverage') ||
        lower.contains('drink') ||
        lower.contains('juice')) {
      return {
        'label': catName,
        'subtitle': 'Juice, soda & drinks',
        'icon': Icons.local_drink_rounded,
        'bgColor': const Color(0xFFDDEBF7),
        'iconColor': const Color(0xFF1F4E79),
      };
    }
    if (lower.contains('snack') ||
        lower.contains('chip') ||
        lower.contains('candy')) {
      return {
        'label': catName,
        'subtitle': 'Chips & treats',
        'icon': Icons.fastfood_rounded,
        'bgColor': const Color(0xFFFFF2CC),
        'iconColor': const Color(0xFFB25900),
      };
    }
    if (lower.contains('can') || lower.contains('soup')) {
      return {
        'label': catName,
        'subtitle': 'Canned meats & soup',
        'icon': Icons.inventory_2_rounded,
        'bgColor': const Color(0xFFFCE4D6),
        'iconColor': const Color(0xFFC55A11),
      };
    }
    if (lower.contains('bakery') ||
        lower.contains('bread') ||
        lower.contains('pastry')) {
      return {
        'label': catName,
        'subtitle': 'Fresh bread & pastries',
        'icon': Icons.bakery_dining_rounded,
        'bgColor': const Color(0xFFF5E6CC),
        'iconColor': const Color(0xFF8C6239),
      };
    }
    if (lower.contains('grain') ||
        lower.contains('rice') ||
        lower.contains('staple')) {
      return {
        'label': catName,
        'subtitle': 'Rice & staples',
        'icon': Icons.rice_bowl_rounded,
        'bgColor': const Color(0xFFF5E6CC),
        'iconColor': const Color(0xFF8C6239),
      };
    }
    if (lower.contains('house') ||
        lower.contains('pantry') ||
        lower.contains('clean')) {
      return {
        'label': catName,
        'subtitle': 'Pantry & home essentials',
        'icon': Icons.home_repair_service_rounded,
        'bgColor': const Color(0xFFE8E8E8),
        'iconColor': const Color(0xFF595959),
      };
    }
    return {
      'label': catName,
      'subtitle': 'Store items',
      'icon': Icons.shopping_basket_rounded,
      'bgColor': const Color(0xFFE2ECD8),
      'iconColor': const Color(0xFF3E6B34),
    };
  }

  /// Compact Explore Categories Vertical Container Card
  Widget _buildPremiumCategoryGridCard(BuildContext context) {
    final inventory = context.watch<InventoryProvider>();

    final List<String> catNames = inventory.products
        .map((p) => p.category.trim())
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();

    final List<Map<String, dynamic>> categories = (catNames.isNotEmpty
        ? catNames.map((name) => _getCategoryVisuals(name)).toList()
        : [
            _getCategoryVisuals('Bakery'),
            _getCategoryVisuals('Beverages'),
            _getCategoryVisuals('Canned Goods'),
            _getCategoryVisuals('Fresh Produce'),
            _getCategoryVisuals('Household'),
            _getCategoryVisuals('Snacks'),
          ]);

    categories.sort((a, b) {
      final String labelA = (a['label'] as String).toLowerCase();
      final String labelB = (b['label'] as String).toLowerCase();
      if (labelA == 'others') return 1;
      if (labelB == 'others') return -1;
      return labelA.compareTo(labelB);
    });

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.sageTint,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Discover',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        color: AppColors.forest,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Explore Categories',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryText,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: onBrowseCatalog,
                child: const Text(
                  'See All →',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: AppColors.forest,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Column(
            children: categories.map((cat) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: _buildCategoryTile(cat),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentPurchaseCard(
      BuildContext context, OrderProvider orderProvider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.sageTint,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Reorder Quickly',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        color: AppColors.forest,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Recent Purchase',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryText,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: onViewOrders,
                child: const Text(
                  'View All →',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11.5,
                    color: AppColors.forest,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          RecentOrderSection(
            order: orderProvider.recentOrder,
            onReorder: () async {
              final messenger = ScaffoldMessenger.of(context);
              final invProvider = context.read<InventoryProvider>();
              final result = await orderProvider.reorderItems(
                  orderProvider.recentOrder!.items, invProvider.products);
              messenger.showSnackBar(SnackBar(
                content: Text(
                    'Order items added to basket. (${result['added']} items)'),
                backgroundColor: AppColors.forest,
                behavior: SnackBarBehavior.floating,
              ));
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTile(Map<String, dynamic> cat) {
    final String label = cat['label'] as String;
    return InkWell(
      onTap: () {
        if (onSelectCategory != null) {
          onSelectCategory!(label);
        } else {
          onBrowseCatalog();
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.warmSurface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: cat['bgColor'] as Color,
                shape: BoxShape.circle,
              ),
              child: Icon(
                cat['icon'] as IconData,
                color: cat['iconColor'] as Color,
                size: 12,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    cat['label'] as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryText,
                    ),
                  ),
                  Text(
                    cat['subtitle'] as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.mutedText,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 14,
              color: AppColors.mutedText,
            ),
          ],
        ),
      ),
    );
  }

  static const List<Product> _sampleFreshPicks = [
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
      category: 'Best Value',
      shelfDays: 7,
    ),
    Product(
      id: 'p4',
      name: 'Farm Fresh Mix',
      unit: '1 bundle',
      price: 189.00,
      stock: 12,
      category: 'Perishable',
      shelfDays: 3,
    ),
  ];
}

class _DashboardHeroCard extends StatelessWidget {
  final VoidCallback onBrowseCatalog;

  const _DashboardHeroCard({required this.onBrowseCatalog});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isTablet = constraints.maxWidth >= 550;

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.deepForest, AppColors.forest],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: AppColors.deepForest.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              Positioned(
                top: -40,
                right: -40,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.04),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: isTablet
                    ? Row(
                        children: [
                          Expanded(flex: 6, child: _buildHeroTextContent()),
                          const SizedBox(width: 20),
                          Expanded(flex: 5, child: _buildHeroImageWithBadge()),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildHeroTextContent(),
                          const SizedBox(height: 20),
                          _buildHeroImageWithBadge(),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeroTextContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'FRESH PICKS, EVERY DAY',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w800,
            color: AppColors.sage,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        RichText(
          text: const TextSpan(
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.2,
              letterSpacing: -0.5,
              fontFamily: 'Plus Jakarta Sans',
            ),
            children: [
              TextSpan(
                  text: 'Fresh essentials,\n',
                  style: TextStyle(color: Colors.white)),
              TextSpan(
                  text: 'ready when you are.',
                  style: TextStyle(color: AppColors.sageTint)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Pre-order produce, snacks, and daily essentials. We’ll have everything packed for quick pickup.',
          style: TextStyle(
            fontSize: 12.5,
            color: Color(0xFFD3E0C9),
            height: 1.35,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          onPressed: onBrowseCatalog,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.orangeCTA,
            foregroundColor: Colors.white,
            minimumSize: const Size(160, 46),
            padding: const EdgeInsets.symmetric(horizontal: 22),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100)),
            elevation: 0,
            textStyle:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
          icon: const Text('Shop the catalog'),
          label: const Icon(Icons.arrow_forward_rounded, size: 16),
        ),
      ],
    );
  }

  Widget _buildHeroImageWithBadge() {
    return Stack(
      children: [
        Container(
          height: 160,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: Colors.white.withValues(alpha: 0.08),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Image.network(
              'https://images.unsplash.com/photo-1714386893630-b7a148f77efd?auto=format&fit=crop&w=1200&q=90',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Center(
                child: Icon(Icons.shopping_basket_rounded,
                    size: 64, color: Colors.white54),
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 10,
          right: 10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.94),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 3)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: const [
                Text(
                  'Picked fresh',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryText,
                      height: 1.1),
                ),
                Text(
                  'Just for you',
                  style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.mutedText),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickShortcutBar extends StatelessWidget {
  final VoidCallback onCatalog;
  final VoidCallback onRestockRadar;
  final VoidCallback onOrders;
  final VoidCallback onFavorites;
  final int activeOrdersCount;
  final int oosCount;
  final int favoriteCount;

  const _QuickShortcutBar({
    required this.onCatalog,
    required this.onRestockRadar,
    required this.onOrders,
    required this.onFavorites,
    required this.activeOrdersCount,
    required this.oosCount,
    required this.favoriteCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ShortcutTile(
          icon: Icons.storefront_rounded,
          label: 'Catalog',
          color: const Color(0xFF38662A),
          bgColor: const Color(0xFFE2F0D9),
          onTap: onCatalog,
        ),
        const SizedBox(width: 8),
        _ShortcutTile(
          icon: Icons.notifications_active_rounded,
          label: 'Restock',
          badgeCount: oosCount,
          color: AppColors.orangeCTA,
          bgColor: const Color(0xFFFFF6ED),
          onTap: onRestockRadar,
        ),
        const SizedBox(width: 8),
        _ShortcutTile(
          icon: Icons.receipt_long_rounded,
          label: 'Orders',
          badgeCount: activeOrdersCount,
          color: AppColors.forest,
          bgColor: const Color(0xFFFDECEA),
          onTap: onOrders,
        ),
        const SizedBox(width: 8),
        _ShortcutTile(
          icon: Icons.favorite_rounded,
          label: 'Saved',
          badgeCount: favoriteCount,
          color: Colors.amber.shade800,
          bgColor: const Color(0xFFFFF9E6),
          onTap: onFavorites,
        ),
      ],
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final int? badgeCount;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  const _ShortcutTile({
    required this.icon,
    required this.label,
    this.badgeCount,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            children: [
              Badge(
                label: Text('${badgeCount ?? 0}'),
                isLabelVisible: (badgeCount ?? 0) > 0,
                backgroundColor: color,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration:
                      BoxDecoration(color: bgColor, shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 20),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryText),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RestockRadarBanner extends StatelessWidget {
  final int allOosCount;
  final int favoriteOosCount;

  const _RestockRadarBanner({
    required this.allOosCount,
    required this.favoriteOosCount,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const OutOfStockDashboardScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF6ED),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.orangeCTA.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: AppColors.orangeCTA.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: AppColors.orangeCTA,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.notifications_active_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Restock Radar Alerts',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryText),
                      ),
                      const SizedBox(width: 6),
                      if (favoriteOosCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.forest,
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: Text(
                            '$favoriteOosCount Fav Sold Out',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w800),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    favoriteOosCount > 0
                        ? '$favoriteOosCount favorited item${favoriteOosCount > 1 ? 's are' : ' is'} out of stock. Tap to configure restock alerts.'
                        : '$allOosCount store items are sold out. Tap to set arrival notifications.',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.mutedText, height: 1.3),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: AppColors.orangeCTA),
          ],
        ),
      ),
    );
  }
}

class _ActiveOrderCard extends StatelessWidget {
  final PreOrder order;
  final VoidCallback onShowQr;
  final VoidCallback onTrack;

  const _ActiveOrderCard({
    required this.order,
    required this.onShowQr,
    required this.onTrack,
  });

  @override
  Widget build(BuildContext context) {
    final int availableMins =
        OrderProvider.getAvailableExtensionMinutes(order.expiresAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: order.status == OrderStatus.ready
              ? AppColors.forest.withValues(alpha: 0.6)
              : AppColors.forest.withValues(alpha: 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.forest.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.receipt_long_rounded,
                        color: AppColors.forest, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        order.orderId,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: AppColors.primaryText),
                      ),
                      Text(
                        '${order.items.length} item${order.items.length > 1 ? 's' : ''} · ₱${order.total.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.mutedText,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
              StatusBadge(order.status),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onShowQr,
                  icon: const Icon(Icons.qr_code_2_rounded, size: 16),
                  label: const Text('SHOW QR CODE',
                      style:
                          TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: order.status == OrderStatus.pending
                        ? AppColors.mutedText
                        : AppColors.forest,
                    side: BorderSide(
                      color: order.status == OrderStatus.pending
                          ? AppColors.border
                          : AppColors.forest,
                      width: 1.2,
                    ),
                    minimumSize: const Size(double.infinity, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onTrack,
                  icon: const Icon(Icons.near_me_rounded, size: 15),
                  label: const Text('TRACK ORDER',
                      style:
                          TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.orangeCTA,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100)),
                  ),
                ),
              ),
            ],
          ),
          if (availableMins > 0) ...[
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  HapticFeedback.lightImpact();
                  final messenger = ScaffoldMessenger.of(context);
                  final op = context.read<OrderProvider>();
                  final ext = await op.extendOrderPickupTime(order.id);
                  if (ext > 0) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                            '⏱ Pickup time extended by $ext mins! Extended up to 3:00 PM cutoff.'),
                        backgroundColor: AppColors.forest,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.timer_outlined, size: 15),
                label: Text(
                  'EXTEND PICKUP (+ $availableMins MIN)',
                  style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w900),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.orangeCTA,
                  side: const BorderSide(color: AppColors.orangeCTA, width: 1.2),
                  minimumSize: const Size(double.infinity, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ShopperOverviewCard extends StatelessWidget {
  final double totalSpent;
  final int completedCount;
  final double cartTotal;
  final int cartItemCount;
  final String userEmail;
  final VoidCallback onViewCart;

  const _ShopperOverviewCard({
    required this.totalSpent,
    required this.completedCount,
    required this.cartTotal,
    required this.cartItemCount,
    required this.userEmail,
    required this.onViewCart,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.forest.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(50),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.stars_rounded,
                        color: AppColors.forest, size: 14),
                    SizedBox(width: 6),
                    Text('Customer Account',
                        style: TextStyle(
                            color: AppColors.forest,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Expanded(
                child: Text(
                  userEmail,
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(color: AppColors.mutedText, fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _ShopperTile(
                label: 'TOTAL SPENT',
                value: formatPeso(totalSpent),
                icon: Icons.account_balance_wallet_rounded,
                color: AppColors.forest,
              ),
              const SizedBox(width: 12),
              _ShopperTile(
                label: 'COMPLETED',
                value: '$completedCount orders',
                icon: Icons.check_circle_rounded,
                color: AppColors.forest,
              ),
              const SizedBox(width: 12),
              _ShopperTile(
                label: 'BASKET TOTAL',
                value: formatPeso(cartTotal),
                icon: Icons.shopping_basket_rounded,
                color: AppColors.orangeCTA,
              ),
            ],
          ),
          if (cartItemCount > 0) ...[
            const SizedBox(height: 14),
            InkWell(
              onTap: onViewCart,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.orangeCTA.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppColors.orangeCTA.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.shopping_bag_rounded,
                            size: 16, color: AppColors.orangeCTA),
                        const SizedBox(width: 8),
                        Text(
                          '$cartItemCount item${cartItemCount > 1 ? 's' : ''} in basket (${formatPeso(cartTotal)})',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryText),
                        ),
                      ],
                    ),
                    const Text(
                      'CHECKOUT →',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: AppColors.orangeCTA),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ShopperTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _ShopperTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                      color: AppColors.mutedText,
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
                color: color, fontSize: 13, fontWeight: FontWeight.w900),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _CategoryAvatarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bgColor;
  final Color iconColor;
  final VoidCallback onTap;

  const _CategoryAvatarItem({
    required this.icon,
    required this.label,
    required this.bgColor,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(right: 16),
        child: Column(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: bgColor.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryText),
            ),
          ],
        ),
      ),
    );
  }
}
