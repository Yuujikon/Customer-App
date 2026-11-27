import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/models/product.dart';
import '../../orders/providers/order_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/inventory_provider.dart';
import '../../../shared/widgets/common/qty_control.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/format.dart';
import '../../../core/theme/app_theme.dart';

class ProductDetailsScreen extends StatefulWidget {
  final Product product;
  final String? heroTag;

  const ProductDetailsScreen({super.key, required this.product, this.heroTag});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  int _quantity = 1;
  String? _selectedVariantId;
  String? _cachedPhotoRaw;
  Uint8List? _cachedPhotoBytes;

  @override
  void initState() {
    super.initState();
    // Default to first available variant if exists
    if (widget.product.hasVariants) {
      final available = widget.product.variants!.values
          .where((v) => !v.isOutOfStockForCustomer)
          .toList();
      if (available.isNotEmpty) {
        _selectedVariantId = available.first.id;
      }
    }
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _syncQuantityWithCart());
  }

  Uint8List? _decodePhoto(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    if (_cachedPhotoRaw == raw) return _cachedPhotoBytes;
    _cachedPhotoRaw = raw;
    try {
      final clean = raw.contains(',') ? raw.split(',').last : raw;
      _cachedPhotoBytes = base64Decode(clean.trim());
    } catch (_) {
      _cachedPhotoBytes = null;
    }
    return _cachedPhotoBytes;
  }

  int? _cartQtyForVariant(String? variantId) {
    final op = context.read<OrderProvider>();
    final idx = op.preCart.indexWhere(
      (i) => i.productId == widget.product.id && i.variantId == variantId,
    );
    return idx >= 0 ? op.preCart[idx].qty : null;
  }

  void _syncQuantityWithCart() {
    if (!mounted) return;
    final cartQty = _cartQtyForVariant(_selectedVariantId);
    if (cartQty != null) {
      setState(() {
        _quantity = cartQty;
      });
    }
  }

  Product _liveProduct(InventoryProvider inventory) {
    for (final p in inventory.products) {
      if (p.id == widget.product.id) return p;
    }
    return widget.product;
  }

  ProductVariant? _resolveSelectedVariant(Product product) {
    if (!product.hasVariants || product.variants == null) return null;
    if (_selectedVariantId != null) {
      final current = product.variants![_selectedVariantId];
      if (current != null && !current.isOutOfStockForCustomer) {
        return current;
      }
    }
    for (final v in product.variants!.values) {
      if (!v.isOutOfStockForCustomer) return v;
    }
    return _selectedVariantId != null
        ? product.variants![_selectedVariantId]
        : null;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AppAuthProvider>();
    final inventory = context.watch<InventoryProvider>();
    final product = _liveProduct(inventory);
    final isFavorite = auth.favorites.contains(product.id);
    final bool isOutOfStock = product.isOutOfStockForCustomer;
    final imageBytes = _decodePhoto(product.photoBase64);

    return Scaffold(
      backgroundColor: Theme.of(context).cardColor,
      body: Responsive(
        mobile: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).brightness == Brightness.dark
                    ? Theme.of(context).colorScheme.surfaceContainerLow
                    : Colors.white.withValues(alpha: 0.8),
                child: IconButton(
                  icon: Icon(Icons.arrow_back,
                      color: Theme.of(context).colorScheme.onSurface),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              actions: [
                GestureDetector(
                  onTap: () => auth.toggleFavorite(product.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isFavorite
                          ? Colors.amber.shade700
                          : (Theme.of(context).brightness == Brightness.dark
                              ? Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerLow
                              : Colors.white.withValues(alpha: 0.9)),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Icon(
                      isFavorite
                          ? Icons.bookmark_rounded
                          : Icons.bookmark_border_rounded,
                      color: isFavorite
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurface,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Hero(
                  tag: widget.heroTag ?? product.id,
                  child: Container(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Theme.of(context).colorScheme.surfaceContainerLow
                        : const Color(0xFFF7F9F5),
                    padding: const EdgeInsets.all(12),
                    child: imageBytes != null
                        ? Image.memory(
                            imageBytes,
                            fit: BoxFit.contain,
                            gaplessPlayback: true,
                          )
                        : Icon(Icons.inventory_2_outlined,
                            size: 80,
                            color: Theme.of(context).colorScheme.primary),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _buildDetailsContent(context, product),
              ),
            ),
          ],
        ),
        tablet: _buildSplitView(
            context, product, imageBytes, isFavorite, isOutOfStock, auth),
        desktop: _buildSplitView(
            context, product, imageBytes, isFavorite, isOutOfStock, auth),
      ),
      bottomSheet: Responsive.isMobile(context)
          ? SafeArea(
              top: false,
              child: _buildBottomActions(context, product, isOutOfStock),
            )
          : null,
    );
  }

  Widget _buildSplitView(
    BuildContext context,
    Product product,
    Uint8List? imageBytes,
    bool isFavorite,
    bool isOutOfStock,
    AppAuthProvider auth,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        // Left pane: Image (Aesthetic framed view)
        Expanded(
          flex: 4,
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  color: isDark
                      ? Theme.of(context).colorScheme.surfaceContainerLow
                      : const Color(0xFFF7F9F5),
                  padding: const EdgeInsets.all(16),
                  child: Hero(
                    tag: widget.heroTag ?? product.id,
                    child: imageBytes != null
                        ? Image.memory(
                            imageBytes,
                            fit: BoxFit.contain,
                            gaplessPlayback: true,
                          )
                        : const Icon(Icons.inventory_2_outlined,
                            size: 100, color: GdcColors.terracotta),
                  ),
                ),
              ),
              Positioned(
                top: 16,
                left: 16,
                child: CircleAvatar(
                  backgroundColor: isDark
                      ? Theme.of(context).cardColor.withValues(alpha: 0.9)
                      : Colors.white.withValues(alpha: 0.8),
                  child: IconButton(
                    icon: Icon(Icons.arrow_back,
                        color: Theme.of(context).colorScheme.onSurface),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Right pane: Details
        Expanded(
          flex: 5,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(-5, 0))
              ],
            ),
            child: Scaffold(
              backgroundColor: Theme.of(context).cardColor,
              appBar: AppBar(
                automaticallyImplyLeading: false,
                backgroundColor: Colors.transparent,
                elevation: 0,
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: GestureDetector(
                      onTap: () => auth.toggleFavorite(product.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isFavorite
                              ? Colors.amber.shade700
                              : (isDark
                                  ? Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerLow
                                  : GdcColors.cream),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Icon(
                          isFavorite
                              ? Icons.bookmark_rounded
                              : Icons.bookmark_border_rounded,
                          color: isFavorite
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurface,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _buildDetailsContent(context, product),
              ),
              bottomNavigationBar: SafeArea(
                top: false,
                child: _buildBottomActions(context, product, isOutOfStock),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsContent(BuildContext context, Product product) {
    final bool hasVariants = product.hasVariants;
    final selectedVariant = _resolveSelectedVariant(product);
    final bool isOutOfStock = product.isOutOfStockForCustomer;
    final int purchasableStock = hasVariants
        ? (selectedVariant?.maxPurchasableStock ?? 0)
        : product.maxPurchasableStock;
    final int effectiveQty =
        purchasableStock > 0 ? _quantity.clamp(1, purchasableStock) : 1;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: GdcColors.terracotta.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                product.category.toUpperCase(),
                style: const TextStyle(
                  color: GdcColors.terracotta,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                  letterSpacing: 1,
                ),
              ),
            ),
            const Spacer(),
            if (product.isPerishable)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: GdcColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'FRESH PRODUCE',
                  style: TextStyle(
                    color: GdcColors.error,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          capitalize(product.name),
          style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).colorScheme.onSurface,
              letterSpacing: -0.3),
        ),
        const SizedBox(height: 12),

        // Price and Stock Display
        if (hasVariants) ...[
          if (selectedVariant != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatPeso(selectedVariant.price),
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Theme.of(context).colorScheme.primary),
                ),
                const Spacer(),
                Text(
                  '${selectedVariant.maxPurchasableStock} left in stock',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: selectedVariant.maxPurchasableStock <= 5
                        ? GdcColors.error
                        : (isDark
                            ? Theme.of(context).colorScheme.primary
                            : GdcColors.textSecondary),
                  ),
                ),
              ],
            ),
          ] else ...[
            const Text(
              'Select a flavor / option below',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey),
            ),
          ]
        ] else ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                formatPeso(product.price),
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).colorScheme.primary),
              ),
              const Spacer(),
              Text(
                '${product.maxPurchasableStock} ${product.unit} left',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: product.maxPurchasableStock <= 5
                      ? GdcColors.error
                      : (isDark
                          ? Theme.of(context).colorScheme.primary
                          : GdcColors.textSecondary),
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: 24),

        // ── Item Specification Cards ──
        Row(
          children: [
            _SpecCard(
              label: 'Unit',
              value: product.unit.toUpperCase(),
              icon: Icons.scale_rounded,
            ),
            const SizedBox(width: 8),
            _SpecCard(
              label: 'Stock',
              value: purchasableStock > 0
                  ? '$purchasableStock ${product.unit}'
                  : 'Out of Stock',
              icon: Icons.inventory_rounded,
            ),
            const SizedBox(width: 8),
            _SpecCard(
              label: 'Pickup Slot',
              value: product.pickupWindowHours != null
                  ? '${product.pickupWindowHours} Hours'
                  : 'Standard',
              icon: Icons.schedule_rounded,
            ),
          ],
        ),

        const SizedBox(height: 28),

        if (hasVariants) ...[
          Text(
            'Select Option',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.onSurface),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: product.variants!.values.map((v) {
              final isSelected = selectedVariant?.id == v.id;
              final isSoldOut = v.isOutOfStockForCustomer;
              return ChoiceChip(
                label: Text(capitalize(v.name)),
                selected: isSelected,
                onSelected: isSoldOut
                    ? null
                    : (selected) {
                        final cartQty = _cartQtyForVariant(v.id);
                        setState(() {
                          _selectedVariantId = v.id;
                          final maxStock = v.maxPurchasableStock;
                          if (cartQty != null && maxStock > 0) {
                            _quantity = cartQty.clamp(1, maxStock);
                          } else {
                            _quantity = 1;
                          }
                        });
                      },
                selectedColor: GdcColors.terracotta,
                labelStyle: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : (isSoldOut
                          ? Colors.grey
                          : Theme.of(context).colorScheme.onSurface),
                  fontWeight: FontWeight.bold,
                ),
                backgroundColor: isSoldOut
                    ? (isDark ? Colors.grey.shade800 : Colors.grey.shade200)
                    : Theme.of(context).cardColor,
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
        ],

        if (!isOutOfStock) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Quantity',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Theme.of(context).colorScheme.onSurface),
              ),
              QtyControl(
                qty: effectiveQty,
                max: purchasableStock,
                onChanged: (v) => setState(() => _quantity = v),
              ),
            ],
          ),
          const SizedBox(height: 28),
        ],

        Text(
          'Product Details',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).colorScheme.onSurface),
        ),
        const SizedBox(height: 8),
        Text(
          'Freshly sourced daily for optimum quality and store freshness. Pre-order online and collect directly at GDC Main Store during your selected pickup window.',
          style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).textTheme.bodySmall?.color,
              height: 1.5,
              fontWeight: FontWeight.w500),
        ),
        if (isOutOfStock) ...[
          const SizedBox(height: 28),
          const Text(
            'Out of Stock',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: GdcColors.error),
          ),
          const SizedBox(height: 6),
          const Text(
            'This item is currently unavailable.',
            style: TextStyle(
                fontSize: 13, color: GdcColors.textSecondary, height: 1.4),
          ),
        ],
        const SizedBox(height: 100),
      ],
    );
  }

  Widget _buildBottomActions(
      BuildContext context, Product product, bool isOutOfStock) {
    if (isOutOfStock) return const SizedBox.shrink();

    final bool hasVariants = product.hasVariants;
    final ProductVariant? selectedVariant = _resolveSelectedVariant(product);
    final int purchasableStock = hasVariants
        ? (selectedVariant?.maxPurchasableStock ?? 0)
        : product.maxPurchasableStock;
    final int effectiveQty =
        purchasableStock > 0 ? _quantity.clamp(1, purchasableStock) : 1;
    final bool canAdd =
        (!hasVariants || selectedVariant != null) && purchasableStock > 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: Theme.of(context).dividerColor),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: !canAdd
            ? null
            : () {
                final op = context.read<OrderProvider>();
                final ProductVariant? v = hasVariants ? selectedVariant : null;

                op.addToPreCart(
                  product,
                  quantity: effectiveQty,
                  variantId: v?.id,
                  variantName: v?.name,
                  replace: true,
                );

                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                      'Added $effectiveQty x ${product.name} ${v != null ? '(${v.name})' : ''} to basket.'),
                  backgroundColor: GdcColors.success,
                  duration: const Duration(seconds: 1),
                ));

                Navigator.pop(context);
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: GdcColors.orangeCTA,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
        ),
        child: Text(
          hasVariants && selectedVariant == null
              ? 'SELECT A FLAVOR'
              : 'ADD TO BASKET',
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 0.5),
        ),
      ),
    );
  }
}

class _SpecCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _SpecCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark
        ? Theme.of(context).colorScheme.surfaceContainerLow
        : const Color(0xFFF4F7EE);
    final borderColor = Theme.of(context).dividerColor;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final textPrimary = Theme.of(context).colorScheme.onSurface;
    final textMuted =
        Theme.of(context).textTheme.bodySmall?.color ?? AppColors.mutedText;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: primaryColor),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                  fontSize: 10, color: textMuted, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                  fontSize: 12,
                  color: textPrimary,
                  fontWeight: FontWeight.w900),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
