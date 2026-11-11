import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../shared/models/product.dart';
import '../../auth/providers/auth_provider.dart';
import '../../orders/providers/order_provider.dart';
import '../providers/inventory_provider.dart';
import 'product_details_screen.dart';

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

class SavedItemsScreen extends StatefulWidget {
  const SavedItemsScreen({super.key});

  @override
  State<SavedItemsScreen> createState() => _SavedItemsScreenState();
}

class _SavedItemsScreenState extends State<SavedItemsScreen> {
  int _selectedFilterIndex = 0; // 0 = All, 1 = In Stock, 2 = Out of Stock

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AppAuthProvider>();
    final inventory = context.watch<InventoryProvider>();
    final orderProvider = context.watch<OrderProvider>();

    final String userId = auth.currentUser?.uid ?? auth.email;

    final allSavedProducts =
        inventory.products.where((p) => auth.favorites.contains(p.id)).toList();

    final inStockSaved =
        allSavedProducts.where((p) => !p.isOutOfStockForCustomer).toList();
    final oosSaved =
        allSavedProducts.where((p) => p.isOutOfStockForCustomer).toList();

    List<Product> displayedProducts;
    if (_selectedFilterIndex == 1) {
      displayedProducts = inStockSaved;
    } else if (_selectedFilterIndex == 2) {
      displayedProducts = oosSaved;
    } else {
      displayedProducts = allSavedProducts;
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).cardColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.primaryText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your Favorites',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Text(
              '${allSavedProducts.length} item${allSavedProducts.length == 1 ? '' : 's'} saved',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).textTheme.bodySmall?.color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip(
                  label: 'All (${allSavedProducts.length})',
                  index: 0,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'In Stock (${inStockSaved.length})',
                  index: 1,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  label: 'Sold Out (${oosSaved.length})',
                  index: 2,
                ),
              ],
            ),
          ),
        ),
      ),
      body: displayedProducts.isNotEmpty
          ? GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 180,
                mainAxisExtent: 260,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: displayedProducts.length,
              itemBuilder: (context, index) {
                final product = displayedProducts[index];
                final inCart =
                    orderProvider.preCart.any((c) => c.productId == product.id);

                return _SavedProductCard(
                  product: product,
                  inCart: inCart,
                  userId: userId,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProductDetailsScreen(product: product),
                    ),
                  ),
                  onToggleFavorite: () => auth.toggleFavorite(product.id),
                  onAddToCart: () {
                    if (product.hasVariants) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ProductDetailsScreen(product: product),
                        ),
                      );
                    } else {
                      orderProvider.addToPreCart(product);
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Added "${product.name}" to pre-cart.'),
                          backgroundColor: AppColors.forest,
                          duration: const Duration(seconds: 1),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                );
              },
            )
          : Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.favorite_border_rounded,
                        size: 48,
                        color: AppColors.mutedText,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _selectedFilterIndex == 1
                          ? 'No Available Favorites'
                          : _selectedFilterIndex == 2
                              ? 'No Sold Out Favorites'
                              : 'Your Favorites List is Empty',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap the ❤ heart icon on any product in the store to save it here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.forest,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100)),
                      ),
                      child: const Text(
                        'Browse Store Catalog',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildFilterChip({required String label, required int index}) {
    final bool isSelected = _selectedFilterIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilterIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.forest : Colors.white,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: isSelected ? AppColors.forest : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: isSelected ? Colors.white : AppColors.primaryText,
          ),
        ),
      ),
    );
  }
}

/// Custom Responsive Moderate Grid Product Card
class _SavedProductCard extends StatelessWidget {
  final Product product;
  final bool inCart;
  final String userId;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;
  final VoidCallback onAddToCart;

  const _SavedProductCard({
    required this.product,
    required this.inCart,
    required this.userId,
    required this.onTap,
    required this.onToggleFavorite,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    final bool isOos = product.isOutOfStockForCustomer;
    final imageBytes = _getDecodedImageBytes(product.photoBase64, product.id);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: inCart ? AppColors.orangeCTA : AppColors.border,
          width: inCart ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image with Stock / Status Badge & Heart Button (Tappable -> Opens details)
          GestureDetector(
            onTap: onTap,
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              height: 105,
              width: double.infinity,
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    height: double.infinity,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F9F5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: imageBytes != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: ColorFiltered(
                              colorFilter: isOos
                                  ? const ColorFilter.mode(
                                      Colors.grey, BlendMode.saturation)
                                  : const ColorFilter.mode(
                                      Colors.transparent, BlendMode.multiply),
                              child: Image.memory(
                                imageBytes,
                                fit: BoxFit.contain,
                                gaplessPlayback: true,
                              ),
                            ),
                          )
                        : const Center(
                            child: Icon(Icons.inventory_2_outlined,
                                size: 36, color: AppColors.mutedText),
                          ),
                  ),

                  // Direct Remove from Basket Button (When in cart)
                  if (inCart)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: GestureDetector(
                        onTap: () {
                          final op = context.read<OrderProvider>();
                          op.removeFromPreCart(product.id);
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
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
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            color: Colors.red.shade600,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.white,
                            size: 13,
                          ),
                        ),
                      ),
                    )
                  else if (isOos)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.shade700,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'Sold Out',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),

                  // Red Heart Remove Button
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: onToggleFavorite,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.favorite_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Product Category & Name
          Text(
            product.category.toUpperCase(),
            style: const TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
              color: AppColors.mutedText,
              letterSpacing: 0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            product.name,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryText,
              height: 1.15,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const Spacer(),

          // Price & Unit
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formatPeso(product.price),
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      color: isOos ? AppColors.mutedText : AppColors.forest,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Text(
                product.unit,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.mutedText,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // Action Button: Add to Basket OR Restock Notify
          if (!isOos)
            ElevatedButton.icon(
              onPressed: onAddToCart,
              icon: Icon(
                inCart
                    ? Icons.check_circle_rounded
                    : Icons.add_shopping_cart_rounded,
                size: 13,
              ),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  inCart ? 'In Basket' : 'Add to Basket',
                  style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w900),
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    inCart ? AppColors.forest : AppColors.orangeCTA,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 32),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
            )
          else
            Container(
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(100),
              ),
              child: const Text(
                'Out of Stock',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  color: Colors.grey,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
