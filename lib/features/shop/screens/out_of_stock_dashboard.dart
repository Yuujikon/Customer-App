import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/format.dart';
import '../../../shared/models/product.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/inventory_provider.dart';
import 'product_details_screen.dart';

/// In-memory cache for decoded base64 product image bytes to prevent
/// expensive re-decoding during scrolling and tab transitions.
final Map<String, Uint8List> _imageCache = {};

class OutOfStockDashboardScreen extends StatefulWidget {
  const OutOfStockDashboardScreen({super.key});

  @override
  State<OutOfStockDashboardScreen> createState() =>
      _OutOfStockDashboardScreenState();
}

class _OutOfStockDashboardScreenState extends State<OutOfStockDashboardScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<InventoryProvider>();
    final auth = context.watch<AppAuthProvider>();

    final String userId = auth.currentUser?.uid ?? auth.email;

    // 1. All Out-of-Stock Products
    final allOosProducts = inventory.outOfStockProducts;

    // Fast search filtering
    List<Product> applySearch(List<Product> list) {
      if (_searchQuery.trim().isEmpty) return list;
      final q = _searchQuery.toLowerCase();
      return list
          .where((p) =>
              p.name.toLowerCase().contains(q) ||
              p.category.toLowerCase().contains(q))
          .toList();
    }

    final filteredAllOos = applySearch(allOosProducts);

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.primaryText),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Restock Radar',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.primaryText,
              ),
            ),
            Text(
              '${allOosProducts.length} item${allOosProducts.length == 1 ? '' : 's'} sold out · Tap to get notified',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.mutedText,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.cream,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search out-of-stock items...',
                  hintStyle: const TextStyle(
                      fontSize: 12.5, color: AppColors.mutedText),
                  prefixIcon: const Icon(Icons.search_rounded,
                      size: 18, color: AppColors.mutedText),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 16),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
          ),
        ),
      ),
      body: _OutOfStockGridView(
        products: filteredAllOos,
        userId: userId,
        onRefresh: inventory.refreshData,
      ),
    );
  }
}

class _OutOfStockGridView extends StatelessWidget {
  final List<Product> products;
  final String userId;
  final Future<void> Function() onRefresh;

  const _OutOfStockGridView({
    required this.products,
    required this.userId,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              Container(
                width: 88,
                height: 88,
                decoration: const BoxDecoration(
                  color: Color(0xFFE2F0D9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 48,
                  color: Color(0xFF38662A),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'All Store Products In Stock! 🎉',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryText),
              ),
              const SizedBox(height: 8),
              const Text(
                'The store currently has high stock availability across all categories.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, color: AppColors.mutedText, height: 1.4),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.storefront_rounded, size: 18),
                label: const Text('Return to Storefront'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.forest,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 180,
          mainAxisExtent: 260,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: products.length,
        itemBuilder: (context, index) {
          final product = products[index];
          return _OutOfStockGridCard(
            key: ValueKey(product.id),
            product: product,
            userId: userId,
          );
        },
      ),
    );
  }
}

class _OutOfStockGridCard extends StatelessWidget {
  final Product product;
  final String userId;

  const _OutOfStockGridCard({
    super.key,
    required this.product,
    required this.userId,
  });

  Uint8List? _getImageBytes(String? base64Str, String productId) {
    if (base64Str == null || base64Str.isEmpty) return null;
    if (_imageCache.containsKey(productId)) {
      return _imageCache[productId];
    }
    try {
      final cleanBase64 =
          base64Str.contains(',') ? base64Str.split(',').last : base64Str;
      final decoded = base64Decode(cleanBase64.trim());
      _imageCache[productId] = decoded;
      return decoded;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isNotifying = product.isNotifyingUser(userId);
    final waitingCount = product.notifyUserIds.length;
    final imageBytes = _getImageBytes(product.photoBase64, product.id);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ProductDetailsScreen(product: product)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isNotifying ? AppColors.forest : AppColors.border,
            width: isNotifying ? 1.5 : 1.0,
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
            // Image with Sold Out Badge
            SizedBox(
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
                              colorFilter: const ColorFilter.mode(
                                  Colors.grey, BlendMode.saturation),
                              child: Image.memory(
                                imageBytes,
                                fit: BoxFit.contain,
                                gaplessPlayback: true,
                              ),
                            ),
                          )
                        : const Center(
                            child: Icon(Icons.inventory_2_outlined,
                                color: AppColors.mutedText, size: 36),
                          ),
                  ),
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
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Category & Name
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

            // Price & Waiting Count
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  formatPeso(product.price),
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.mutedText,
                  ),
                ),
                if (waitingCount > 0)
                  Text(
                    '$waitingCount waiting',
                    style: const TextStyle(
                      fontSize: 9.5,
                      color: AppColors.orangeCTA,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                else
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

            // Action Button: Toggle Restock Notification
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: isNotifying
                  ? ElevatedButton.icon(
                      key: const ValueKey('notifying'),
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final inventory = context.read<InventoryProvider>();
                        await inventory.toggleRestockNotification(
                            product.id, userId);
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Restock notification turned off.'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      icon: const Icon(Icons.check_circle_rounded, size: 12),
                      label: const Text('✓ Notifying',
                          style: TextStyle(
                              fontSize: 9.5, fontWeight: FontWeight.w900)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.forest,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                    )
                  : OutlinedButton.icon(
                      key: const ValueKey('notify_me'),
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final inventory = context.read<InventoryProvider>();
                        await inventory.toggleRestockNotification(
                            product.id, userId);
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text(
                                "🔔 Restock Radar Set! We'll alert you as soon as ${product.name} is restocked."),
                            backgroundColor: AppColors.orangeCTA,
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      },
                      icon: const Icon(Icons.notifications_active_rounded,
                          size: 12),
                      label: const Text('Notify Me',
                          style: TextStyle(
                              fontSize: 9.5, fontWeight: FontWeight.w900)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.orangeCTA,
                        side: const BorderSide(color: AppColors.orangeCTA),
                        minimumSize: const Size(double.infinity, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
