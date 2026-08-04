import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import '../../models/order.dart';
import '../../providers/auth_provider.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/order_provider.dart';
import '../../widgets/qty_control.dart';
import '../../utils/format.dart';
import '../../utils/store_hours.dart';
import '../../utils/pricing_engine.dart';
import '../../config/theme.dart';

const _pickupLocations = [
  'GDC Main Store – Sampaguita St.',
  'Blk 4 Pickup Hub – Narra Ave.',
  'Purok 3 Collection Point – Mabini St.',
  'Brgy Hall Drop-off – Rizal St.',
  'Other (call to arrange)',
];

class PreOrderScreen extends StatefulWidget {
  final VoidCallback onSubmitted;
  final VoidCallback onBrowseMore;
  const PreOrderScreen({super.key, required this.onSubmitted, required this.onBrowseMore});
  @override State<PreOrderScreen> createState() => _PreOrderScreenState();
}

class _PreOrderScreenState extends State<PreOrderScreen> {
  String    _location  = _pickupLocations[0];
  String    _slot      = '';
  String    _notes     = '';
  bool      _redeemPoints = false; 
  bool      _isSeniorPWD = false; // NEW
  bool      _schedOpen = false;
  String    _error     = '';
  bool      _loading   = false;
  PreOrder? _done;
  Timer?    _autoClearTimer;

  @override
  void dispose() {
    _autoClearTimer?.cancel();
    super.dispose();
  }

  void _startAutoClear() {
    _autoClearTimer?.cancel();
    _autoClearTimer = Timer(const Duration(minutes: 10), () {
      if (mounted) {
        setState(() {
          _done = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<OrderProvider>().preCart;

    if (_done != null) {
      return _ConfirmationScreen(
        order: _done!, 
        onTrack: () {
          setState(() => _done = null);
          widget.onSubmitted();
        },
        onBrowse: () {
          setState(() => _done = null);
          widget.onBrowseMore();
        },
      );
    }

    if (cart.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.shopping_basket_outlined, size: 100, color: Colors.grey.shade100),
              const SizedBox(height: 24),
              const Text('Your basket is empty',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black87)),
              const SizedBox(height: 12),
              const Text('Start adding some fresh groceries from the shop to prepare your pre-order.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, height: 1.5)),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: widget.onBrowseMore,
                style: ElevatedButton.styleFrom(minimumSize: const Size(200, 54)),
                child: const Text('GO TO SHOP'),
              ),
            ],
          ),
        ),
      );
    }

    final op            = context.read<OrderProvider>();
    final inventory      = context.read<InventoryProvider>();
    final auth           = context.watch<AppAuthProvider>();
    final settings       = inventory.settings;
    final effectivelyClosed = inventory.settings.effectivelyClosed;
    final products       = inventory.products;
    final hasPerishables  = cart.any((ci) =>
        products.any((p) => p.id == ci.productId && p.isPerishable));
    final onlyPerishables = cart.every((ci) =>
        products.any((p) => p.id == ci.productId && p.isPerishable));

    final breakdown = PricingEngine.calculate(
      items: cart, 
      allProducts: products, 
      activePromos: op.promotions,
      pointsToRedeem: _redeemPoints ? auth.loyaltyPoints : 0,
      isSeniorOrPWD: _isSeniorPWD,
    );

    final total = breakdown.total;
    
    // Calculate dynamic maxHours for slot picker and notice
    int minWindow = settings.standardWindowHours;
    for (final item in cart) {
      final p = products.firstWhere((prod) => prod.id == item.productId);
      int itemWindow;
      if (p.pickupWindowHours != null) {
        itemWindow = p.pickupWindowHours!;
      } else if (p.isPerishable) {
        itemWindow = settings.perishableWindowHours;
      } else {
        itemWindow = settings.standardWindowHours;
      }
      if (itemWindow < minWindow) minWindow = itemWindow;
    }
    
    if (hasPerishables && cart.any((i) => !i.isPerishable)) {
       if (settings.mixedWindowHours < minWindow) minWindow = settings.mixedWindowHours;
    }

    final slots = StoreHours.availableSlots(maxHours: minWindow);

    // Dynamic warning text
    String pickupNotice = '';
    if (onlyPerishables) {
      pickupNotice = 'Strict pickup: Your order contains only perishables. Please collect within $minWindow hours.';
    } else if (hasPerishables) {
      pickupNotice = 'Quality notice: Your order has perishable items. Pick up within $minWindow hours to ensure freshness.';
    } else {
      pickupNotice = 'Pick up within $minWindow hours. Uncollected orders will be cancelled.';
    }

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Review Order', style: TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32), 
        children: [
          // ── Pickup location ─────────────────────────────────────────────────
          _SectionHeader('Pickup Location'),
          DropdownButtonFormField<String>(
              value: _location,
              isExpanded: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.location_on_rounded, color: GdcColors.terracotta),
                hintText: 'Select where to pick up',
              ),
              items: _pickupLocations.map((l) => DropdownMenuItem(
                  value: l,
                  child: Text(l, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis))).toList(),
              onChanged: (v) => setState(() => _location = v!)),

          const SizedBox(height: 24),

          // ── Pickup schedule ─────────────────────────────────────────────────
          _SectionHeader('Preferred Pickup Time'),
          _SlotPicker(
            selectedSlot: _slot,
            isOpen: _schedOpen,
            slots: slots,
            hasPerishables: hasPerishables,
            onToggle: () => setState(() => _schedOpen = !_schedOpen),
            onSelect: (s) => setState(() {
              _slot = s;
              _schedOpen = false;
              _error = '';
            }),
          ),

          // Perishable warning
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: hasPerishables ? const Color(0xFFFFF3E0) : GdcColors.cream,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: hasPerishables ? const Color(0xFFFFCC80).withOpacity(0.5) : GdcColors.terracotta.withOpacity(0.1))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline_rounded,
                  size: 20, color: hasPerishables ? const Color(0xFFF57C00) : GdcColors.terracotta),
              const SizedBox(width: 12),
              Expanded(child: Text(
                  pickupNotice,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: hasPerishables ? const Color(0xFF7B4A00) : GdcColors.textSecondary, height: 1.4))),
            ]),
          ),

          const SizedBox(height: 24),

          // ── Loyalty Redemption ──────────────────────────────────────────────
          if (auth.loyaltyPoints >= 10) ...[
             _SectionHeader('Loyalty Rewards'),
             Card(
               elevation: 0,
               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: GdcColors.terracotta.withOpacity(0.1))),
               child: CheckboxListTile(
                 title: const Text('Redeem Suki Points', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                 subtitle: Text('Use ${auth.loyaltyPoints} points for ${formatPeso(auth.loyaltyPoints.toDouble())} discount', style: const TextStyle(fontSize: 12)),
                 value: _redeemPoints,
                 onChanged: (v) => setState(() => _redeemPoints = v ?? false),
                 secondary: const Icon(Icons.stars_rounded, color: Colors.amber),
                 activeColor: GdcColors.terracotta,
                 contentPadding: const EdgeInsets.symmetric(horizontal: 16),
               ),
             ),
             const SizedBox(height: 24),
          ],

          // ── Senior / PWD Discount ──────────────────────────────────────────
          _SectionHeader('Discounts'),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: GdcColors.terracotta.withOpacity(0.1))),
            child: CheckboxListTile(
              title: const Text('Senior / PWD Discount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              subtitle: const Text('Applies 20% discount (VAT Exempt)', style: TextStyle(fontSize: 12)),
              value: _isSeniorPWD,
              onChanged: (v) => setState(() => _isSeniorPWD = v ?? false),
              secondary: const Icon(Icons.badge_outlined, color: Colors.blue),
              activeColor: GdcColors.terracotta,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
          const SizedBox(height: 24),

          // ── Cart items ──────────────────────────────────────────────────────
          _SectionHeader('Items In Basket (${cart.length})'),
          ...cart.map((item) {
            final product = products.firstWhere((p) => p.id == item.productId, orElse: () => throw 'Product not found');
            return _CartItemRow(
              item: item, 
              stock: product.stock,
              onAdjust: (n) => context.read<OrderProvider>().setPreCartQty(item.productId, n, product.stock),
              onRemove: () => context.read<OrderProvider>().removeFromPreCart(item.productId),
            );
          }),

          const SizedBox(height: 16),

          // ── Special instructions ────────────────────────────────────────────
          TextField(
              decoration: const InputDecoration(
                labelText: 'Notes or Instructions (optional)',
                hintText: 'e.g. Please pack cold items together...',
                alignLabelWithHint: true,
                prefixIcon: Icon(Icons.notes_rounded, color: Colors.grey),
              ),
              maxLines: 2,
              onChanged: (v) => setState(() => _notes = v)),

          const SizedBox(height: 32),

          // ── Order summary + submit ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: GdcColors.warmBrown,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: GdcColors.warmBrown.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 8))
              ]
            ),
            child: Column(
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Grand Total', style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600)),
                  Text(formatPeso(total), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                ]),
                const Divider(height: 32, color: Colors.white12),
                const Row(children: [
                  Icon(Icons.payment_rounded, color: Colors.white54, size: 16),
                  SizedBox(width: 8),
                  Text('Pay in-store upon collection', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                ]),
                const SizedBox(height: 24),
                if (_error.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(_error, style: const TextStyle(color: Color(0xFFFFCDD2), fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ElevatedButton(
                    onPressed: (_loading || effectivelyClosed) ? null : () async {
                      if (_slot.isEmpty) {
                        setState(() => _error = 'Please select a pickup time slot.');
                        return;
                      }

                      final connectivity = await Connectivity().checkConnectivity();
                      if (connectivity.contains(ConnectivityResult.none)) {
                        if (context.mounted) {
                          _showNoInternet(context);
                        }
                        return;
                      }

                      setState(() { _error = ''; _loading = true; });
                      try {
                        final auth = context.read<AppAuthProvider>();
                        final order = await context.read<OrderProvider>().submitOrder(
                          customerName:  auth.displayName,
                          customerEmail: auth.email,
                          notes:         _notes,
                          location:      _location,
                          pickupSlot:    _slot,
                          allProducts:   context.read<InventoryProvider>().products,
                          pointsRedeemed: _redeemPoints ? auth.loyaltyPoints : 0,
                          isSeniorPWD: _isSeniorPWD,
                        );
                        setState(() { 
                          _done = order; 
                          _loading = false; 
                          _startAutoClear();
                        });
                      } catch (e) {
                        setState(() { _error = e.toString(); _loading = false; });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: GdcColors.warmBrown,
                      minimumSize: const Size.fromHeight(60),
                    ),
                    child: _loading
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3, color: GdcColors.warmBrown))
                        : Text(effectivelyClosed ? 'STORE CLOSED' : 'CONFIRM PRE-ORDER', style: const TextStyle(letterSpacing: 1.2, fontWeight: FontWeight.w900))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showNoInternet(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Offline'),
        content: const Text('You are currently offline. Please reconnect to submit your order.'),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
  }
}

// ── Components ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12, top: 4),
    child: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Colors.grey, letterSpacing: 0.5)),
  );
}

class _CartItemRow extends StatelessWidget {
  final CartItem item;
  final int stock;
  final ValueChanged<int> onAdjust;
  final VoidCallback onRemove;

  const _CartItemRow({required this.item, required this.stock, required this.onAdjust, required this.onRemove});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
    ),
    child: Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 50, height: 50,
              decoration: BoxDecoration(color: GdcColors.cream, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.inventory_2_outlined, color: GdcColors.terracotta, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text('${formatPeso(item.price)} each', style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w500)),
                ],
              ),
            ),
            Text(formatPeso(item.price * item.qty), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: GdcColors.terracotta)),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
              ),
            ),
            const Spacer(),
            QtyControl(qty: item.qty, max: stock, onChanged: onAdjust),
          ],
        ),
      ],
    ),
  );
}

class _SlotPicker extends StatelessWidget {
  final String selectedSlot;
  final bool isOpen;
  final List<Map<String, dynamic>> slots;
  final bool hasPerishables;
  final VoidCallback onToggle;
  final ValueChanged<String> onSelect;

  const _SlotPicker({required this.selectedSlot, required this.isOpen, required this.slots, required this.hasPerishables, required this.onToggle, required this.onSelect});

  @override
  Widget build(BuildContext context) => Column(
    children: [
      InkWell(
        onTap: onToggle,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selectedSlot.isNotEmpty ? GdcColors.terracotta : GdcColors.terracotta.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              Icon(Icons.schedule_rounded, color: selectedSlot.isNotEmpty ? GdcColors.terracotta : Colors.grey),
              const SizedBox(width: 12),
              Expanded(child: Text(selectedSlot.isEmpty ? 'Tap to choose a time slot' : selectedSlot, 
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: selectedSlot.isEmpty ? Colors.grey : Colors.black87))),
              Icon(isOpen ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: Colors.grey),
            ],
          ),
        ),
      ),
      if (isOpen) ...[
        const SizedBox(height: 8),
        Container(
          height: 220,
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey.shade100)),
          child: ListView.separated(
            padding: const EdgeInsets.all(8),
            itemCount: slots.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 40),
            itemBuilder: (_, i) {
              final s = slots[i];
              final isPast = s['isPast'] as bool? ?? false;
              final isSelected = selectedSlot == s['value'];
              return ListTile(
                dense: true,
                enabled: !isPast,
                onTap: () => onSelect(s['value'] as String),
                leading: Icon(Icons.circle, size: 8, color: isPast ? Colors.grey.shade200 : (isSelected ? GdcColors.terracotta : Colors.grey.shade300)),
                title: Text(s['label'] as String, style: TextStyle(fontSize: 13, fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600, color: isPast ? Colors.grey.shade300 : Colors.black87)),
                trailing: isPast ? const Text('CLOSED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: Colors.grey)) : (isSelected ? const Icon(Icons.check_circle_rounded, color: GdcColors.terracotta, size: 20) : null),
              );
            },
          ),
        ),
      ],
    ],
  );
}

// ── Order confirmation screen ──────────────────────────────────────────────

class _ConfirmationScreen extends StatelessWidget {
  final PreOrder order;
  final VoidCallback onTrack;
  final VoidCallback onBrowse;
  const _ConfirmationScreen({required this.order, required this.onTrack, required this.onBrowse});

  @override
  Widget build(BuildContext context) => Container(
    color: Colors.white,
    child: Center(child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.check_circle_rounded, size: 100, color: GdcColors.success),
        const SizedBox(height: 32),
        const Text('Order Placed!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        const Text("We've received your request and we're starting to prepare it.", textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, height: 1.5)),
        const SizedBox(height: 48),
        
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(color: GdcColors.cream, borderRadius: BorderRadius.circular(24)),
          child: Column(children: [
            const Text('ORDER REFERENCE', style: TextStyle(color: GdcColors.warmBrown, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            Text(order.orderId, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: GdcColors.warmBrown, letterSpacing: 1.5)),
          ]),
        ),
        
        const SizedBox(height: 40),
        ElevatedButton(onPressed: onTrack, child: const Text('TRACK MY ORDER')),
        const SizedBox(height: 16),
        OutlinedButton(onPressed: onBrowse, style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(54)), child: const Text('BROWSE MORE')),
      ]),
    )),
  );
}
