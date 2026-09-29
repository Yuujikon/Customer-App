import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../shared/models/order.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/order_provider.dart';
import '../widgets/order_stepper.dart';
import '../../../shared/widgets/common/status_badge.dart';
import '../../../core/utils/format.dart';
import '../../../core/theme/app_theme.dart';

class ActiveOrdersScreen extends StatefulWidget {
  const ActiveOrdersScreen({super.key});
  @override State<ActiveOrdersScreen> createState() => _ActiveOrdersScreenState();
}

class _ActiveOrdersScreenState extends State<ActiveOrdersScreen> with AutomaticKeepAliveClientMixin {
  String? _expanded;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final auth = context.watch<AppAuthProvider>();
    final orderProvider = context.watch<OrderProvider>();
    final email = auth.email;

    if (email.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () async {
        orderProvider.ordersStreamForEmail(email, limit: 50);
        await Future.delayed(const Duration(milliseconds: 800));
      },
      child: StreamBuilder<List<PreOrder>>(
        stream: orderProvider.ordersStreamForEmail(email),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          
          final ordersData = snap.data ?? orderProvider.orders;
          
          if (ordersData.isEmpty && snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final orders = ordersData.where((o) => 
              o.status != OrderStatus.collected && 
              o.status != OrderStatus.cancelled &&
              o.status != OrderStatus.refunded &&
              o.status != OrderStatus.refundRejected &&
              !o.isExpired).toList();

          if (orders.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No active orders.', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            itemCount: orders.length,
            separatorBuilder: (_, __) => const Divider(height: 12, color: Colors.transparent),
            physics: const AlwaysScrollableScrollPhysics(),
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
      border: Border.all(color: isOpen ? GdcColors.terracotta.withValues(alpha: 0.3) : Colors.transparent),
      boxShadow: [
        BoxShadow(color: Colors.black.withValues(alpha: isOpen ? 0.08 : 0.03), blurRadius: 15, offset: const Offset(0, 5))
      ],
    ),
    clipBehavior: Clip.antiAlias,
    child: Column(children: [
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        onTap: onToggle,
        title: Row(
          children: [
            Expanded(
              child: Text(
                order.orderId, 
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: GdcColors.warmBrown, letterSpacing: 0.5),
                maxLines: 1, 
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            StatusBadge(order.status),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${order.items.length} items · ${DateFormat('MMM d, h:mm a').format(order.createdAt)}', 
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w500)),
              if (order.expiresAt != null && !order.isExpired && (order.status == OrderStatus.pending || order.status == OrderStatus.staging || order.status == OrderStatus.ready))
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

class _OrderDetail extends StatelessWidget {
  final PreOrder order;
  const _OrderDetail({required this.order});

  void _showQr(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Column(
          children: [
            const Text('Pickup QR Code', style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(order.orderId, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Show this to the store attendant.', textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: QrImageView(
                data: order.orderId,
                version: QrVersions.auto,
                size: 200.0,
                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: GdcColors.warmBrown),
                dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: GdcColors.warmBrown),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CLOSE')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (order.status == OrderStatus.ready) ...[
          _NoticeBanner(icon: Icons.stars_rounded, color: GdcColors.terracotta, bgColor: GdcColors.terracotta.withValues(alpha: 0.08), text: 'Your order is ready! 🛍️'),
          const SizedBox(height: 16),
        ],

        OrderStepper(status: order.status),
        const SizedBox(height: 24),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('ITEMS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.5)),
            if (order.status == OrderStatus.ready)
              TextButton.icon(
                onPressed: () => _showQr(context),
                icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                label: const Text('SHOW QR', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
                style: TextButton.styleFrom(foregroundColor: GdcColors.terracotta, padding: EdgeInsets.zero, minimumSize: Size.zero),
              ),
          ],
        ),
        const SizedBox(height: 8),

        ...order.items.map((item) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${item.name} × ${item.qty}', 
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (item.variantName != null)
                    Text('Flavor: ${item.variantName}', style: const TextStyle(fontSize: 11, color: GdcColors.terracotta, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(formatPeso(item.price * item.qty), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: GdcColors.warmBrown)),
          ]),
        )),

        const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
        
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Total Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: GdcColors.textPrimary)),
          Text(formatPeso(order.total), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: GdcColors.terracotta)),
        ]),

        const SizedBox(height: 24),
        const Text('LOGISTICS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.5)),
        const SizedBox(height: 12),
        
        _InfoBox(icon: Icons.access_time_rounded, label: 'Pickup Time', value: order.pickupTime),
        const SizedBox(height: 8),
        _InfoBox(icon: Icons.location_on_rounded, label: 'Location', value: order.location),
      ]),
    );
  }
}

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
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, 
          children: [
            Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.grey)),
            Text(
              value, 
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    ],
  );
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center, 
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              text, 
              style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
