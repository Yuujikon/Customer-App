import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../../../shared/models/product.dart';
import '../../../shared/models/order.dart';
import '../../../shared/models/bundle.dart';
import '../../../shared/widgets/common/status_badge.dart';
import '../providers/inventory_provider.dart';
import '../../orders/providers/order_provider.dart';
import '../../../core/utils/format.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import 'variant_selection_sheet.dart';

final Map<String, Uint8List> _base64BytesCache = {};

Uint8List? _getDecodedImageBytes(String? base64Str, String productId) {
  if (base64Str == null || base64Str.isEmpty) return null;
  if (_base64BytesCache.containsKey(productId)) {
    return _base64BytesCache[productId];
  }
  try {
    final cleanBase64 =
        base64Str.contains(',') ? base64Str.split(',').last : base64Str;
    final decoded = base64Decode(cleanBase64.trim());
    _base64BytesCache[productId] = decoded;
    return decoded;
  } catch (_) {
    return null;
  }
}

// ── Product Tile / Product Card Widget ────────────────────────────────────

/// Responsive, fixed-ratio compact Product Card widget with capped & non-negative quantity management
class ProductTile extends StatelessWidget {
  final Product product;
  final bool inCart;
  final bool isOutOfStock;
  final bool isFavorite;
  final bool enabled;
  final String? heroTag;
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
    this.heroTag,
  });

  IconData _getCategoryIcon(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('beverage') || cat.contains('drink'))
      return Icons.local_drink_rounded;
    if (cat.contains('grain') || cat.contains('rice'))
      return Icons.grass_rounded;
    if (cat.contains('snack')) return Icons.fastfood_rounded;
    if (cat.contains('household')) return Icons.home_repair_service_rounded;
    if (cat.contains('can')) return Icons.inventory_2_rounded;
    if (cat.contains('noodle')) return Icons.ramen_dining_rounded;
    if (cat.contains('fresh') || cat.contains('veg')) return Icons.eco_rounded;
    return Icons.shopping_basket_rounded;
  }

  void _showEditProductQuantityDialog(
    BuildContext context,
    Product product,
    int currentQty,
    int maxStock,
    OrderProvider orderProvider,
  ) {
    final ctrl = TextEditingController(text: '$currentQty');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Modify Quantity',
            style: TextStyle(fontWeight: FontWeight.w900)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              product.name,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryText),
            ),
            const SizedBox(height: 4),
            Text(
              'Available Stock: $maxStock ${product.unit}',
              style: const TextStyle(fontSize: 12, color: AppColors.mutedText),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Quantity',
                hintText: 'Enter quantity',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = int.tryParse(ctrl.text.trim());
              if (val == null || val <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Quantity must be at least 1.')),
                );
                return;
              }

              final clamped = val.clamp(1, maxStock);
              orderProvider.setPreCartQty(
                product.id,
                clamped,
                maxStock,
              );

              Navigator.pop(ctx);

              if (val > maxStock) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Quantity capped at maximum available stock ($maxStock).'),
                    backgroundColor: AppColors.orangeCTA,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.orangeCTA,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100)),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<GdcSemanticColors>();
    final perishableColor = semantic?.perishable ?? GdcColors.warning;

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

    final bool isLowStock =
        purchasableStock > 0 && purchasableStock <= product.lowStockThreshold;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: inCart
                ? GdcColors.terracotta.withValues(alpha: 0.5)
                : Theme.of(context).dividerColor,
            width: inCart ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Fixed Square Image Ratio (1:1 AspectRatio with BoxFit.cover)
                AspectRatio(
                  aspectRatio: 1.0,
                  child: Stack(
                    children: [
                      Hero(
                        tag: heroTag ?? product.id,
                        child: Container(
                          width: double.infinity,
                          height: double.infinity,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerLow,
                          ),
                          child: product.photoBase64 != null
                              ? ColorFiltered(
                                  colorFilter: isOutOfStock
                                      ? const ColorFilter.mode(
                                          Colors.grey, BlendMode.saturation)
                                      : const ColorFilter.mode(
                                          Colors.transparent,
                                          BlendMode.multiply),
                                  child: Image.memory(
                                    base64Decode(product.photoBase64!),
                                    fit: BoxFit.cover,
                                    alignment: Alignment.center,
                                  ),
                                )
                              : Center(
                                  child: Icon(
                                    _getCategoryIcon(product.category),
                                    color: GdcColors.terracotta
                                        .withValues(alpha: 0.25),
                                    size: 40,
                                  ),
                                ),
                        ),
                      ),

                      // Direct Red Trash Delete Button (When Item is in Basket)
                      if (inCart)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              final op = context.read<OrderProvider>();
                              op.removeFromPreCart(product.id);
                              ScaffoldMessenger.of(context)
                                  .hideCurrentSnackBar();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Removed "${product.name}" from pre-cart.'),
                                  backgroundColor: AppColors.orangeCTA,
                                  duration: const Duration(seconds: 1),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.red.shade600,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.18),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        ),

                      // Status / Fresh / Perishable Badge
                      if (product.isPerishable && !isOutOfStock)
                        Positioned(
                          top: 8,
                          left: inCart ? 36 : 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: perishableColor,
                              borderRadius: BorderRadius.circular(6),
                              boxShadow: [
                                BoxShadow(
                                  color: perishableColor.withValues(alpha: 0.3),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ],
                            ),
                            child: Text(
                              product.pickupWindowHours != null
                                  ? 'FRESH · ${product.pickupWindowHours}H'
                                  : 'FRESH PRODUCE',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ),
                        ),

                      // Favorite Bookmark Button
                      Positioned(
                        top: 8,
                        right: 8,
                        child: GestureDetector(
                          onTap: onToggleFavorite,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isFavorite
                                  ? Colors.amber.shade700
                                  : (Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerLow
                                      : Colors.white.withValues(alpha: 0.92)),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                )
                              ],
                            ),
                            child: Icon(
                              isFavorite
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              color: isFavorite
                                  ? Colors.white
                                  : Theme.of(context).colorScheme.onSurface,
                              size: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. Compact Content Area
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.category.toUpperCase(),
                          style: TextStyle(
                            fontSize: 9,
                            color: Theme.of(context).textTheme.bodySmall?.color,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          capitalize(product.name),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
                            height: 1.2,
                            color: isOutOfStock
                                ? Colors.grey.shade400
                                : Theme.of(context).colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        if (isOutOfStock)
                          Text(
                            'Out of Stock',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color:
                                  Theme.of(context).textTheme.bodySmall?.color,
                            ),
                          )
                        else ...[
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isLowStock
                                      ? GdcColors.error
                                      : GdcColors.success,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '$purchasableStock ${product.unit} left',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isLowStock
                                        ? GdcColors.error
                                        : Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.color,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  priceText,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: hasVariants ? 12 : 13.5,
                                    color: GdcColors.terracotta,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Consumer<OrderProvider>(
                                builder: (context, orderProvider, _) {
                                  final matchingCartItems = orderProvider
                                      .preCart
                                      .where((c) => c.productId == product.id)
                                      .toList();
                                  final bool itemInCart =
                                      matchingCartItems.isNotEmpty;
                                  final int cartQty = matchingCartItems.fold(
                                      0, (sum, c) => sum + c.qty);

                                  if (itemInCart && !hasVariants) {
                                    return Container(
                                      height: 28,
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.sageTint,
                                        borderRadius:
                                            BorderRadius.circular(100),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.center,
                                        children: [
                                          InkWell(
                                            onTap: () {
                                              if (cartQty <= 1) {
                                                orderProvider.removeFromPreCart(
                                                    product.id);
                                              } else {
                                                orderProvider.adjustPreCartQty(
                                                    product.id,
                                                    -1,
                                                    purchasableStock);
                                              }
                                            },
                                            borderRadius:
                                                BorderRadius.circular(100),
                                            child: const Padding(
                                              padding: EdgeInsets.all(4),
                                              child: Icon(Icons.remove_rounded,
                                                  size: 13,
                                                  color: AppColors.forest),
                                            ),
                                          ),
                                          InkWell(
                                            onTap: () =>
                                                _showEditProductQuantityDialog(
                                              context,
                                              product,
                                              cartQty,
                                              purchasableStock,
                                              orderProvider,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 5,
                                                      vertical: 2),
                                              child: Text(
                                                '$cartQty',
                                                style: const TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: AppColors.forest,
                                                ),
                                              ),
                                            ),
                                          ),
                                          InkWell(
                                            onTap: () {
                                              if (cartQty >= purchasableStock) {
                                                ScaffoldMessenger.of(context)
                                                    .hideCurrentSnackBar();
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                        'Maximum stock reached ($purchasableStock available).'),
                                                    backgroundColor:
                                                        AppColors.orangeCTA,
                                                    duration: const Duration(
                                                        seconds: 2),
                                                  ),
                                                );
                                              } else {
                                                orderProvider.adjustPreCartQty(
                                                    product.id,
                                                    1,
                                                    purchasableStock);
                                              }
                                            },
                                            borderRadius:
                                                BorderRadius.circular(100),
                                            child: const Padding(
                                              padding: EdgeInsets.all(4),
                                              child: Icon(Icons.add_rounded,
                                                  size: 13,
                                                  color: AppColors.forest),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }

                                  return Material(
                                    color: GdcColors.orangeCTA,
                                    borderRadius: BorderRadius.circular(100),
                                    elevation: 2,
                                    child: InkWell(
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        if (hasVariants) {
                                          showModalBottomSheet(
                                            context: context,
                                            isScrollControlled: true,
                                            backgroundColor: Colors.transparent,
                                            builder: (_) =>
                                                VariantSelectionSheet(
                                                    product: product),
                                          );
                                        } else {
                                          orderProvider.addToPreCart(product);
                                        }
                                      },
                                      borderRadius: BorderRadius.circular(100),
                                      child: Container(
                                        height: 30,
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.add_rounded,
                                              size: 16,
                                              color: Colors.white,
                                            ),
                                            SizedBox(width: 2),
                                            Text(
                                              'ADD',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 10.5,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 0.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
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
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Alias for ProductTile to adhere to ProductCard naming convention
typedef ProductCard = ProductTile;

// ── Store status chip ──────────────────────────────────────────────────────

class StoreStatusChip extends StatelessWidget {
  final bool isOpen;
  const StoreStatusChip({super.key, required this.isOpen});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isOpen
              ? GdcColors.success.withValues(alpha: 0.1)
              : GdcColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isOpen ? GdcColors.success : GdcColors.error)),
          const SizedBox(width: 6),
          Text(isOpen ? 'Open' : 'Closed',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
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

class _AnnouncementTickerState extends State<AnnouncementTicker>
    with SingleTickerProviderStateMixin {
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
      await _scrollController.animateTo(maxScroll,
          duration: Duration(milliseconds: (maxScroll * 30).toInt()),
          curve: Curves.linear);

      if (!_scrollController.hasClients) return;
      await Future.delayed(const Duration(seconds: 2));

      if (!_scrollController.hasClients) return;
      await _scrollController.animateTo(0,
          duration: const Duration(milliseconds: 1000), curve: Curves.easeOut);
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
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5)),
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
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: GdcColors.terracotta),
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
        if (a.category == currentCategory && b.category != currentCategory)
          return -1;
        if (a.category != currentCategory && b.category == currentCategory)
          return 1;
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
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: GdcColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              TextButton(
                onPressed: () {},
                child: const Text('See all →',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: GdcColors.terracotta)),
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
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4))
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Row(
                    children: [
                      Container(
                        width: 100,
                        color: GdcColors.cream.withValues(alpha: 0.3),
                        child: bundle.photoBase64 != null
                            ? Image.memory(base64Decode(bundle.photoBase64!),
                                fit: BoxFit.cover)
                            : const Icon(Icons.auto_awesome_motion_rounded,
                                color: GdcColors.terracotta, size: 32),
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(bundle.name,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Text(bundle.description,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: GdcColors.textMuted,
                                      height: 1.2),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis),
                              const Spacer(),
                              Align(
                                alignment: Alignment.bottomRight,
                                child: ElevatedButton(
                                  onPressed: () => onAdd(bundle),
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(80, 28),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12),
                                    backgroundColor: GdcColors.terracotta,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                  ),
                                  child: const Text('ADD ALL',
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900)),
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
            Center(
                child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                      color: GdcColors.cream,
                      borderRadius: BorderRadius.circular(16)),
                  clipBehavior: Clip.antiAlias,
                  child: bundle.photoBase64 != null
                      ? Image.memory(base64Decode(bundle.photoBase64!),
                          fit: BoxFit.cover)
                      : const Icon(Icons.auto_awesome_motion_rounded,
                          color: GdcColors.terracotta, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(bundle.name,
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w900)),
                      Text(bundle.category,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: GdcColors.terracotta)),
                      const SizedBox(height: 4),
                      Text(bundle.description,
                          style: const TextStyle(
                              fontSize: 14, color: GdcColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Text('Items in this bundle:',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 12),
            ...bundle.productIds.map((id) {
              Product? p;
              try {
                p = allProducts.firstWhere((prod) => prod.id == id);
              } catch (_) {}
              if (p == null) return const SizedBox.shrink();
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: GdcColors.cream,
                  backgroundImage: p.photoBase64 != null
                      ? MemoryImage(base64Decode(p.photoBase64!))
                      : null,
                  child: p.photoBase64 == null
                      ? const Icon(Icons.inventory_2_outlined, size: 16)
                      : null,
                ),
                title: Text(p.name,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                subtitle: Text(formatPeso(p.price),
                    style: const TextStyle(
                        fontSize: 13,
                        color: GdcColors.terracotta,
                        fontWeight: FontWeight.bold)),
                trailing: p.stock <= 0
                    ? const Text('Out of Stock',
                        style: TextStyle(
                            color: Colors.red,
                            fontSize: 11,
                            fontWeight: FontWeight.bold))
                    : const Icon(Icons.check_circle_rounded,
                        color: Colors.green, size: 20),
              );
            }),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                onAdd(bundle);
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(60),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20))),
              child: const Text('ADD BUNDLE TO BASKET',
                  style: TextStyle(
                      fontWeight: FontWeight.w900, letterSpacing: 0.5)),
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

    final availableItems = items.where((item) {
      try {
        final p = allProducts.firstWhere((prod) => prod.id == item.productId);
        return !p.isOutOfStockForCustomer;
      } catch (_) {
        return false;
      }
    }).toList();

    final bool isTablet = Responsive.isTablet(context);
    final double itemWidth = isTablet ? 200 : 175;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    if (availableItems.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'Your Usual Items',
                    style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context).colorScheme.onSurface),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF283826)
                          : const Color(0xFFE2F0D9),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      '${availableItems.length} In Stock',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: isDark
                              ? const Color(0xFF81D268)
                              : const Color(0xFF38662A)),
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onAddAll();
                },
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Text(
                    'REORDER ALL',
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        color: GdcColors.orangeCTA,
                        letterSpacing: 0.4),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: availableItems.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final item = availableItems[i];
                Product? p;
                try {
                  p = allProducts
                      .firstWhere((prod) => prod.id == item.productId);
                } catch (_) {}

                if (p == null) return const SizedBox.shrink();

                final bool added = inCart(p.id);
                final imageBytes = _getDecodedImageBytes(p.photoBase64, p.id);

                return Container(
                  width: itemWidth,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: added
                            ? GdcColors.forest
                            : Theme.of(context).dividerColor,
                        width: 1.2),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.015),
                          blurRadius: 4,
                          offset: const Offset(0, 2))
                    ],
                  ),
                  child: Row(
                    children: [
                      // Tappable Thumbnail & Info (Opens Product Details)
                      Expanded(
                        child: GestureDetector(
                          onTap: () => onAdd(p!),
                          behavior: HitTestBehavior.opaque,
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: imageBytes != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.memory(
                                          imageBytes,
                                          fit: BoxFit.contain,
                                          gaplessPlayback: true,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.eco_rounded,
                                        color: GdcColors.forest,
                                        size: 18,
                                      ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      p.name,
                                      style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurface,
                                          height: 1.15),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      formatPeso(p.price),
                                      style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          color: GdcColors.terracotta),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(width: 4),

                      // Direct Action Button (Adds or Removes from Pre-Cart)
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          final op = context.read<OrderProvider>();
                          if (added) {
                            op.removeFromPreCart(p!.id);
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content:
                                    Text('Removed "${p.name}" from pre-cart.'),
                                backgroundColor: AppColors.orangeCTA,
                                duration: const Duration(seconds: 1),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } else {
                            op.addToPreCart(p!);
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Added "${p.name}" to pre-cart.'),
                                backgroundColor: AppColors.forest,
                                duration: const Duration(seconds: 1),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: added
                                ? GdcColors.sageTint
                                : GdcColors.orangeCTA,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            added ? Icons.check_rounded : Icons.add_rounded,
                            size: 13,
                            color: added ? GdcColors.forest : Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ShopEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const ShopEmptyState(
      {super.key,
      required this.icon,
      required this.title,
      required this.subtitle});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 64, color: GdcColors.terracotta.withValues(alpha: 0.1)),
            const SizedBox(height: 20),
            Text(title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: GdcColors.textPrimary)),
            const SizedBox(height: 6),
            Text(subtitle,
                style: const TextStyle(
                    fontSize: 13,
                    color: GdcColors.textMuted,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      );
}

class RecentOrderSection extends StatefulWidget {
  final List<PreOrder> orders;

  const RecentOrderSection({super.key, required this.orders});

  @override
  State<RecentOrderSection> createState() => _RecentOrderSectionState();
}

class _RecentOrderSectionState extends State<RecentOrderSection> {
  @override
  Widget build(BuildContext context) {
    if (widget.orders.isEmpty) return const SizedBox.shrink();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: widget.orders
          .map((order) => _buildOrderTile(context, order))
          .toList(),
    );
  }

  Widget _buildOrderTile(BuildContext context, PreOrder order) {
    final inventory = context.watch<InventoryProvider>();
    final orderProvider = context.watch<OrderProvider>();
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final String orderIdText =
        order.orderId.isNotEmpty ? order.orderId : order.id;
    final String formattedDate =
        DateFormat('MMM d, yyyy').format(order.createdAt);
    final String totalText = formatPeso(order.total);

    final cardBg = Theme.of(context).cardColor;
    final borderColor = Theme.of(context).dividerColor;
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final textMuted =
        Theme.of(context).textTheme.bodySmall?.color ?? AppColors.mutedText;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.015),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            title: Text(
              orderIdText,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15,
                color: textPrimary,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                formattedDate,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: textMuted,
                ),
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  totalText,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: textMuted,
                  size: 20,
                ),
              ],
            ),
            children: [
              Divider(height: 1, color: borderColor),
              const SizedBox(height: 14),

              // ITEMS section title
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'ITEMS',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: textMuted,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Item rows
              ...order.items.map((item) {
                Product? p;
                try {
                  p = inventory.products
                      .firstWhere((prod) => prod.id == item.productId);
                } catch (_) {}

                final String barcodeText = item.barcode.isNotEmpty
                    ? 'Barcode: ${item.barcode}'
                    : (p?.barcode != null && p!.barcode!.isNotEmpty
                        ? 'Barcode: ${p.barcode}'
                        : 'Item Code: ${item.productId}');

                final String variantNameStr =
                    item.variantName != null ? ' (${item.variantName})' : '';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${item.qty}x ${item.name}$variantNameStr',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              barcodeText,
                              style: TextStyle(
                                fontSize: 10.5,
                                color: textMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        formatPeso(item.price * item.qty),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 4),

              // Return & Exchange Policy Banner
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFFF0F5EE)
                      : const Color(0xFFFAFAF7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: Color(0xFF2E402B),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Return & Exchange Policy: Present this QR receipt at the store. Opened, unsealed, or tampered items cannot be refunded or swapped.',
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.3,
                          color: Color(0xFF2E402B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Total Price at Bottom Right
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  totalText,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Bottom Actions: Status Pill & Buy Again Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  StatusBadge(order.status),
                  OutlinedButton.icon(
                    onPressed: () async {
                      HapticFeedback.lightImpact();
                      final messenger = ScaffoldMessenger.of(context);
                      final result = await orderProvider.reorderItems(
                          order.items, inventory.products);

                      if (context.mounted) {
                        final int added = result['added'] ?? 0;
                        messenger.hideCurrentSnackBar();
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              added > 0
                                  ? 'Added $added item(s) from order $orderIdText to basket.'
                                  : 'Items out of stock or max limit reached.',
                            ),
                            backgroundColor: added > 0
                                ? AppColors.forest
                                : AppColors.orangeCTA,
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 14),
                    label: const Text(
                      'Buy Again',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      side: BorderSide(
                          color: Theme.of(context).colorScheme.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      minimumSize: const Size(0, 32),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
