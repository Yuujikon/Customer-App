import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/models/product.dart';
import '../../orders/providers/order_provider.dart';
import '../providers/inventory_provider.dart';
import '../../../core/utils/format.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/common/qty_control.dart';

class VariantSelectionSheet extends StatefulWidget {
  final Product product;
  const VariantSelectionSheet({super.key, required this.product});

  @override
  State<VariantSelectionSheet> createState() => _VariantSelectionSheetState();
}

class _VariantSelectionSheetState extends State<VariantSelectionSheet> {
  String? _selectedVariantId;
  int _quantity = 1;

  Product _liveProduct(InventoryProvider inventory) {
    for (final p in inventory.products) {
      if (p.id == widget.product.id) return p;
    }
    return widget.product;
  }

  void _syncQuantityWithCart(int maxStock) {
    if (!mounted) return;
    final op = context.read<OrderProvider>();
    final idx = op.preCart.indexWhere((i) =>
        i.productId == widget.product.id && i.variantId == _selectedVariantId);
    if (idx >= 0) {
      setState(() {
        final cartQty = op.preCart[idx].qty;
        _quantity = maxStock > 0 ? cartQty.clamp(1, maxStock) : 1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<InventoryProvider>();
    final product = _liveProduct(inventory);
    final variants = product.variants?.values.toList() ?? [];
    variants.sort((a, b) => a.name.compareTo(b.name));

    final selectedVariant = _selectedVariantId != null
        ? (product.variants?[_selectedVariantId])
        : null;
    final int selectedMaxStock = selectedVariant?.maxPurchasableStock ?? 0;
    final bool canAddSelected = selectedVariant != null &&
        !selectedVariant.isOutOfStockForCustomer &&
        selectedMaxStock > 0;
    final int effectiveQty =
        selectedMaxStock > 0 ? _quantity.clamp(1, selectedMaxStock) : 1;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
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
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 24),
            Text(capitalize(product.name),
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: GdcColors.textPrimary)),
            const Text('Choose your flavor/type',
                style: TextStyle(
                    fontSize: 14,
                    color: GdcColors.textSecondary,
                    fontWeight: FontWeight.w500)),
            const SizedBox(height: 24),
            ...variants.map((v) {
              final isSelected = _selectedVariantId == v.id;
              final isSoldOut = v.isOutOfStockForCustomer;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: isSoldOut
                      ? null
                      : () {
                          setState(() {
                            _selectedVariantId = v.id;
                            if (_quantity > v.maxPurchasableStock) {
                              _quantity = v.maxPurchasableStock;
                            }
                            if (_quantity < 1) _quantity = 1;
                            _syncQuantityWithCart(v.maxPurchasableStock);
                          });
                        },
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? GdcColors.terracotta.withValues(alpha: 0.05)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? GdcColors.terracotta
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(capitalize(v.name),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: isSoldOut
                                        ? Colors.grey
                                        : GdcColors.textPrimary,
                                  )),
                              const SizedBox(height: 4),
                              Text(formatPeso(v.price),
                                  style: TextStyle(
                                    color: isSoldOut
                                        ? Colors.grey
                                        : GdcColors.terracotta,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  )),
                            ],
                          ),
                        ),
                        if (isSoldOut)
                          const Text('SOLD OUT',
                              style: TextStyle(
                                  color: GdcColors.error,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11))
                        else
                          Text('${v.maxPurchasableStock} left',
                              style: const TextStyle(
                                  color: GdcColors.textMuted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              );
            }),
            if (canAddSelected) ...[
              const SizedBox(height: 24),
              const Text('Quantity',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 12),
              QtyControl(
                qty: effectiveQty,
                max: selectedMaxStock,
                onChanged: (v) => setState(() => _quantity = v),
              ),
            ],
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: !canAddSelected
                  ? null
                  : () {
                      final v = selectedVariant;

                      context.read<OrderProvider>().addToPreCart(
                            product,
                            quantity: effectiveQty,
                            variantId: v.id,
                            variantName: v.name,
                            replace: true,
                          );

                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(
                            'Added $effectiveQty x ${product.name} (${v.name}) to basket.'),
                        backgroundColor: GdcColors.success,
                        duration: const Duration(seconds: 1),
                      ));

                      Navigator.pop(context);
                    },
              child: const Text('ADD TO BASKET'),
            ),
          ],
        ),
      ),
    );
  }
}
