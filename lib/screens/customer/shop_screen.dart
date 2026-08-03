import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../models/product.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/order_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/format.dart';
import '../../utils/store_hours.dart';
import '../../config/theme.dart';

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
    final products  = inventory.sortedProducts.where((p) => p.stock > 0).toList();
    final preCart   = context.watch<OrderProvider>().preCart;
    final effectivelyClosed = inventory.settings.effectivelyClosed;
    final isOpen    = StoreHours.isOpen() && !effectivelyClosed;
    final auth      = context.read<AppAuthProvider>();

    final cats = ['All', ...inventory.products.map((p) => p.category).toSet().toList()..sort()];
    final filtered = products
        .where((p) => _cat == 'All' || p.category == _cat)
        .where((p) => _search.isEmpty || p.name.toLowerCase().contains(_search.toLowerCase()))
        .toList();

    final cartTotal = preCart.fold(0.0, (s, i) => s + i.price * i.qty);
    final cartCount = preCart.fold(0, (s, i) => s + i.qty);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // ── Premium App Bar / Header ─────────────────────────────────────
          SliverAppBar(
            expandedHeight: 180,
            floating: false,
            pinned: true,
            backgroundColor: Theme.of(context).colorScheme.surface,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Good day,', style: TextStyle(fontSize: 14, color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                            Text(auth.displayName.split(' ')[0], 
                                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                          ],
                        ),
                        _StoreStatusChip(isOpen),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text('${products.length} fresh items available today', 
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
          ),

          // ── Search & Filter Persistent Header ────────────────────────────
          SliverPersistentHeader(
            pinned: true,
            delegate: _SearchFilterDelegate(
              child: Container(
                color: Theme.of(context).colorScheme.surface.withOpacity(0.95),
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: 'Search for groceries...',
                          prefixIcon: const Icon(Icons.search_rounded, color: GdcColors.terracotta),
                          suffixIcon: _search.isNotEmpty
                              ? IconButton(icon: const Icon(Icons.clear_rounded), onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _search = '');
                                })
                              : null,
                          filled: true,
                          fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
                        ),
                        onChanged: (v) => setState(() => _search = v),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 40,
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

          // ── Closed Warning ────────────────────────────────────────────────
          if (effectivelyClosed)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).colorScheme.error.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.store_mall_directory_rounded, color: Theme.of(context).colorScheme.error),
                        const SizedBox(width: 8),
                        Text(inventory.settings.isClosed ? 'STORE TEMPORARILY CLOSED' : 'SCHEDULED CLOSURE', 
                          style: TextStyle(color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w800, fontSize: 12)),
                      ],
                    ),
                    if (inventory.settings.closureMessage?.isNotEmpty ?? false) ...[
                      const SizedBox(height: 8),
                      Text(inventory.settings.closureMessage!, textAlign: TextAlign.center, 
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
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
                  ? SliverFillRemaining(child: _EmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'Items are currently out of stock',
                      subtitle: 'Check back later for fresh inventory!',
                    ))
                  : (filtered.isEmpty
                      ? SliverFillRemaining(child: _EmptyState(
                          icon: Icons.search_off_rounded,
                          title: 'No products found',
                          subtitle: 'Try a different search term or category',
                        ))
                      : SliverGrid(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.72,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, i) {
                              final p      = filtered[i];
                              final inCart = preCart.any((c) => c.productId == p.id);
                              return _ProductTile(
                                product: p,
                                inCart:  inCart,
                                enabled: !effectivelyClosed,
                                onTap: effectivelyClosed ? () {} : () {
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
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: FloatingActionButton.extended(
              onPressed: widget.onViewCart,
              backgroundColor: GdcColors.terracotta,
              foregroundColor: Colors.white,
              elevation: 4,
              label: Text('$cartCount item${cartCount != 1 ? 's' : ''} · ${formatPeso(cartTotal)}'),
              icon: const Icon(Icons.shopping_basket_rounded),
            ),
          )
        : null,
    );
  }
}

// ── Search/Filter Delegate ──────────────────────────────────────────────────

class _SearchFilterDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _SearchFilterDelegate({required this.child});

  @override Widget build(context, double shrinkOffset, bool overlapsContent) => child;
  @override double get maxExtent => 125;
  @override double get minExtent => 125;
  @override bool shouldRebuild(_SearchFilterDelegate oldDelegate) => false;
}

// ── Product tile ───────────────────────────────────────────────────────────

class _ProductTile extends StatelessWidget {
  final Product product;
  final bool inCart;
  final bool enabled;
  final VoidCallback onTap;
  const _ProductTile({required this.product, required this.inCart, required this.onTap, this.enabled = true});

  @override
  Widget build(BuildContext context) {
    final semantic = Theme.of(context).extension<GdcSemanticColors>()!;
    
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: inCart ? GdcColors.terracotta : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        clipBehavior: Clip.antiAlias,
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
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                    ),
                    child: product.photoBase64 != null
                      ? Image.memory(base64Decode(product.photoBase64!), fit: BoxFit.cover)
                      : Icon(Icons.inventory_2_outlined, color: Colors.grey.shade200, size: 48),
                  ),
                  if (product.isPerishable)
                    Positioned(
                      top: 10, left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: semantic.perishable.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('PERISHABLE', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w900)),
                      ),
                    ),
                ],
              ),
            ),
            // Info
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(product.category.toUpperCase(),
                        style: TextStyle(fontSize: 9, color: Colors.grey.shade400, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
                    const SizedBox(height: 4),
                    Text(product.name,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, height: 1.2),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    const Spacer(),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(formatPeso(product.price),
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: GdcColors.terracotta)),
                              Text('${product.stock} ${product.unit} left',
                                  style: TextStyle(fontSize: 10, color: product.stock <= 5 ? Colors.red : Colors.grey.shade400, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: inCart ? GdcColors.terracotta : Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            inCart ? Icons.check_rounded : Icons.add_shopping_cart_rounded,
                            size: 18,
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
        borderRadius: BorderRadius.circular(50)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isOpen ? const Color(0xFF4CAF50) : const Color(0xFFEF5350))),
      const SizedBox(width: 8),
      Text(isOpen ? 'Open · 11AM–3PM' : 'Pickup Closed',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
              color: isOpen ? const Color(0xFF2E7D32) : const Color(0xFFC62828))),
    ]),
  );
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
        Icon(icon, size: 80, color: Colors.grey.shade200),
        const SizedBox(height: 20),
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 8),
        Text(subtitle, style: const TextStyle(fontSize: 13, color: Colors.grey)),
      ],
    ),
  );
}
