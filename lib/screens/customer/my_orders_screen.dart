import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/order.dart';
import '../../providers/auth_provider.dart';
import '../../providers/order_provider.dart';
import '../../widgets/status_badge.dart';
import '../../utils/format.dart';
import '../../config/theme.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});
  @override State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  String? _expanded;

  @override
  Widget build(BuildContext context) {
    final email = context.read<AppAuthProvider>().email;

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('My Orders', style: TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: GdcColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(50)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.circle, size: 8, color: GdcColors.success),
                SizedBox(width: 6),
                Text('LIVE', style: TextStyle(fontSize: 10, color: GdcColors.success, fontWeight: FontWeight.w900, letterSpacing: 1)),
              ]),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<PreOrder>>(
        stream: context.read<OrderProvider>().ordersStreamForEmail(email),
        builder: (context, snap) {
          if (snap.hasError) {
            return _ErrorState(error: snap.error.toString());
          }
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final orders = snap.data ?? [];

          if (orders.isEmpty) {
            return const _EmptyOrdersState();
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            itemCount: orders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final o = orders[i];
              final isOpen = _expanded == o.id;
              return _OrderCard(
                order: o,
                isOpen: isOpen,
                onToggle: () => setState(() => _expanded = isOpen ? null : o.id),
              );
            },
          );
        },
      ),
    );
  }
}

// ── Order card ─────────────────────────────────────────────────────────────

class _OrderCard extends StatelessWidget {
  final PreOrder order;
  final bool isOpen;
  final VoidCallback onToggle;
  const _OrderCard({required this.order, required this.isOpen, required this.onToggle});

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeInOut,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: isOpen ? GdcColors.terracotta.withOpacity(0.3) : Colors.transparent),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(isOpen ? 0.08 : 0.03), blurRadius: 15, offset: const Offset(0, 5))
      ],
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(children: [
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        onTap: onToggle,
        title: Row(children: [
          Text(order.orderId, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: GdcColors.warmBrown, letterSpacing: 0.5)),
          const Spacer(),
          StatusBadge(order.status),
        ]),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${order.items.length} items · ${DateFormat('MMM d, h:mm a').format(order.createdAt)}', 
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w500)),
              if (order.expiresAt != null && ![OrderStatus.collected, OrderStatus.cancelled].contains(order.status))
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(children: [
                    const Icon(Icons.timer_outlined, size: 14, color: GdcColors.error),
                    const SizedBox(width: 4),
                    Text('Exp: ${DateFormat('h:mm a').format(order.expiresAt!)}', 
                        style: const TextStyle(color: GdcColors.error, fontSize: 11, fontWeight: FontWeight.w800)),
                  ]),
                ),
            ],
          ),
        ),
        trailing: Icon(isOpen ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: Colors.grey),
      ),
      if (isOpen) ...[
        const Divider(height: 1, indent: 20, endIndent: 20),
        _OrderDetail(order: order),
      ],
    ]),
  );
}

// ── Order detail ───────────────────────────────────────────────────────────

class _OrderDetail extends StatelessWidget {
  final PreOrder order;
  const _OrderDetail({required this.order});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (order.status == OrderStatus.collected)
        _NoticeBanner(icon: Icons.check_circle_rounded, color: GdcColors.success, bgColor: GdcColors.success.withOpacity(0.08), text: 'Thank you for shopping!'),
      
      if (order.status == OrderStatus.ready)
        _NoticeBanner(icon: Icons.stars_rounded, color: GdcColors.terracotta, bgColor: GdcColors.terracotta.withOpacity(0.08), text: 'Your order is ready! 🛍️'),

      if (order.status == OrderStatus.cancelled)
        _NoticeBanner(icon: Icons.cancel_rounded, color: GdcColors.error, bgColor: GdcColors.error.withOpacity(0.08), text: 'Order Cancelled'),

      const SizedBox(height: 12),
      const Text('ITEMS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.5)),
      const SizedBox(height: 8),

      ...order.items.map((item) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('${item.name} × ${item.qty}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          Text(formatPeso(item.price * item.qty), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: GdcColors.warmBrown)),
        ]),
      )),

      const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
      
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Total Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        Text(formatPeso(order.total), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: GdcColors.terracotta)),
      ]),

      const SizedBox(height: 24),
      const Text('LOGISTICS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.5)),
      const SizedBox(height: 12),
      
      _InfoBox(icon: Icons.access_time_rounded, label: 'Pickup Time', value: order.pickupTime),
      const SizedBox(height: 8),
      _InfoBox(icon: Icons.location_on_rounded, label: 'Location', value: order.location),
      
      if (order.notes.isNotEmpty) ...[
        const SizedBox(height: 8),
        _InfoBox(icon: Icons.notes_rounded, label: 'Your Notes', value: order.notes),
      ],

      if (order.status == OrderStatus.collected) ...[
        const SizedBox(height: 24),
        _RefundSection(order: order),
      ],
    ]),
  );
}

// ── UI Components ─────────────────────────────────────────────────────────

class _InfoBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoBox({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: GdcColors.cream, borderRadius: BorderRadius.circular(8)), child: Icon(icon, size: 16, color: GdcColors.terracotta)),
      const SizedBox(width: 12),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      ]),
    ],
  );
}

class _EmptyOrdersState extends StatelessWidget {
  const _EmptyOrdersState();
  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(40.0),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.receipt_long_rounded, size: 100, color: Colors.grey.shade100),
      const SizedBox(height: 32),
      const Text('No orders yet', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black87)),
      const SizedBox(height: 12),
      const Text('Your pre-orders will appear here once you place them from the shop.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, height: 1.5)),
    ]),
  ));
}

class _ErrorState extends StatelessWidget {
  final String error;
  const _ErrorState({required this.error});
  @override
  Widget build(BuildContext context) => Center(child: Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.error_outline_rounded, size: 48, color: GdcColors.error),
      const SizedBox(height: 16),
      const Text('Something went wrong', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
      const SizedBox(height: 8),
      Text(error, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 12)),
    ]),
  ));
}

class _RefundSection extends StatelessWidget {
  final PreOrder order;
  const _RefundSection({required this.order});

  @override
  Widget build(BuildContext context) {
    final diff = DateTime.now().difference(order.createdAt).inDays;
    final hasPerishable = order.items.any((i) => i.isPerishable);
    final canRefund = !hasPerishable && diff <= 3;

    if (!canRefund) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)),
        child: Row(children: [
          const Icon(Icons.info_outline_rounded, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          Expanded(child: Text(hasPerishable ? 'Perishable goods are non-refundable.' : 'Refund period (3 days) has expired.', style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.w600))),
        ]),
      );
    }

    return OutlinedButton.icon(
      onPressed: () => _confirmRefund(context),
      icon: const Icon(Icons.assignment_return_rounded, size: 18),
      label: const Text('REQUEST REFUND'),
      style: OutlinedButton.styleFrom(
        foregroundColor: GdcColors.warmBrown,
        side: const BorderSide(color: GdcColors.creamDark),
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  void _confirmRefund(BuildContext context) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Request Refund'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Request a refund for order ${order.orderId}? It will be reviewed by the store manager.'),
            const SizedBox(height: 16),
            TextField(controller: reasonController, decoration: const InputDecoration(labelText: 'Reason', hintText: 'e.g. Quality issue'), maxLines: 2),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              try {
                await context.read<OrderProvider>().requestRefund(order.id, reasonController.text.trim());
                if (context.mounted) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Refund request submitted'), backgroundColor: GdcColors.success));
                }
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: GdcColors.error));
              }
            },
            child: const Text('Submit Request'),
          ),
        ],
      ),
    );
  }
}

class _NoticeBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bgColor;
  final String text;

  const _NoticeBanner({required this.icon, required this.color, required this.bgColor, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(16)),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 10),
        Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 13)),
      ]),
    );
  }
}
