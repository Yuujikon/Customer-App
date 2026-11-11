import 'package:flutter/material.dart';
import 'dart:convert';
import '../../../shared/models/product.dart';
import '../../../core/utils/format.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';

class FavoritesSection extends StatelessWidget {
  final List<Product> products;
  final Function(Product) onAdd;
  final Function(String) onRemove;
  final Function(Product) onTap;

  const FavoritesSection({
    super.key,
    required this.products,
    required this.onAdd,
    required this.onRemove,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();

    final inStockProducts =
        products.where((p) => !p.isOutOfStockForCustomer).toList();
    final oosProducts =
        products.where((p) => p.isOutOfStockForCustomer).toList();

    final bool isTablet = Responsive.isTablet(context);
    final double itemWidth = isTablet ? 180 : 140;

    // Empty State
    if (inStockProducts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    'Your Favorites',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: GdcColors.textPrimary),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2F0D9),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      '${inStockProducts.length} Available',
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF38662A)),
                    ),
                  ),
                ],
              ),
              if (oosProducts.isNotEmpty)
                Text(
                  '${oosProducts.length} Out of Stock',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: GdcColors.textMuted),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 160,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: inStockProducts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (_, i) {
              final p = inStockProducts[i];
              return _FavoriteCard(
                product: p,
                onAdd: () => onAdd(p),
                onRemove: () => onRemove(p.id),
                onTap: () => onTap(p),
                width: itemWidth,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FavoriteCard extends StatelessWidget {
  final Product product;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final VoidCallback onTap;
  final double width;

  const _FavoriteCard({
    required this.product,
    required this.onAdd,
    required this.onRemove,
    required this.onTap,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Theme.of(context).dividerColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 90,
              width: double.infinity,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: GdcColors.cream.withValues(alpha: 0.5),
                    child: product.photoBase64 != null
                        ? Image.memory(
                            base64Decode(product.photoBase64!),
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                          )
                        : const Icon(Icons.inventory_2_outlined,
                            color: Colors.grey, size: 32),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: onRemove,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.amber,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(color: Colors.black12, blurRadius: 4)
                          ],
                        ),
                        child: const Icon(Icons.bookmark_rounded,
                            color: Colors.white, size: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w800),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        formatPeso(product.price),
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: GdcColors.terracotta),
                      ),
                      GestureDetector(
                        onTap: !product.isOutOfStockForCustomer ? onAdd : null,
                        child: Icon(
                          Icons.add_circle_rounded,
                          color: !product.isOutOfStockForCustomer
                              ? GdcColors.terracotta
                              : Colors.grey.shade300,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
