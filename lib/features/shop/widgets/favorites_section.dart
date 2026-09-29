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
    final bool isTablet = Responsive.isTablet(context);
    final double itemWidth = isTablet ? 180 : 140;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Text('Your Favorites', 
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: GdcColors.textPrimary)),
        ),
        SizedBox(
          height: 160,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: products.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (_, i) {
              final p = products[i];
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    color: GdcColors.cream.withValues(alpha: 0.5),
                    child: product.photoBase64 != null
                      ? Image.memory(base64Decode(product.photoBase64!), fit: BoxFit.cover)
                      : const Icon(Icons.inventory_2_outlined, color: Colors.grey, size: 32),
                  ),
                  Positioned(
                    top: 4, right: 4,
                    child: GestureDetector(
                      onTap: onRemove,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.amber, 
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                        ),
                        child: const Icon(Icons.bookmark_rounded, color: Colors.white, size: 14),
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
                  Text(product.name, 
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(formatPeso(product.price), 
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: GdcColors.terracotta)),
                      GestureDetector(
                        onTap: product.stock > 0 ? onAdd : null,
                        child: Icon(
                          Icons.add_circle_rounded, 
                          color: product.stock > 0 ? GdcColors.terracotta : Colors.grey.shade300, 
                          size: 20
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
