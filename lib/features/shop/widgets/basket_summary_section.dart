import 'package:flutter/material.dart';
import 'dart:convert';
import '../../../shared/models/order.dart';
import '../../../shared/models/product.dart';
import '../../../core/theme/app_theme.dart';

class BasketSummarySection extends StatelessWidget {
  final List<CartItem> items;
  final List<Product> allProducts;
  final Function(String productId, String? variantId) onRemove;
  final VoidCallback onClearAll;

  const BasketSummarySection({
    super.key,
    required this.items,
    required this.allProducts,
    required this.onRemove,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text('Items in your Basket', 
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: GdcColors.textPrimary),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              TextButton(
                onPressed: onClearAll,
                child: Text('CLEAR ALL', 
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: GdcColors.error.withValues(alpha: 0.8))),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 100,
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

              return Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: GdcColors.terracotta.withValues(alpha: 0.15)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8)],
                ),
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 20),
                      child: Center(
                        child: (p?.photoBase64 != null)
                            ? Image.memory(base64Decode(p!.photoBase64!), fit: BoxFit.contain)
                            : const Icon(Icons.inventory_2_outlined, color: Colors.grey, size: 24),
                      ),
                    ),
                    if (item.variantName != null)
                      Positioned(
                        bottom: 4, left: 4, right: 4,
                        child: Text(
                          item.variantName!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: GdcColors.terracotta),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    Positioned(
                      top: -4, right: -4,
                      child: GestureDetector(
                        onTap: () => onRemove(item.productId, item.variantId),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          child: const Icon(Icons.cancel_rounded, color: GdcColors.error, size: 18),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4, left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(color: GdcColors.terracotta, borderRadius: BorderRadius.circular(4)),
                        child: Text('${item.qty}', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
