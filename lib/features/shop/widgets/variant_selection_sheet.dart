import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/models/product.dart';
import '../../orders/providers/order_provider.dart';
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

  void _syncQuantityWithCart() {
    if (!mounted) return;
    final op = context.read<OrderProvider>();
    final idx = op.preCart.indexWhere((i) => i.productId == widget.product.id && i.variantId == _selectedVariantId);
    if (idx >= 0) {
      setState(() {
        _quantity = op.preCart[idx].qty;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final variants = widget.product.variants?.values.toList() ?? [];
    variants.sort((a, b) => a.name.compareTo(b.name));

    final selectedVariant = _selectedVariantId != null 
        ? widget.product.variants![_selectedVariantId] 
        : null;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 24),
            Text(capitalize(widget.product.name), 
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: GdcColors.textPrimary)),
            const Text('Choose your flavor/type', 
                style: TextStyle(fontSize: 14, color: GdcColors.textSecondary, fontWeight: FontWeight.w500)),
            
            const SizedBox(height: 24),
            ...variants.map((v) {
              final isSelected = _selectedVariantId == v.id;
              final isSoldOut = v.isOutOfStockForCustomer;

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  onTap: isSoldOut ? null : () {
                    setState(() {
                      _selectedVariantId = v.id;
                      if (_quantity > v.maxPurchasableStock) _quantity = v.maxPurchasableStock;
                      if (_quantity < 1) _quantity = 1;
                      _syncQuantityWithCart();
                    });
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected ? GdcColors.terracotta.withValues(alpha: 0.05) : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? GdcColors.terracotta : Colors.transparent,
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
                                    color: isSoldOut ? Colors.grey : GdcColors.textPrimary,
                                  )),
                              const SizedBox(height: 4),
                              Text(formatPeso(v.price), 
                                  style: TextStyle(
                                    color: isSoldOut ? Colors.grey : GdcColors.terracotta, 
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  )),
                            ],
                          ),
                        ),
                        if (isSoldOut)
                          const Text('SOLD OUT', 
                              style: TextStyle(color: GdcColors.error, fontWeight: FontWeight.w900, fontSize: 11))
                        else
                          Text('${v.maxPurchasableStock} left', 
                              style: const TextStyle(color: GdcColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              );
            }),

            if (_selectedVariantId != null) ...[
              const SizedBox(height: 24),
              const Text('Quantity', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 12),
              QtyControl(
                qty: _quantity, 
                max: selectedVariant?.maxPurchasableStock ?? 0, 
                onChanged: (v) => setState(() => _quantity = v),
              ),
            ],

            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _selectedVariantId == null ? null : () {
                final v = widget.product.variants?[_selectedVariantId!];
                if (v == null) return;
                
                context.read<OrderProvider>().addToPreCart(
                  widget.product,
                  quantity: _quantity,
                  variantId: v.id,
                  variantName: v.name,
                  replace: true,
                );

                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Added $_quantity x ${widget.product.name} (${v.name}) to basket.'),
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
