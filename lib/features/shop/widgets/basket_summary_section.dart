import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import '../../../shared/models/order.dart';
import '../../../shared/models/product.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';

final Map<String, Uint8List> _basketImageCache = {};

Uint8List? _getBasketDecodedImage(String? base64Str, String productId) {
  if (base64Str == null || base64Str.isEmpty) return null;
  if (_basketImageCache.containsKey(productId)) {
    return _basketImageCache[productId];
  }
  try {
    final cleanBase64 =
        base64Str.contains(',') ? base64Str.split(',').last : base64Str;
    final decoded = base64Decode(cleanBase64.trim());
    _basketImageCache[productId] = decoded;
    return decoded;
  } catch (_) {
    return null;
  }
}

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

    final int totalCount = items.fold(0, (sum, i) => sum + i.qty);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Text(
                    'Items in your Basket',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primaryText,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.orangeCTA.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      '$totalCount',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        color: AppColors.orangeCTA,
                      ),
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  onClearAll();
                },
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  child: Text(
                    'CLEAR ALL',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Colors.red,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Horizontal Basket Items Carousel
          SizedBox(
            height: 76,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final item = items[i];
                Product? p;
                try {
                  p = allProducts
                      .firstWhere((prod) => prod.id == item.productId);
                } catch (_) {}

                final imageBytes =
                    _getBasketDecodedImage(p?.photoBase64, item.productId);
                final double itemSubtotal = item.price * item.qty;

                return Container(
                  width: 175,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFFE5D8C5),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Row(
                        children: [
                          // Thumbnail Image
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7F9F5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: imageBytes != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.memory(
                                      imageBytes,
                                      fit: BoxFit.contain,
                                      gaplessPlayback: true,
                                    ),
                                  )
                                : const Icon(
                                    Icons.shopping_basket_outlined,
                                    color: AppColors.forest,
                                    size: 20,
                                  ),
                          ),
                          const SizedBox(width: 8),

                          // Name, Qty & Subtotal
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  item.name,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.primaryText,
                                    height: 1.15,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 5, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: AppColors.sageTint,
                                        borderRadius:
                                            BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'x${item.qty}',
                                        style: const TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.forest,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        formatPeso(itemSubtotal),
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.forest,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                        ],
                      ),

                      // Sleek Top-Right Remove Delete Button
                      Positioned(
                        top: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            onRemove(item.productId, item.variantId);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              color: Colors.red.shade700,
                              size: 13,
                            ),
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
