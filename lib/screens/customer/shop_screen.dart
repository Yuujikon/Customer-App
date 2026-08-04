import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../models/product.dart';
import '../../models/order.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/format.dart';
import '../../utils/store_hours.dart';
import '../../config/theme.dart';
import '../../widgets/loyalty_dashboard.dart';
import '../../models/bundle.dart';

class ShopScreen extends StatefulWidget {
  final VoidCallback onViewCart;
  const ShopScreen({super.key, required this.onViewCart});
  @override State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  String _cat    = 'All';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<InventoryProvider>();
    final products  = inventory.sortedProducts;
    final orderProvider = context.watch<OrderProvider>();
    final preCart   = orderProvider.preCart;
    final buyAgain  = orderProvider.getBuyItAgainItems();
    final effectivelyClosed = inventory.settings.effectivelyClosed;
    final isOpen    = StoreHours.isOpen() && !effectivelyClosed;
    final auth      = context.read<AppAuthProvider>();

    final cats = ['All', ...inventory.products.map((p) => p.category).toSet().toList()..sort()];
    final filtered = products
        .where((p) => p.status == ProductStatus.published) // Requirement 7
        .where((p) => _cat == 'All' || p.category == _cat)
        .where((p) => _search.isEmpty || p.name.toLowerCase().contains(_search.toLowerCase()))
        .toList();

    final cartTotal = preCart.fold(0.0, (s, i) => s + i.price * i.qty);
    final cartCount = preCart.fold(0, (s, i) => s + i.qty);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──────────────────────────────────────────────────────
          SliverAppBar(
            floating: false,
            pinned: true,
            backgroundColor: Theme.of(context).colorScheme.surface,
            elevation: 0,
            scrolledUnderElevation: 0,
            toolbarHeight: 64,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Good day,', style: TextStyle(fontSize: 11, color: GdcColors.textSecondary, fontWeight: FontWeight.bold)),
                Text(auth.displayName.split(' ').first, 
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: GdcColors.textPrimary)),
              ],
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16),
                child: _StoreStatusChip(isOpen),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(110),
              child: Container(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _searchCtrl,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: GdcColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Search for groceries...',
                          prefixIcon: const Icon(Icons.search_rounded, color: GdcColors.terracotta, size: 20),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          suffixIcon: _search.isNotEmpty
                              ? IconButton(icon: const Icon(Icons.clear_rounded, size: 18), onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _search = '');
                                })
                              : null,
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        onChanged: (v) => setState(() => _search = v),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 44,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: cats.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) => ChoiceChip(
                          label: Text(cats[i]),
                          selected: _cat == cats[i],
                          onSelected: (selected) => setState(() {
                            _cat = cats[i];
                            if (_cat == 'All') {
                              _searchCtrl.clear();
                              _search = '';
                            }
                          }),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Store Announcement ───────────────────────────────────────────
          if (inventory.settings.announcement?.isNotEmpty ?? false)
            SliverToBoxAdapter(
              child: _AnnouncementTicker(text: inventory.settings.announcement!),
            ),

          // ── Loyalty Dashboard ─────────────────────────────────────────────
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: 8),
              child: LoyaltyDashboard(),
            ),
          ),

          // ── Buy it Again ──────────────────────────────────────────────────
          if (buyAgain.isNotEmpty)
            SliverToBoxAdapter(
              child: _BuyItAgainSection(
                items: buyAgain,
                allProducts: inventory.products,
                inCart: (id) => preCart.any((c) => c.productId == id),
                onAdd: (p) => context.read<OrderProvider>().addToPreCart(p),
              ),
            ),

          // ── Recipe Bundles ────────────────────────────────────────────────
          if (inventory.bundles.isNotEmpty)
            SliverToBoxAdapter(
              child: _BundlesSection(
                bundles: inventory.bundles,
                allProducts: inventory.products,
                onAdd: (bundle) {
                  final op = context.read<OrderProvider>();
                  for (final pid in bundle.productIds) {
                    try {
                      final p = inventory.products.firstWhere((prod) => prod.id == pid);
                      if (p.stock > 0) op.addToPreCart(p);
                    } catch (_) {}
                  }
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${bundle.name} items added to basket!'), backgroundColor: GdcColors.success));
                },
              ),
            ),

          // ── Closed Warning ────────────────────────────────────────────────
          if (effectivelyClosed)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDECEA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: GdcColors.error.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.store_mall_directory_rounded, color: GdcColors.error, size: 18),
                        SizedBox(width: 8),
                        Text('STORE CLOSED', 
                          style: TextStyle(color: GdcColors.error, fontWeight: FontWeight.w900, fontSize: 12, letterSpacing: 0.5)),
                      ],
                    ),
                    if (inventory.settings.closureMessage?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 6),
                      Text(inventory.settings.closureMessage!, textAlign: TextAlign.center, 
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: GdcColors.textPrimary)),
                    ],
                  ],
                ),
              ),
            ),

          // ── Product Grid ──────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            sliver: inventory.products.isEmpty 
              ? const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
              : (products.isEmpty 
                  ? const SliverFillRemaining(child: _EmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'Items are currently out of stock',
                      subtitle: 'Check back later for fresh inventory!',
                    ))
                  : (filtered.isEmpty
                      ? const SliverFillRemaining(child: _EmptyState(
                          icon: Icons.search_off_rounded,
                          title: 'No products found',
                          subtitle: 'Try a different search term or category',
                        ))
                      : SliverGrid(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.75,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, i) {
                              final p      = filtered[i];
                              final inCart = preCart.any((c) => c.productId == p.id);
                              final isOutOfStock = p.stock <= 0;
                              
                              return _ProductTile(
                                product: p,
                                inCart:  inCart,
                                isOutOfStock: isOutOfStock,
                                enabled: !effectivelyClosed && !isOutOfStock,
                                onTap: (effectivelyClosed || isOutOfStock) ? () {} : () {
                                  final op = context.read<OrderProvider>();
                                  if (inCart) {
                                    op.removeFromPreCart(p.id);
                                  } else {
                                    op.addToPreCart(p);
                                  }
                                },
                              );
                            },
                            childCount: filtered.length,
                          ),
                        ))),
          ),
        ],
      ),

      // ── Floating Cart Button ─────────────────────────────────────────────
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: (preCart.isNotEmpty && !effectivelyClosed)
        ? FloatingActionButton.extended(
            onPressed: widget.onViewCart,
            backgroundColor: GdcColors.terracotta,
            foregroundColor: Colors.white,
            elevation: 8,
            label: Text('$cartCount item${cartCount != 1 ? 's' : ''} · ${formatPeso(cartTotal)}',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.5)),
            icon: const Icon(Icons.shopping_basket_rounded),
          )
        : null,
    );
  }
}

// ── Product tile ───────────────────────────────────────────────────────────

class _ProductTile extends StatelessWidget {
  final Product product;
  final bool inCart;
  final bool isOutOfStock;
  final bool enabled;
  final VoidCallback onTap;
  const _ProductTile({required this.product, required this.inCart, required this.onTap, this.enabled = true, this.isOutOfStock = false});

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<GdcSemanticColors>();
    final perishableColor = semantic?.perishable ?? Colors.orange;
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isOutOfStock ? Colors.grey.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: inCart ? GdcColors.terracotta : GdcColors.terracotta.withOpacity(0.08),
            width: inCart ? 2 : 1.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Opacity(
          opacity: isOutOfStock ? 0.8 : 1.0,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
              Expanded(
                flex: 4,
                child: Stack(
                  children: [
                    Container(
                      width: double.infinity,
                      color: const Color(0xFFFDFDFD),
                      child: product.photoBase64 != null
                        ? ColorFiltered(
                            colorFilter: isOutOfStock 
                                ? const ColorFilter.mode(Colors.grey, BlendMode.saturation)
                                : const ColorFilter.mode(Colors.transparent, BlendMode.multiply),
                            child: Image.memory(base64Decode(product.photoBase64!), fit: BoxFit.cover),
                          )
                        : Icon(Icons.inventory_2_outlined, color: Colors.grey.shade100, size: 40),
                    ),
                    if (product.isPerishable && !isOutOfStock)
                      Positioned(
                        top: 8, left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                          decoration: BoxDecoration(
                            color: perishableColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            product.pickupWindowHours != null 
                                ? '${product.pickupWindowHours}H PICKUP' 
                                : 'PERISHABLE', 
                            style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
                        ),
                      ),
                    if (isOutOfStock)
                      Container(
                        color: Colors.black26,
                        child: const Center(
                          child: Text('OUT OF STOCK', 
                              style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 1)),
                        ),
                      ),
                  ],
                ),
              ),
              // Info
              Expanded(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(product.category.toUpperCase(),
                          style: const TextStyle(fontSize: 8.5, color: GdcColors.textMuted, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                      const SizedBox(height: 4),
                      Text(product.name,
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, height: 1.2, color: isOutOfStock ? Colors.grey : GdcColors.textPrimary),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      const Spacer(),
                      if (isOutOfStock)
                        _NotifyMeButton(productId: product.id)
                      else
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(formatPeso(product.price),
                                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: GdcColors.terracotta)),
                                  Text('${product.stock} ${product.unit} left',
                                      style: TextStyle(fontSize: 9.5, color: product.stock <= 5 ? GdcColors.error : GdcColors.textSecondary, fontWeight: FontWeight.w800)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: inCart ? GdcColors.terracotta : const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                inCart ? Icons.check_rounded : Icons.add_shopping_cart_rounded,
                                size: 16,
                                color: inCart ? Colors.white : GdcColors.terracotta,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotifyMeButton extends StatefulWidget {
  final String productId;
  const _NotifyMeButton({required this.productId});

  @override
  State<_NotifyMeButton> createState() => _NotifyMeButtonState();
}

class _NotifyMeButtonState extends State<_NotifyMeButton> {
  bool _isWatching = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  void _checkStatus() async {
    final email = context.read<AppAuthProvider>().email;
    final status = await context.read<InventoryProvider>().isWatching(widget.productId, email);
    if (mounted) setState(() { _isWatching = status; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox(height: 32, child: Center(child: SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))));

    return InkWell(
      onTap: _isWatching ? null : () async {
        final email = context.read<AppAuthProvider>().email;
        await context.read<InventoryProvider>().watchProduct(widget.productId, email);
        setState(() => _isWatching = true);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('We\'ll notify you when it\'s back!'), backgroundColor: GdcColors.success));
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        width: double.infinity,
        decoration: BoxDecoration(
          color: _isWatching ? GdcColors.success.withOpacity(0.1) : GdcColors.terracotta.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(_isWatching ? 'NOTIFYING' : 'NOTIFY ME', 
              style: TextStyle(color: _isWatching ? GdcColors.success : GdcColors.terracotta, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
        ),
      ),
    );
  }
}

// ── Store status chip ──────────────────────────────────────────────────────

class _StoreStatusChip extends StatelessWidget {
  final bool isOpen;
  const _StoreStatusChip(this.isOpen);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
        color: isOpen ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: isOpen ? const Color(0xFF2E7D32).withOpacity(0.3) : const Color(0xFFC62828).withOpacity(0.3))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isOpen ? GdcColors.success : GdcColors.error)),
      const SizedBox(width: 8),
      Text(isOpen ? 'Open · 11AM–3PM' : 'Pickup Closed',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900,
              color: isOpen ? const Color(0xFF2E7D32) : const Color(0xFFC62828))),
    ]),
  );
}

class _AnnouncementTicker extends StatefulWidget {
  final String text;
  const _AnnouncementTicker({required this.text});

  @override
  State<_AnnouncementTicker> createState() => _AnnouncementTickerState();
}

class _AnnouncementTickerState extends State<_AnnouncementTicker> with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startScrolling());
  }

  void _startScrolling() async {
    while (_scrollController.hasClients) {
      await Future.delayed(const Duration(seconds: 1));
      if (!_scrollController.hasClients) return;
      
      double maxScroll = _scrollController.position.maxScrollExtent;
      await _scrollController.animateTo(
        maxScroll, 
        duration: Duration(milliseconds: (maxScroll * 30).toInt()), 
        curve: Curves.linear
      );
      
      if (!_scrollController.hasClients) return;
      await Future.delayed(const Duration(seconds: 2));
      
      if (!_scrollController.hasClients) return;
      await _scrollController.animateTo(
        0, 
        duration: const Duration(milliseconds: 1000), 
        curve: Curves.easeOut
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      decoration: BoxDecoration(
        color: GdcColors.terracotta.withOpacity(0.05),
        borderRadius: BorderRadius.circular(50),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: GdcColors.terracotta,
              borderRadius: BorderRadius.circular(50),
            ),
            child: const Center(
              child: Text('NEWS', 
                  style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ListView(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                Center(
                  child: Text(
                    widget.text, 
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: GdcColors.terracotta),
                  ),
                ),
                const SizedBox(width: 100), // Gap before repeat if implemented
              ],
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
    );
  }
}

class _BundlesSection extends StatelessWidget {
  final List<ProductBundle> bundles;
  final List<Product> allProducts;
  final Function(ProductBundle) onAdd;

  const _BundlesSection({required this.bundles, required this.allProducts, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Text('Cooking Bundles', 
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: GdcColors.textPrimary)),
        ),
        SizedBox(
          height: 160,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: bundles.length,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (_, i) {
              final bundle = bundles[i];
              return Container(
                width: 280,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: GdcColors.terracotta.withOpacity(0.08)),
                ),
                clipBehavior: Clip.antiAlias,
                child: Row(
                  children: [
                    // Bundle Image/Icon
                    Container(
                      width: 100,
                      color: GdcColors.cream,
                      child: bundle.photoBase64 != null
                        ? Image.memory(base64Decode(bundle.photoBase64!), fit: BoxFit.cover)
                        : const Icon(Icons.auto_awesome_motion_rounded, color: GdcColors.terracotta, size: 40),
                    ),
                    // Info
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(bundle.name, 
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 4),
                            Text(bundle.description, 
                                style: const TextStyle(fontSize: 11, color: GdcColors.textMuted, height: 1.3),
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                            const Spacer(),
                            ElevatedButton(
                              onPressed: () => onAdd(bundle),
                              style: ElevatedButton.styleFrom(
                                minimumSize: const Size.fromHeight(32),
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('ADD ALL', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
                            ),
                          ],
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
    );
  }
}

class _BuyItAgainSection extends StatelessWidget {
  final List<CartItem> items;
  final List<Product> allProducts;
  final bool Function(String) inCart;
  final Function(Product) onAdd;

  const _BuyItAgainSection({required this.items, required this.allProducts, required this.inCart, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 24, 20, 12),
          child: Text('Buy it Again', 
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: GdcColors.textPrimary)),
        ),
        SizedBox(
          height: 90,
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
              
              if (p == null || p.stock <= 0) return const SizedBox.shrink();

              final added = inCart(p.id);

              return InkWell(
                onTap: () => onAdd(allProducts.firstWhere((prod) => prod.id == item.productId)),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: 160,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: added ? GdcColors.terracotta : GdcColors.terracotta.withOpacity(0.08)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(color: GdcColors.cream, borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.history_rounded, size: 20, color: GdcColors.terracotta),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(item.name, 
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: GdcColors.textPrimary),
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            Text(formatPeso(item.price), 
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: GdcColors.terracotta)),
                          ],
                        ),
                      ),
                      if (added)
                        const Icon(Icons.check_circle_rounded, size: 16, color: GdcColors.terracotta),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyState({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 56, color: Colors.grey.shade200),
        const SizedBox(height: 16),
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: GdcColors.textPrimary)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(fontSize: 12, color: GdcColors.textMuted, fontWeight: FontWeight.w500)),
      ],
    ),
  );
}
