import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../../shared/models/order.dart';
import '../../../shared/models/product.dart';
import '../../auth/providers/auth_provider.dart';
import '../../shop/providers/inventory_provider.dart';
import '../providers/order_provider.dart';
import '../../../shared/widgets/common/qty_control.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/store_hours.dart';
import '../../../core/utils/pricing_engine.dart';
import '../../../core/theme/app_theme.dart';

const _pickupLocations = [
  'GDC Main Store – Sampaguita St.',
];

class PreOrderScreen extends StatefulWidget {
  final VoidCallback onSubmitted;
  final VoidCallback onBrowseMore;
  const PreOrderScreen({super.key, required this.onSubmitted, required this.onBrowseMore});
  @override State<PreOrderScreen> createState() => _PreOrderScreenState();
}

class _PreOrderScreenState extends State<PreOrderScreen> {
  final String _location  = _pickupLocations[0];
  String    _slot      = '';
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

  Future<void> _pickPickupDateTime(BuildContext context, int minWindow) async {
    final availableDates = StoreHours.getAvailableDates(maxHours: minWindow);
    if (availableDates.isEmpty) return;

    // 1. Launch Calendar Date Picker
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: availableDates.first,
      firstDate: availableDates.first,
      lastDate: availableDates.last,
      selectableDayPredicate: (d) {
        return availableDates.any((ad) => ad.year == d.year && ad.month == d.month && ad.day == d.day);
      },
      helpText: 'SELECT PICKUP DATE',
      confirmText: 'NEXT: SELECT TIME',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: GdcColors.terracotta,
              onPrimary: Colors.white,
              onSurface: GdcColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null || !context.mounted) return;

    // 2. Select Pickup Time for the chosen Calendar Date
    final daySlots = StoreHours.getTimeSlotsForDate(pickedDate, maxHours: minWindow);
    final isToday = pickedDate.year == DateTime.now().year &&
        pickedDate.month == DateTime.now().month &&
        pickedDate.day == DateTime.now().day;
    final dateLabel = isToday ? 'Today' : DateFormat('EEE, MMM d').format(pickedDate);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
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
            const SizedBox(height: 20),
            Row(
              children: [
                const Icon(Icons.access_time_rounded, color: GdcColors.terracotta, size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pickup Time for $dateLabel',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: GdcColors.textPrimary)),
                      const Text('Store Operating Hours: 9:00 AM – 10:00 PM',
                          style: TextStyle(fontSize: 12, color: GdcColors.textSecondary, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (daySlots.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No pickup slots available for this date.',
                    style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                ),
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: daySlots.map((s) {
                  final val = s['value'] as String;
                  final timeLabel = s['timeLabel'] as String;
                  final isSelected = _slot == val;

                  return InkWell(
                    onTap: () {
                      setState(() {
                        _slot = val;
                        _error = '';
                      });
                      Navigator.pop(ctx);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? GdcColors.terracotta : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? GdcColors.terracotta : Colors.grey.shade200,
                        ),
                      ),
                      child: Text(
                        timeLabel,
                        style: TextStyle(
                          color: isSelected ? Colors.white : GdcColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<OrderProvider>().preCart;
    final inventory = context.watch<InventoryProvider>();
    final products = inventory.products;

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

    final inventoryProvider = context.read<InventoryProvider>();
    final settings       = inventoryProvider.settings;
    final effectivelyClosed = settings.effectivelyClosed;
    
    final hasPerishables  = cart.any((ci) =>
        products.any((p) => p.id == ci.productId && p.isPerishable));
    final onlyPerishables = cart.every((ci) =>
        products.any((p) => p.id == ci.productId && p.isPerishable));

    final breakdown = PricingEngine.calculate(
      items: cart, 
      allProducts: products,
    );

    final total = breakdown.total;

    // Check for stock issues in real-time
    bool hasStockIssues = false;
    for (final item in cart) {
      try {
        final p = products.firstWhere((prod) => prod.id == item.productId);
        int currentStock = p.stock;
        if (item.variantId != null) {
           currentStock = p.variants?[item.variantId]?.stock ?? 0;
        }
        if (currentStock < item.qty) {
          hasStockIssues = true;
          break;
        }
      } catch (_) {
        hasStockIssues = true;
        break;
      }
    }

    // Determine window based on products
    int minWindow = settings.standardWindowHours;
    for (final item in cart) {
      final p = products.firstWhere((prod) => prod.id == item.productId, orElse: () => products.first);
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
          const _SectionHeader('Pickup Location'),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: GdcColors.terracotta.withValues(alpha: 0.15)),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on_rounded, color: GdcColors.terracotta),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _location,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: GdcColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Pickup schedule ─────────────────────────────────────────────────
          const _SectionHeader('Preferred Pickup Time'),
          InkWell(
            onTap: () => _pickPickupDateTime(context, minWindow),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _slot.isEmpty 
                      ? GdcColors.terracotta.withValues(alpha: 0.3) 
                      : GdcColors.terracotta, 
                  width: _slot.isEmpty ? 1 : 2,
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4))
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: GdcColors.terracotta.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.calendar_month_rounded, 
                      size: 22, 
                      color: GdcColors.terracotta,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _slot.isEmpty ? 'Select Pickup Date & Time' : _slot, 
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold, 
                            color: _slot.isEmpty ? Colors.grey : GdcColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _slot.isEmpty ? 'Tap to open calendar' : 'Tap to change pickup schedule',
                          style: const TextStyle(fontSize: 11, color: GdcColors.textMuted, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios_rounded, 
                    size: 16, 
                    color: Colors.grey,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Perishable warning
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: hasPerishables ? const Color(0xFFFFF3E0) : GdcColors.cream,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: hasPerishables ? const Color(0xFFFFCC80).withValues(alpha: 0.5) : GdcColors.terracotta.withValues(alpha: 0.1))),
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

          // ── Cart items ──────────────────────────────────────────────────────
          _SectionHeader('Items In Basket (${cart.length})'),
          ...cart.map((item) {
            Product? product;
            try {
               product = products.firstWhere((p) => p.id == item.productId);
            } catch (_) {}

            if (product == null) {
              return _CartIssueRow(name: item.name, reason: 'Item no longer exists');
            }

            int currentStock = product.stock;
            if (item.variantId != null) {
              currentStock = product.variants?[item.variantId]?.stock ?? 0;
            }

            return _CartItemRow(
              item: item, 
              stock: currentStock,
              onAdjust: (n) => context.read<OrderProvider>().setPreCartQty(item.productId, n, currentStock, variantId: item.variantId),
              onRemove: () => context.read<OrderProvider>().removeFromPreCart(item.productId, variantId: item.variantId),
            );
          }),

          const SizedBox(height: 32),

          // ── Order summary + submit ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: GdcColors.warmBrown,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(color: GdcColors.warmBrown.withValues(alpha: 0.2), blurRadius: 15, offset: const Offset(0, 8))
              ]
            ),
            child: Column(
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Expanded(
                    child: Text('Grand Total', 
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 8),
                  Text(formatPeso(total), style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                ]),
                const SizedBox(height: 16),
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
                    onPressed: (_loading || effectivelyClosed || hasStockIssues) ? null : () async {
                      if (_slot.isEmpty) {
                        setState(() => _error = 'Please select a pickup time slot.');
                        return;
                      }

                      final authProvider = context.read<AppAuthProvider>();
                      final orderProvider = context.read<OrderProvider>();
                      final invProvider = context.read<InventoryProvider>();

                      final connectivity = await Connectivity().checkConnectivity();
                      if (connectivity.contains(ConnectivityResult.none)) {
                        if (context.mounted) {
                          _showNoInternet(context);
                        }
                        return;
                      }

                      setState(() { _error = ''; _loading = true; });

                      final userPhone = authProvider.phoneNumber;
                      final phoneToUse = (userPhone != null && userPhone.trim().isNotEmpty)
                          ? userPhone.trim()
                          : 'N/A';

                      // Strict Inventory Re-Validation immediately before push
                      final latestProducts = invProvider.products;
                      bool stockIssues = false;
                      List<String> issues = [];

                      for (final item in cart) {
                        try {
                          final p = latestProducts.firstWhere((prod) => prod.id == item.productId);
                          int s = p.stock;
                          if (item.variantId != null) {
                            s = p.variants?[item.variantId]?.stock ?? 0;
                          }

                          if (s < item.qty) {
                            stockIssues = true;
                            issues.add('${p.name}: only $s available');
                          }
                        } catch (_) {
                          stockIssues = true;
                          issues.add('${item.name} is no longer available');
                        }
                      }

                      if (stockIssues) {
                        setState(() {
                          _error = 'Inventory changed:\n${issues.join('\n')}';
                          _loading = false;
                        });
                        return;
                      }

                      try {
                        final order = await orderProvider.submitOrder(
                          customerName:  authProvider.displayName,
                          customerEmail: authProvider.email,
                          customerPhone: phoneToUse,
                          location:      _location,
                          pickupSlot:    _slot,
                          allProducts:   invProvider.products,
                        );
                        if (!mounted) return;
                        setState(() { 
                          _done = order; 
                          _loading = false; 
                          _startAutoClear();
                        });
                      } catch (e) {
                        if (!mounted) return;
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
                        : Text(effectivelyClosed ? 'STORE CLOSED' : (hasStockIssues ? 'INSUFFICIENT STOCK' : 'CONFIRM PRE-ORDER'), 
                            style: const TextStyle(letterSpacing: 1.2, fontWeight: FontWeight.w900))),
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

class _CartIssueRow extends StatelessWidget {
  final String name;
  final String reason;
  const _CartIssueRow({required this.name, required this.reason});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: GdcColors.error.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: GdcColors.error.withValues(alpha: 0.2))),
    child: Row(children: [
      const Icon(Icons.error_outline_rounded, color: GdcColors.error, size: 20),
      const SizedBox(width: 12),
      Expanded(child: Text('$name: $reason', style: const TextStyle(color: GdcColors.error, fontSize: 12, fontWeight: FontWeight.bold))),
    ]),
  );
}

class _CartItemRow extends StatelessWidget {
  final CartItem item;
  final int stock;
  final ValueChanged<int> onAdjust;
  final VoidCallback onRemove;

  const _CartItemRow({required this.item, required this.stock, required this.onAdjust, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final isInsufficient = stock < item.qty;
    final isSoldOut = stock <= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: isInsufficient ? Border.all(color: GdcColors.error.withValues(alpha: 0.3), width: 1.5) : null,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    if (item.variantName != null)
                      Text('Flavor: ${item.variantName}', style: const TextStyle(fontSize: 12, color: GdcColors.terracotta, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              IconButton(onPressed: onRemove, icon: const Icon(Icons.delete_outline_rounded, color: Colors.grey, size: 20)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: isSoldOut
                    ? const Text('⚠️ SOLD OUT', style: TextStyle(color: GdcColors.error, fontWeight: FontWeight.w900, fontSize: 12))
                    : (isInsufficient
                        ? Text('⚠️ ONLY $stock LEFT', style: const TextStyle(color: GdcColors.error, fontWeight: FontWeight.w900, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)
                        : Text(formatPeso(item.price), style: const TextStyle(fontWeight: FontWeight.w800, color: GdcColors.terracotta), maxLines: 1, overflow: TextOverflow.ellipsis)),
              ),
              const SizedBox(width: 8),
              QtyControl(qty: item.qty, max: stock, onChanged: onAdjust),
            ],
          ),
        ],
      ),
    );
  }
}

class _ConfirmationScreen extends StatelessWidget {
  final PreOrder order;
  final VoidCallback onTrack;
  final VoidCallback onBrowse;

  const _ConfirmationScreen({required this.order, required this.onTrack, required this.onBrowse});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(color: Color(0xFFE8F5E9), shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_rounded, size: 80, color: Colors.green),
            ),
            const SizedBox(height: 32),
            const Text('Pre-Order Placed!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            Text('Order Reference: ${order.orderId}', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            const Text('Your order is being prepared. We will notify you once it is ready for collection.', 
                textAlign: TextAlign.center, style: TextStyle(color: GdcColors.textSecondary, height: 1.5)),
            const SizedBox(height: 48),
            ElevatedButton(onPressed: onTrack, child: const Text('TRACK ORDER STATUS')),
            const SizedBox(height: 16),
            TextButton(onPressed: onBrowse, child: const Text('BACK TO SHOP', style: TextStyle(fontWeight: FontWeight.bold, color: GdcColors.terracotta))),
          ],
        ),
      ),
    ),
  );
}
