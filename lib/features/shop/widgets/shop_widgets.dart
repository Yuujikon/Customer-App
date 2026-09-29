import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../../shared/models/product.dart';
import '../../../shared/models/order.dart';
import '../../../shared/models/bundle.dart';
import '../providers/inventory_provider.dart';
import '../../orders/providers/order_provider.dart';
import '../../orders/screens/my_orders_screen.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/utils/format.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import 'variant_selection_sheet.dart';

// ── Product tile ───────────────────────────────────────────────────────────

class ProductTile extends StatelessWidget {
  final Product product;
  final bool inCart;
  final bool isOutOfStock;
  final bool isFavorite;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  const ProductTile({
    super.key,
    required this.product,
    required this.inCart,
    required this.onTap,
    required this.onToggleFavorite,
    this.isFavorite = false,
    this.enabled = true,
    this.isOutOfStock = false,
  });

  IconData _getCategoryIcon(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('beverage') || cat.contains('drink')) return Icons.local_drink_rounded;
    if (cat.contains('grain') || cat.contains('rice')) return Icons.grass_rounded;
    if (cat.contains('snack')) return Icons.fastfood_rounded;
    if (cat.contains('household')) return Icons.home_repair_service_rounded;
    if (cat.contains('can')) return Icons.inventory_2_rounded;
    if (cat.contains('noodle')) return Icons.ramen_dining_rounded;
    if (cat.contains('fresh') || cat.contains('veg')) return Icons.eco_rounded;
    return Icons.shopping_basket_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<GdcSemanticColors>();
    final perishableColor = semantic?.perishable ?? Colors.orange;

    final bool hasVariants = product.hasVariants;
    final bool isOutOfStock = product.isOutOfStockForCustomer;
    final int purchasableStock = product.maxPurchasableStock;

    final String priceText;
    if (hasVariants) {
      final range = product.priceRange;
      if (range.length == 2 && range[0] != range[1]) {
        priceText = '${formatPeso(range[0])} - ${formatPeso(range[1])}';
      } else {
        priceText = formatPeso(range[0]);
      }
    } else {
      priceText = formatPeso(product.price);
    }

    final bool isLowStock = purchasableStock > 0 && purchasableStock <= product.lowStockThreshold;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image Area (~40%)
                AspectRatio(
                  aspectRatio: 1.2,
                  child: Stack(
                    children: [
                      Hero(
                        tag: product.id,
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: GdcColors.cream.withValues(alpha: 0.4),
                          ),
                          child: product.photoBase64 != null
                            ? ColorFiltered(
                                colorFilter: isOutOfStock 
                                    ? const ColorFilter.mode(Colors.grey, BlendMode.saturation)
                                    : const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
                                child: Image.memory(base64Decode(product.photoBase64!), fit: BoxFit.cover),
                              )
                            : Center(
                                child: Icon(
                                  _getCategoryIcon(product.category), 
                                  color: GdcColors.terracotta.withValues(alpha: 0.2), 
                                  size: 40
                                ),
                              ),
                        ),
                      ),
                      if (product.isPerishable && !isOutOfStock)
                        Positioned(
                          top: 8, left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: perishableColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              product.pickupWindowHours != null 
                                  ? '${product.pickupWindowHours}H' 
                                  : 'FRESH', 
                              style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
                          ),
                        ),
                      Positioned(
                        top: 4, right: 4,
                        child: GestureDetector(
                          onTap: onToggleFavorite,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isFavorite ? Colors.amber.shade700 : Colors.white.withValues(alpha: 0.9),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ],
                            ),
                            child: Icon(
                              isFavorite ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                              color: isFavorite ? Colors.white : Colors.grey.shade700,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Content Area
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(product.category.toUpperCase(),
                            style: const TextStyle(fontSize: 9, color: GdcColors.textMuted, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                        const SizedBox(height: 2),
                        Text(capitalize(product.name),
                            style: TextStyle(
                              fontWeight: FontWeight.w700, 
                              fontSize: 14, 
                              height: 1.2, 
                              color: isOutOfStock ? Colors.grey.shade400 : GdcColors.textPrimary
                            ),
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        const Spacer(),
                        if (isOutOfStock)
                          NotifyMeButton(productId: product.id)
                        else ...[
                          Text('$purchasableStock ${product.unit} left',
                              style: TextStyle(
                                fontSize: 10, 
                                color: isLowStock ? GdcColors.error : GdcColors.textSecondary, 
                                fontWeight: FontWeight.w600
                              )),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(priceText,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900, 
                                          fontSize: hasVariants ? 13 : 16, 
                                          color: GdcColors.textPrimary
                                        ),
                                        maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 4),
                              Material(
                                color: GdcColors.terracotta.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                                child: InkWell(
                                  onTap: () {
                                    if (hasVariants) {
                                      showModalBottomSheet(
                                        context: context,
                                        isScrollControlled: true,
                                        backgroundColor: Colors.transparent,
                                        builder: (_) => VariantSelectionSheet(product: product),
                                      );
                                    } else {
                                      onTap(); // Navigate to details
                                    }
                                  },
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.add_rounded,
                                          size: 16,
                                          color: GdcColors.terracotta,
                                        ),
                                        SizedBox(width: 2),
                                        Icon(
                                          Icons.shopping_cart_rounded,
                                          size: 14,
                                          color: GdcColors.terracotta,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (isOutOfStock)
              Positioned.fill(
                child: Container(
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
          ],
        ),
      ),
    );
  }
}


// ── Store status chip ──────────────────────────────────────────────────────

class StoreStatusChip extends StatelessWidget {
  final bool isOpen;
  const StoreStatusChip({super.key, required this.isOpen});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
        color: isOpen ? GdcColors.success.withValues(alpha: 0.1) : GdcColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(100),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 6, height: 6, decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isOpen ? GdcColors.success : GdcColors.error)),
      const SizedBox(width: 6),
      Text(isOpen ? 'Open' : 'Closed',
          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800,
              color: isOpen ? GdcColors.success : GdcColors.error)),
    ]),
  );
}

class AnnouncementTicker extends StatefulWidget {
  final String text;
  const AnnouncementTicker({super.key, required this.text});

  @override
  State<AnnouncementTicker> createState() => _AnnouncementTickerState();
}

class _AnnouncementTickerState extends State<AnnouncementTicker> with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScrolling());
  }

  void _startScrolling() async {
    while (_scrollController.hasClients) {
      await Future.delayed(const Duration(seconds: 1));
      if (!_scrollController.hasClients) return;
      
      double maxScroll = _scrollController.position.maxScrollExtent;
      await _scrollController.animateTo(
        maxScroll, 
        duration: Duration(milliseconds: (maxScroll * 30).toInt()), 
        curve: Curves.linear
      );
      
      if (!_scrollController.hasClients) return;
      await Future.delayed(const Duration(seconds: 2));
      
      if (!_scrollController.hasClients) return;
      await _scrollController.animateTo(
        0, 
        duration: const Duration(milliseconds: 1000), 
        curve: Curves.easeOut
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      decoration: BoxDecoration(
        color: GdcColors.terracotta.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(50),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: GdcColors.terracotta,
              borderRadius: BorderRadius.circular(50),
            ),
            child: const Center(
              child: Text('NEWS', 
                  style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ListView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                Center(
                  child: Text(
                    widget.text, 
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: GdcColors.terracotta),
                  ),
                ),
                const SizedBox(width: 100),
              ],
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}

class BundlesSection extends StatelessWidget {
  final List<ProductBundle> bundles;
  final List<Product> allProducts;
  final String currentCategory;
  final Function(ProductBundle) onAdd;

  const BundlesSection({
    super.key,
    required this.bundles,
    required this.allProducts,
    required this.onAdd,
    required this.currentCategory,
  });

  @override
  Widget build(BuildContext context) {
    if (bundles.isEmpty) return const SizedBox.shrink();
    final bool isTablet = Responsive.isTablet(context);
    final double itemWidth = isTablet ? 350 : 300;

    final sortedBundles = List<ProductBundle>.from(bundles)
      ..sort((a, b) {
        if (a.category == currentCategory && b.category != currentCategory) return -1;
        if (a.category != currentCategory && b.category == currentCategory) return 1;
        return 0;
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text('Sulit Bundles', 
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: GdcColors.textPrimary),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              TextButton(
                onPressed: () {}, // See all functionality if needed
                child: const Text('See all →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: GdcColors.terracotta)),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: sortedBundles.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (_, i) {
              final bundle = sortedBundles[i];
              return GestureDetector(
                onTap: () => _showBundleDetails(context, bundle),
                child: Container(
                  width: itemWidth,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Row(
                    children: [
                      Container(
                        width: 100,
                        color: GdcColors.cream.withValues(alpha: 0.3),
                        child: bundle.photoBase64 != null
                          ? Image.memory(base64Decode(bundle.photoBase64!), fit: BoxFit.cover)
                          : const Icon(Icons.auto_awesome_motion_rounded, color: GdcColors.terracotta, size: 32),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(bundle.name, 
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Text(bundle.description, 
                                  style: const TextStyle(fontSize: 11, color: GdcColors.textMuted, height: 1.2),
                                  maxLines: 2, overflow: TextOverflow.ellipsis),
                              const Spacer(),
                              Align(
                                alignment: Alignment.bottomRight,
                                child: ElevatedButton(
                                  onPressed: () => onAdd(bundle),
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(80, 28),
                                    padding: const EdgeInsets.symmetric(horizontal: 12),
                                    backgroundColor: GdcColors.terracotta,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text('ADD ALL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showBundleDetails(BuildContext context, ProductBundle bundle) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(color: GdcColors.cream, borderRadius: BorderRadius.circular(16)),
                  clipBehavior: Clip.antiAlias,
                  child: bundle.photoBase64 != null 
                    ? Image.memory(base64Decode(bundle.photoBase64!), fit: BoxFit.cover)
                    : const Icon(Icons.auto_awesome_motion_rounded, color: GdcColors.terracotta, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(bundle.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                      Text(bundle.category, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: GdcColors.terracotta)),
                      const SizedBox(height: 4),
                      Text(bundle.description, style: const TextStyle(fontSize: 14, color: GdcColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Text('Items in this bundle:', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 12),
            ...bundle.productIds.map((id) {
              Product? p;
              try { p = allProducts.firstWhere((prod) => prod.id == id); } catch (_) {}
              if (p == null) return const SizedBox.shrink();
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: GdcColors.cream,
                  backgroundImage: p.photoBase64 != null ? MemoryImage(base64Decode(p.photoBase64!)) : null,
                  child: p.photoBase64 == null ? const Icon(Icons.inventory_2_outlined, size: 16) : null,
                ),
                title: Text(p.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                subtitle: Text(formatPeso(p.price), style: const TextStyle(fontSize: 13, color: GdcColors.terracotta, fontWeight: FontWeight.bold)),
                trailing: p.stock <= 0 
                  ? const Text('Out of Stock', style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold))
                  : const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
              );
            }),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                onAdd(bundle);
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(60), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
              child: const Text('ADD BUNDLE TO BASKET', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 0.5)),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class UsualBasketSection extends StatelessWidget {
  final List<CartItem> items;
  final List<Product> allProducts;
  final bool Function(String) inCart;
  final Function(Product) onAdd;
  final VoidCallback onAddAll;

  const UsualBasketSection({
    super.key,
    required this.items,
    required this.allProducts,
    required this.inCart,
    required this.onAdd,
    required this.onAddAll,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final bool isTablet = Responsive.isTablet(context);
    final double itemWidth = isTablet ? 200 : 160;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text('Your Usual Items', 
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: GdcColors.textPrimary),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              TextButton(
                onPressed: onAddAll,
                child: const Text('ADD ALL', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: GdcColors.terracotta)),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final item = items[i];
              Product? p;
              try {
                p = allProducts.firstWhere((prod) => prod.id == item.productId);
              } catch (_) {}
              
              if (p == null || p.stock <= 0) return const SizedBox.shrink();

              final added = inCart(p.id);

              return InkWell(
                onTap: () => onAdd(p!),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: itemWidth,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8)],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(color: GdcColors.cream.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(10)),
                        child: Icon(added ? Icons.check_circle_rounded : Icons.history_rounded, size: 20, color: GdcColors.terracotta),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('${item.name}${item.variantName != null ? ' (${item.variantName})' : ''}', 
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: GdcColors.textPrimary),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text(formatPeso(item.price), 
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: GdcColors.terracotta),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class ShopEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const ShopEmptyState({super.key, required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 64, color: GdcColors.terracotta.withValues(alpha: 0.1)),
        const SizedBox(height: 20),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: GdcColors.textPrimary)),
        const SizedBox(height: 6),
        Text(subtitle, style: const TextStyle(fontSize: 13, color: GdcColors.textMuted, fontWeight: FontWeight.w500)),
      ],
    ),
  );
}

class RecentOrderSection extends StatefulWidget {
  final PreOrder? order;
  final VoidCallback onReorder;

  const RecentOrderSection({super.key, required this.order, required this.onReorder});

  @override
  State<RecentOrderSection> createState() => _RecentOrderSectionState();
}

class _RecentOrderSectionState extends State<RecentOrderSection> {
  bool _seeMore = false;

  @override
  Widget build(BuildContext context) {
    if (widget.order == null) return const SizedBox.shrink();
    final orderProvider = context.watch<OrderProvider>();
    final inventory = context.watch<InventoryProvider>();
    final bool isTablet = Responsive.isTablet(context);

    // Get all past completed/cancelled orders to display under "See more"
    final pastOrders = orderProvider.orders.where((o) => 
        o.status == OrderStatus.collected || 
        o.status == OrderStatus.cancelled).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text('Recent Order', 
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: GdcColors.textPrimary),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (pastOrders.isNotEmpty && !_seeMore)
                    TextButton(
                      onPressed: () => setState(() => _seeMore = true),
                      child: const Text('See more →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: GdcColors.terracotta)),
                    ),
                  if (_seeMore) ...[
                    TextButton(
                      onPressed: () => setState(() => _seeMore = false),
                      child: const Text('See less ↑', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                    ),
                    const SizedBox(width: 4),
                    TextButton(
                      onPressed: () {
                        // Navigate to past purchases tab
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const MyOrdersScreen(),
                          ),
                        );
                      },
                      child: const Text('See all →', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: GdcColors.terracotta)),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 20),
          padding: const EdgeInsets.all(16),
          constraints: isTablet ? const BoxConstraints(maxWidth: 500) : null,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(color: GdcColors.cream, shape: BoxShape.circle),
                child: const Icon(Icons.receipt_long_rounded, color: GdcColors.terracotta, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.order!.orderId, 
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: GdcColors.textPrimary),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text('${widget.order!.items.length} item${widget.order!.items.length > 1 ? 's' : ''} · ${formatPeso(widget.order!.total)}', 
                        style: const TextStyle(fontSize: 13, color: GdcColors.textSecondary, fontWeight: FontWeight.w600),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              ElevatedButton(
                onPressed: widget.onReorder,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(100, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  backgroundColor: GdcColors.terracotta.withValues(alpha: 0.1),
                  foregroundColor: GdcColors.terracotta,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('BUY AGAIN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ),
        if (_seeMore) ...[
          const SizedBox(height: 12),
          ...pastOrders.take(3).map((o) => Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.history_toggle_off_rounded, color: Colors.grey, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(o.orderId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text('${o.items.length} item(s) · ${formatPeso(o.total)}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    final result = await orderProvider.reorderItems(o.items, inventory.products);
                    messenger.showSnackBar(SnackBar(
                      content: Text('Added ${result['added']} items to basket.'),
                      backgroundColor: GdcColors.success,
                    ));
                  },
                  child: const Text('BUY AGAIN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: GdcColors.terracotta)),
                ),
              ],
            ),
          )),
        ],
      ],
    );
  }
}

class NotifyMeButton extends StatefulWidget {
  final String productId;
  final bool isLarge;
  const NotifyMeButton({super.key, required this.productId, this.isLarge = false});

  @override
  State<NotifyMeButton> createState() => _NotifyMeButtonState();
}

class _NotifyMeButtonState extends State<NotifyMeButton> {
  bool _isWatching = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  void _checkStatus() async {
    final email = context.read<AppAuthProvider>().email;
    final status = await context.read<InventoryProvider>().isWatching(widget.productId, email);
    if (mounted) setState(() { _isWatching = status; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return SizedBox(height: widget.isLarge ? 54 : 32, child: const Center(child: SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))));

    return InkWell(
      onTap: _isWatching ? null : () async {
        final auth = context.read<AppAuthProvider>();
        final email = auth.email;
        final messenger = ScaffoldMessenger.of(context);
        final inventory = context.read<InventoryProvider>();
        
        await inventory.watchProduct(widget.productId, email);
        
        if (mounted) {
          setState(() => _isWatching = true);
          messenger.showSnackBar(const SnackBar(
            content: Text('We\'ll notify you when it\'s back!'), 
            backgroundColor: GdcColors.success
          ));
        }
      },
      borderRadius: BorderRadius.circular(widget.isLarge ? 16 : 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: widget.isLarge ? double.infinity : null,
        padding: EdgeInsets.symmetric(
          vertical: widget.isLarge ? 16 : 6, 
          horizontal: widget.isLarge ? 24 : 12
        ),
        decoration: BoxDecoration(
          color: _isWatching ? GdcColors.success.withValues(alpha: 0.1) : GdcColors.terracotta.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(widget.isLarge ? 16 : 10),
          border: widget.isLarge ? Border.all(
            color: _isWatching ? GdcColors.success.withValues(alpha: 0.5) : GdcColors.terracotta.withValues(alpha: 0.5),
            width: 2
          ) : null,
        ),
        child: Text(
          _isWatching ? (widget.isLarge ? '✓ NOTIFYING ACTIVE' : 'Notifying') : (widget.isLarge ? 'NOTIFY ME WHEN AVAILABLE' : 'Notify me'), 
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _isWatching ? GdcColors.success : GdcColors.terracotta, 
            fontSize: widget.isLarge ? 13 : 11, 
            fontWeight: FontWeight.w900,
            letterSpacing: widget.isLarge ? 0.5 : 0,
          ),
        ),
      ),
    );
  }
}
