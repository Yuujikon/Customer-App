import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../../shared/models/product.dart';
import '../../orders/providers/order_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/widgets/common/qty_control.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/format.dart';
import '../../../core/theme/app_theme.dart';
import '../widgets/shop_widgets.dart';

class ProductDetailsScreen extends StatefulWidget {
  final Product product;
  const ProductDetailsScreen({super.key, required this.product});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  int _quantity = 1;
  String? _selectedVariantId;

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

  void _syncQuantityWithCart() {
    if (!mounted) return;
    final op = context.read<OrderProvider>();
    final idx = op.preCart.indexWhere((i) =>
        i.productId == widget.product.id && i.variantId == _selectedVariantId);
    if (idx >= 0) {
      setState(() {
        _quantity = op.preCart[idx].qty;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AppAuthProvider>();
    final isFavorite = auth.favorites.contains(widget.product.id);

    final bool isOutOfStock = widget.product.isOutOfStockForCustomer;

    final imageBytes = widget.product.photoBase64 != null
        ? base64Decode(
            widget.product.photoBase64!.contains(',')
                ? widget.product.photoBase64!.split(',').last
                : widget.product.photoBase64!.trim(),
          )
        : null;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Responsive(
        mobile: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 200,
              pinned: true,
              leading: CircleAvatar(
                backgroundColor: Colors.white.withValues(alpha: 0.8),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back,
                      color: GdcColors.textPrimary),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              actions: [
                GestureDetector(
                  onTap: () => auth.toggleFavorite(widget.product.id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isFavorite
                          ? Colors.amber.shade700
                          : Colors.white.withValues(alpha: 0.9),
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
                      color: isFavorite ? Colors.white : GdcColors.textPrimary,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Hero(
                  tag: widget.product.id,
                  child: Container(
                    color: const Color(0xFFF7F9F5),
                    padding: const EdgeInsets.all(12),
                    child: imageBytes != null
                        ? Image.memory(
                            imageBytes,
                            fit: BoxFit.contain,
                            gaplessPlayback: true,
                          )
                        : const Icon(Icons.inventory_2_outlined,
                            size: 80, color: GdcColors.terracotta),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _buildDetailsContent(context),
              ),
            ),
          ],
        ),
        tablet: _buildSplitView(context, isFavorite, isOutOfStock, auth),
        desktop: _buildSplitView(context, isFavorite, isOutOfStock, auth),
      ),
      bottomSheet: Responsive.isMobile(context)
          ? _buildBottomActions(context, isOutOfStock)
          : null,
    );
  }

  Widget _buildSplitView(BuildContext context, bool isFavorite,
      bool isOutOfStock, AppAuthProvider auth) {
    final imageBytes = widget.product.photoBase64 != null
        ? base64Decode(
            widget.product.photoBase64!.contains(',')
                ? widget.product.photoBase64!.split(',').last
                : widget.product.photoBase64!.trim(),
          )
        : null;

    return Row(
      children: [
        // Left pane: Image (Aesthetic framed view)
        Expanded(
          flex: 4,
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  color: const Color(0xFFF7F9F5),
                  padding: const EdgeInsets.all(16),
                  child: Hero(
                    tag: widget.product.id,
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
                  backgroundColor: Colors.white.withValues(alpha: 0.8),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back,
                        color: GdcColors.textPrimary),
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
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 20,
                    offset: const Offset(-5, 0))
              ],
            ),
            child: Scaffold(
              backgroundColor: Colors.white,
              appBar: AppBar(
                automaticallyImplyLeading: false,
                backgroundColor: Colors.transparent,
                elevation: 0,
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: GestureDetector(
                      onTap: () => auth.toggleFavorite(widget.product.id),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isFavorite
                              ? Colors.amber.shade700
                              : GdcColors.cream,
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
                          color:
                              isFavorite ? Colors.white : GdcColors.textPrimary,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: _buildDetailsContent(context),
              ),
              bottomNavigationBar: _buildBottomActions(context, isOutOfStock),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsContent(BuildContext context) {
    final bool hasVariants = widget.product.hasVariants;
    final selectedVariant = _selectedVariantId != null
        ? widget.product.variants![_selectedVariantId]
        : null;
    final bool isOutOfStock = widget.product.isOutOfStockForCustomer;
    final int purchasableStock = hasVariants
        ? (selectedVariant?.maxPurchasableStock ?? 0)
        : widget.product.maxPurchasableStock;

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
                widget.product.category.toUpperCase(),
                style: const TextStyle(
                  color: GdcColors.terracotta,
                  fontWeight: FontWeight.w900,
                  fontSize: 10,
                  letterSpacing: 1,
                ),
              ),
            ),
            const Spacer(),
            if (widget.product.isPerishable)
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
          capitalize(widget.product.name),
          style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: GdcColors.textPrimary,
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
                  style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: GdcColors.terracotta),
                ),
                const Spacer(),
                Text(
                  '${selectedVariant.maxPurchasableStock} left in stock',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: selectedVariant.maxPurchasableStock <= 5
                        ? GdcColors.error
                        : GdcColors.textSecondary,
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
                formatPeso(widget.product.price),
                style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: GdcColors.terracotta),
              ),
              const Spacer(),
              Text(
                '${widget.product.maxPurchasableStock} ${widget.product.unit} left',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: widget.product.maxPurchasableStock <= 5
                      ? GdcColors.error
                      : GdcColors.textSecondary,
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: 24),

        // ── Item Specification Cards (Inspired by Reference Images 1 & 2) ──
        Row(
          children: [
            _SpecCard(
              label: 'Unit',
              value: widget.product.unit.toUpperCase(),
              icon: Icons.scale_rounded,
            ),
            const SizedBox(width: 8),
            _SpecCard(
              label: 'In Stock',
              value: '$purchasableStock items',
              icon: Icons.inventory_rounded,
            ),
            const SizedBox(width: 8),
            _SpecCard(
              label: 'Pickup Slot',
              value: widget.product.pickupWindowHours != null
                  ? '${widget.product.pickupWindowHours} Hours'
                  : 'Standard',
              icon: Icons.schedule_rounded,
            ),
          ],
        ),

        const SizedBox(height: 28),

        if (hasVariants) ...[
          const Text(
            'Select Option',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: GdcColors.textPrimary),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: widget.product.variants!.values.map((v) {
              final isSelected = _selectedVariantId == v.id;
              final isSoldOut = v.isOutOfStockForCustomer;
              return ChoiceChip(
                label: Text(capitalize(v.name)),
                selected: isSelected,
                onSelected: isSoldOut
                    ? null
                    : (selected) {
                        setState(() {
                          _selectedVariantId = v.id;
                          if (_quantity > v.maxPurchasableStock)
                            _quantity = v.maxPurchasableStock;
                          if (_quantity < 1) _quantity = 1;
                          _syncQuantityWithCart();
                        });
                      },
                selectedColor: GdcColors.terracotta,
                labelStyle: TextStyle(
                  color: isSelected
                      ? Colors.white
                      : (isSoldOut ? Colors.grey : GdcColors.textPrimary),
                  fontWeight: FontWeight.bold,
                ),
                backgroundColor:
                    isSoldOut ? Colors.grey.shade100 : Colors.white,
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
        ],

        if (!isOutOfStock) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Quantity',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: GdcColors.textPrimary),
              ),
              QtyControl(
                qty: _quantity,
                max: hasVariants
                    ? selectedVariant?.maxPurchasableStock
                    : widget.product.maxPurchasableStock,
                onChanged: (v) => setState(() => _quantity = v),
              ),
            ],
          ),
          const SizedBox(height: 28),
        ],

        const Text(
          'Product Details',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: GdcColors.textPrimary),
        ),
        const SizedBox(height: 8),
        const Text(
          'Freshly sourced daily for optimum quality and store freshness. Pre-order online and collect directly at GDC Main Store during your selected pickup window.',
          style: TextStyle(
              fontSize: 14,
              color: GdcColors.textSecondary,
              height: 1.5,
              fontWeight: FontWeight.w500),
        ),
        if (isOutOfStock) ...[
          const SizedBox(height: 28),
          const Text(
            'Notify Me',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: GdcColors.textPrimary),
          ),
          const SizedBox(height: 6),
          const Text(
            'This item is currently out of stock. We can notify you as soon as it becomes available again.',
            style: TextStyle(
                fontSize: 13, color: GdcColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 14),
          NotifyMeButton(productId: widget.product.id, isLarge: true),
        ],
        const SizedBox(height: 100),
      ],
    );
  }

  bool get isOutOfStock => widget.product.isOutOfStockForCustomer;

  Widget _buildBottomActions(BuildContext context, bool isOutOfStock) {
    if (isOutOfStock) return const SizedBox.shrink();

    final bool hasVariants = widget.product.hasVariants;
    final bool canAdd = (!hasVariants || _selectedVariantId != null);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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

                ProductVariant? v;
                if (hasVariants && _selectedVariantId != null) {
                  v = widget.product.variants![_selectedVariantId!];
                }

                op.addToPreCart(
                  widget.product,
                  quantity: _quantity,
                  variantId: v?.id,
                  variantName: v?.name,
                  replace: true,
                );

                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                      'Added $_quantity x ${widget.product.name} ${v != null ? '(${v.name})' : ''} to basket.'),
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
          hasVariants && _selectedVariantId == null
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
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF4F7EE),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5EBDD)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: GdcColors.terracotta),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 10,
                  color: GdcColors.textMuted,
                  fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                  fontSize: 12,
                  color: GdcColors.textPrimary,
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
