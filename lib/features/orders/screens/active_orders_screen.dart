import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../widgets/cancel_order_dialog.dart';
import '../../../shared/models/order.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/order_provider.dart';
import '../widgets/order_stepper.dart';
import '../../../shared/widgets/common/status_badge.dart';
import '../../../core/utils/format.dart';
import '../../../core/theme/app_theme.dart';

class ActiveOrdersScreen extends StatefulWidget {
  const ActiveOrdersScreen({super.key});
  @override
  State<ActiveOrdersScreen> createState() => _ActiveOrdersScreenState();
}

class _ActiveOrdersScreenState extends State<ActiveOrdersScreen>
    with AutomaticKeepAliveClientMixin {
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

          if (ordersData.isEmpty &&
              snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final orders = ordersData
              .where((o) =>
                  o.status != OrderStatus.collected &&
                  o.status != OrderStatus.cancelled &&
                  o.status != OrderStatus.refunded &&
                  o.status != OrderStatus.refundRejected &&
                  !o.isExpired)
              .toList()
            ..sort((a, b) {
              final aReady = a.status == OrderStatus.ready;
              final bReady = b.status == OrderStatus.ready;
              if (aReady && !bReady) return -1;
              if (!aReady && bReady) return 1;
              return a.createdAt.compareTo(b.createdAt);
            });

          if (orders.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.receipt_long_outlined,
                      size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No active orders.',
                      style: TextStyle(
                          color: Colors.grey, fontWeight: FontWeight.bold)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            itemCount: orders.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 12, color: Colors.transparent),
            physics: const AlwaysScrollableScrollPhysics(),
            itemBuilder: (_, i) {
              final o = orders[i];
              final isOpen = _expanded == o.id;
              return _OrderCard(
                order: o,
                isOpen: isOpen,
                onToggle: () =>
                    setState(() => _expanded = isOpen ? null : o.id),
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
  const _OrderCard(
      {required this.order, required this.isOpen, required this.onToggle});

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: isOpen
                  ? GdcColors.terracotta.withValues(alpha: 0.3)
                  : Colors.transparent),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: isOpen ? 0.08 : 0.03),
                blurRadius: 15,
                offset: const Offset(0, 5))
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          Material(
            color: Colors.transparent,
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              onTap: onToggle,
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      order.orderId,
                      style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: GdcColors.warmBrown,
                          letterSpacing: 0.5),
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
                    Text(
                        '${order.items.length} items · ${DateFormat('MMM d, h:mm a').format(order.createdAt)}',
                        style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 13,
                            fontWeight: FontWeight.w500)),
                    if (order.expiresAt != null &&
                        !order.isExpired &&
                        (order.status == OrderStatus.pending ||
                            order.status == OrderStatus.staging ||
                            order.status == OrderStatus.ready))
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(children: [
                          const Icon(Icons.timer_outlined,
                              size: 14, color: GdcColors.error),
                          const SizedBox(width: 4),
                          Text(
                              'Exp: ${DateFormat('h:mm a').format(order.expiresAt!)}',
                              style: const TextStyle(
                                  color: GdcColors.error,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800)),
                          if (order.isExtended) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: GdcColors.forest.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: GdcColors.forest, width: 1),
                              ),
                              child: const Text(
                                'Extended (1-time limit reached)',
                                style: TextStyle(
                                  color: GdcColors.forest,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ] else if (OrderProvider.getAvailableExtensionMinutes(
                                  order.expiresAt,
                                  isExtended: order.isExtended) >
                              0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color:
                                    GdcColors.orangeCTA.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: GdcColors.orangeCTA, width: 1),
                              ),
                              child: Text(
                                '+ Extend (+${OrderProvider.getAvailableExtensionMinutes(order.expiresAt, isExtended: order.isExtended)} min)',
                                style: const TextStyle(
                                  color: GdcColors.orangeCTA,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ]),
                      ),
                  ],
                ),
              ),
              trailing: Icon(
                  isOpen
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: Colors.grey),
            ),
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
    if (order.status == OrderStatus.pending) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order is still at the pending stage.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final qrData = order.orderId.trim().isNotEmpty ? order.orderId : order.id;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: Theme.of(context).cardColor,
        title: Column(
          children: [
            const Text('Pickup QR Code',
                style: TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(order.orderId,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: GdcColors.terracotta)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Show this QR code to the store attendant.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade300, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SizedBox(
                width: 200,
                height: 200,
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 200.0,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square, color: Colors.black),
                  dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Colors.black),
                  errorStateBuilder: (c, err) => Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.qr_code_2_rounded,
                          size: 80, color: GdcColors.terracotta),
                      const SizedBox(height: 8),
                      Text(order.orderId,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CLOSE',
                  style: TextStyle(fontWeight: FontWeight.bold))),
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
          _NoticeBanner(
              icon: Icons.stars_rounded,
              color: GdcColors.terracotta,
              bgColor: GdcColors.terracotta.withValues(alpha: 0.08),
              text: 'Your order is ready! 🛍️'),
          const SizedBox(height: 16),
        ],
        OrderStepper(status: order.status),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('ITEMS',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: Colors.grey,
                    letterSpacing: 1.5)),
            TextButton.icon(
              onPressed: () => _showQr(context),
              icon: const Icon(Icons.qr_code_2_rounded, size: 18),
              label: const Text('SHOW QR CODE',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900)),
              style: TextButton.styleFrom(
                  foregroundColor: order.status == OrderStatus.pending
                      ? Colors.grey
                      : GdcColors.terracotta,
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...order.items.map((item) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text('${item.name} × ${item.qty}',
                                    style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ),
                              if (item.returnedQty > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                    border:
                                        Border.all(color: Colors.red.shade200),
                                  ),
                                  child: Text(
                                    'Returned: ${item.returnedQty}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (item.variantName != null)
                            Text('Flavor: ${item.variantName}',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: GdcColors.terracotta,
                                    fontWeight: FontWeight.w600)),
                          Text(
                            'Barcode: ${item.barcode.isNotEmpty ? item.barcode : "N/A"}',
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(formatPeso(item.price * item.qty),
                        style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: GdcColors.warmBrown)),
                  ]),
            )),
        const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1)),
        Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.warmSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.sage.withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 16, color: GdcColors.terracotta),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Return & Exchange Policy: Present this QR receipt at the store. Opened, unsealed, or tampered items cannot be refunded or swapped.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Total Amount',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Theme.of(context).colorScheme.onSurface)),
          Text(formatPeso(order.total),
              style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: GdcColors.terracotta)),
        ]),
        const SizedBox(height: 24),
        const Text('LOGISTICS',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: Colors.grey,
                letterSpacing: 1.5)),
        const SizedBox(height: 12),
        _InfoBox(
            icon: Icons.access_time_rounded,
            label: 'Pickup Time',
            value: order.pickupTime),
        const SizedBox(height: 8),
        _InfoBox(
            icon: Icons.location_on_rounded,
            label: 'Location',
            value: order.location),
        if (order.isExtended) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: GdcColors.cream,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(
                  color: GdcColors.forest.withValues(alpha: 0.3), width: 1.2),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline_rounded,
                    size: 16, color: GdcColors.forest),
                SizedBox(width: 6),
                Text(
                  'Pickup time extended (1-time limit reached)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: GdcColors.forest,
                  ),
                ),
              ],
            ),
          ),
        ] else if (OrderProvider.getAvailableExtensionMinutes(order.expiresAt,
                isExtended: order.isExtended) >
            0) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                HapticFeedback.lightImpact();
                final messenger = ScaffoldMessenger.of(context);
                final op = context.read<OrderProvider>();
                final ext = await op.extendOrderPickupTime(order.id);
                if (ext > 0) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                          '⏱ Pickup time extended by $ext mins! Extended up to 3:00 PM cutoff.'),
                      backgroundColor: GdcColors.forest,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.timer_outlined, size: 16),
              label: Text(
                'EXTEND PICKUP (+ ${OrderProvider.getAvailableExtensionMinutes(order.expiresAt, isExtended: order.isExtended)} MIN)',
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: GdcColors.orangeCTA,
                side: const BorderSide(color: GdcColors.orangeCTA, width: 1.5),
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100)),
              ),
            ),
          ),
        ],
        if (order.status != OrderStatus.cancelled &&
            order.status != OrderStatus.completed) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                HapticFeedback.lightImpact();
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => CancelOrderDialog(orderId: order.orderId),
                );

                if (confirm == true) {
                  if (context.mounted) {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await context.read<OrderProvider>().cancelOrder(order);
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Order cancelled successfully.'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Error cancelling order: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                }
              },
              icon: const Icon(Icons.close_rounded, size: 16),
              label: const Text(
                'Cancel Order',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFCE1B3D),
                side: const BorderSide(color: Color(0xFFCE1B3D), width: 1.5),
                minimumSize: const Size(double.infinity, 44),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100)),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoBox(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: GdcColors.cream,
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 16, color: GdcColors.terracotta)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.grey)),
                Text(
                  value,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
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

  const _NoticeBanner(
      {required this.icon,
      required this.color,
      required this.bgColor,
      required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
          color: bgColor, borderRadius: BorderRadius.circular(16)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w900, fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
