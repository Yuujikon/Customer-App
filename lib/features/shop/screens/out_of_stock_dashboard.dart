import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../shared/models/product.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/inventory_provider.dart';
import '../../orders/providers/order_provider.dart';
import 'product_details_screen.dart';

/// In-memory cache for decoded base64 product image bytes to prevent
/// expensive re-decoding during scrolling and tab transitions.
final Map<String, Uint8List> _imageCache = {};

class OutOfStockDashboardScreen extends StatefulWidget {
  const OutOfStockDashboardScreen({super.key});

  @override
  State<OutOfStockDashboardScreen> createState() =>
      _OutOfStockDashboardScreenState();
}

class _OutOfStockDashboardScreenState extends State<OutOfStockDashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<InventoryProvider>();
    final auth = context.watch<AppAuthProvider>();
    final orderProvider = context.watch<OrderProvider>();

    final String userId = auth.currentUser?.uid ?? auth.email;

    // 1. All Out-of-Stock Products
    final allOosProducts = inventory.outOfStockProducts;

    // 2. Buy again & Favorites IDs
    final buyAgainProductIds =
        orderProvider.getBuyItAgainItems().map((i) => i.productId).toSet();
    final favoriteIds = auth.favorites.toSet();

    // 3. User's Out-of-Stock Wishlist (Favorites, Frequent purchases, or Notifying)
    final wishlistOosProducts = allOosProducts.where((p) {
      return favoriteIds.contains(p.id) ||
          buyAgainProductIds.contains(p.id) ||
          p.isNotifyingUser(userId);
    }).toList();

    // Fast search filtering
    List<Product> applySearch(List<Product> list) {
      if (_searchQuery.trim().isEmpty) return list;
      final q = _searchQuery.toLowerCase();
      return list
          .where((p) =>
              p.name.toLowerCase().contains(q) ||
              p.category.toLowerCase().contains(q))
          .toList();
    }

    final filteredWishlist = applySearch(wishlistOosProducts);
    final filteredAllOos = applySearch(allOosProducts);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Restock Alerts & Sold Out Items',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            Text('Get notified instantly when stock arrives',
                style: TextStyle(fontSize: 11, color: GdcColors.textMuted)),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              // Search Input
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: const Color(0xFFE5EBDD)),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search out-of-stock items...',
                      hintStyle: const TextStyle(
                          fontSize: 13, color: GdcColors.textMuted),
                      prefixIcon: const Icon(Icons.search_rounded,
                          size: 20, color: GdcColors.textMuted),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
              ),
              TabBar(
                controller: _tabController,
                indicatorColor: GdcColors.terracotta,
                labelColor: GdcColors.terracotta,
                unselectedLabelColor: GdcColors.textMuted,
                labelStyle:
                    const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                unselectedLabelStyle:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                tabs: [
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.bookmark_rounded, size: 18),
                        const SizedBox(width: 6),
                        Text('Your Wishlist (${wishlistOosProducts.length})'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.inventory_2_outlined, size: 18),
                        const SizedBox(width: 6),
                        Text('All Unavailable (${allOosProducts.length})'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Your Wishlist OOS items
          _OutOfStockListView(
            products: filteredWishlist,
            userId: userId,
            isWishlistTab: true,
            onRefresh: inventory.refreshData,
          ),
          // Tab 2: All Store OOS items
          _OutOfStockListView(
            products: filteredAllOos,
            userId: userId,
            isWishlistTab: false,
            onRefresh: inventory.refreshData,
          ),
        ],
      ),
    );
  }
}

class _OutOfStockListView extends StatelessWidget {
  final List<Product> products;
  final String userId;
  final bool isWishlistTab;
  final Future<void> Function() onRefresh;

  const _OutOfStockListView({
    super.key,
    required this.products,
    required this.userId,
    required this.isWishlistTab,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: isWishlistTab
                      ? const Color(0xFFE2F0D9)
                      : const Color(0xFFFFF2CC),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isWishlistTab
                      ? Icons.check_circle_outline_rounded
                      : Icons.inventory_rounded,
                  size: 48,
                  color: isWishlistTab
                      ? const Color(0xFF38662A)
                      : const Color(0xFFB25900),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                isWishlistTab
                    ? 'All Your Usuals & Favorites are in Stock! 🎉'
                    : 'No Out-of-Stock Items Found',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: GdcColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                isWishlistTab
                    ? 'None of your favorited products or frequent purchases are currently sold out. Everything you love is available to order right now!'
                    : 'The store currently has high stock availability across all catalog categories.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, color: GdcColors.textMuted, height: 1.4),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.storefront_rounded, size: 18),
                label: const Text('Return to Storefront'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: GdcColors.orangeCTA,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final product = products[index];
          return _OutOfStockProductCard(
            key: ValueKey(product.id),
            product: product,
            userId: userId,
          );
        },
      ),
    );
  }
}

class _OutOfStockProductCard extends StatelessWidget {
  final Product product;
  final String userId;

  const _OutOfStockProductCard({
    super.key,
    required this.product,
    required this.userId,
  });

  Uint8List? _getImageBytes(String? base64Str, String productId) {
    if (base64Str == null || base64Str.isEmpty) return null;
    if (_imageCache.containsKey(productId)) {
      return _imageCache[productId];
    }
    try {
      final cleanBase64 =
          base64Str.contains(',') ? base64Str.split(',').last : base64Str;
      final decoded = base64Decode(cleanBase64.trim());
      _imageCache[productId] = decoded;
      return decoded;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNotifying = product.isNotifyingUser(userId);
    final waitingCount = product.notifyUserIds.length;
    final imageBytes = _getImageBytes(product.photoBase64, product.id);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isNotifying
              ? GdcColors.terracotta.withValues(alpha: 0.4)
              : const Color(0xFFE5EBDD),
          width: isNotifying ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Thumbnail
              GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => ProductDetailsScreen(product: product)),
                ),
                child: Container(
                  width: 76,
                  height: 76,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F7EE),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      imageBytes != null
                          ? ColorFiltered(
                              colorFilter: const ColorFilter.mode(
                                  Colors.grey, BlendMode.saturation),
                              child: Image.memory(
                                imageBytes,
                                fit: BoxFit.cover,
                                width: 76,
                                height: 76,
                                gaplessPlayback: true,
                              ),
                            )
                          : const Center(
                              child: Icon(Icons.inventory_2_outlined,
                                  color: Colors.grey, size: 36),
                            ),
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          color: Colors.black87,
                          child: const Text(
                            'OUT OF STOCK',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 7,
                                fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Product Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: GdcColors.cream,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        product.category.toUpperCase(),
                        style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: GdcColors.textMuted),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.name,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: GdcColors.textPrimary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          formatPeso(product.price),
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              color: GdcColors.terracotta),
                        ),
                        Text(
                          ' / ${product.unit}',
                          style: const TextStyle(
                              fontSize: 11, color: GdcColors.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF0F3EC)),
          const SizedBox(height: 10),

          // Notify Toggle & Status
          Row(
            children: [
              if (waitingCount > 0)
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.people_outline_rounded,
                          size: 14, color: GdcColors.textMuted),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '$waitingCount customer${waitingCount > 1 ? 's' : ''} waiting',
                          style: const TextStyle(
                              fontSize: 11,
                              color: GdcColors.textMuted,
                              fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                )
              else
                const Spacer(),

              // Action Button
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: isNotifying
                    ? ElevatedButton.icon(
                        key: const ValueKey('notifying'),
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final inventory = context.read<InventoryProvider>();
                          await inventory.toggleRestockNotification(
                              product.id, userId);
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Restock notification turned off.'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(Icons.check_circle_rounded,
                            size: 16, color: Colors.white),
                        label: const Text("✓ You'll be notified"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF38662A),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(100)),
                          textStyle: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w900),
                        ),
                      )
                    : OutlinedButton.icon(
                        key: const ValueKey('notify_me'),
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          final inventory = context.read<InventoryProvider>();
                          await inventory.toggleRestockNotification(
                              product.id, userId);
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(
                                  "🔔 Restock Radar Set! We'll alert you as soon as ${product.name} is restocked."),
                              backgroundColor: GdcColors.terracotta,
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        },
                        icon: const Icon(Icons.notifications_active_rounded,
                            size: 16, color: GdcColors.orangeCTA),
                        label: const Text('🔔 Notify Me When Available'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: GdcColors.orangeCTA,
                          side: const BorderSide(
                              color: GdcColors.orangeCTA, width: 1.5),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(100)),
                          textStyle: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w900),
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
