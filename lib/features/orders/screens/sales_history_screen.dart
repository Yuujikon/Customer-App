import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../shared/models/order.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/order_provider.dart';
import '../../shop/providers/inventory_provider.dart';
import '../widgets/reorder_summary_dialog.dart';
import '../../../shared/widgets/common/status_badge.dart';
import '../../../core/utils/format.dart';
import '../../../core/theme/app_theme.dart';

class SalesHistoryScreen extends StatefulWidget {
  final Function(String category)? onBrowseSimilar;

  const SalesHistoryScreen({super.key, this.onBrowseSimilar});
  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen>
    with AutomaticKeepAliveClientMixin {
  String? _expanded;
  int _displayedCount = 10;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final auth = context.watch<AppAuthProvider>();
    final orderProvider = context.watch<OrderProvider>();
    final email = auth.email;

    return StreamBuilder<List<PreOrder>>(
      stream: orderProvider.ordersStreamForEmail(email),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));

        final ordersData = snap.data ?? orderProvider.orders;

        if (ordersData.isEmpty &&
            snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final history = ordersData
            .where((o) =>
                o.status == OrderStatus.collected ||
                o.status == OrderStatus.refundRequested ||
                o.status == OrderStatus.cancelled ||
                o.status == OrderStatus.refunded ||
                o.status == OrderStatus.refundRejected ||
                o.isExpired)
            .toList();

        if (history.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.history_rounded, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No past transactions.',
                    style: TextStyle(
                        color: Colors.grey, fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }

        final hasMore = history.length > _displayedCount;
        final displayedHistory = history.take(_displayedCount).toList();

        return ListView.separated(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            32 + MediaQuery.paddingOf(context).bottom,
          ),
          itemCount: displayedHistory.length + (hasMore ? 1 : 0),
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) {
            if (i == displayedHistory.length) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _displayedCount += 10),
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Load 10 More Transactions'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: GdcColors.terracotta,
                    side: const BorderSide(color: GdcColors.terracotta),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              );
            }
            final o = displayedHistory[i];
            final isOpen = _expanded == o.id;
            return _HistoryCard(
              order: o,
              isOpen: isOpen,
              onToggle: () => setState(() => _expanded = isOpen ? null : o.id),
              onBrowseSimilar: widget.onBrowseSimilar,
            );
          },
        );
      },
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final PreOrder order;
  final bool isOpen;
  final VoidCallback onToggle;
  final Function(String category)? onBrowseSimilar;

  const _HistoryCard(
      {required this.order,
      required this.isOpen,
      required this.onToggle,
      this.onBrowseSimilar});

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          Material(
            color: Colors.transparent,
            child: ListTile(
              onTap: onToggle,
              title: Text(order.orderId,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(DateFormat('MMM d, yyyy').format(order.createdAt)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(formatPeso(order.total),
                      style: const TextStyle(fontWeight: FontWeight.w900)),
                  const SizedBox(width: 8),
                  Icon(isOpen ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
          if (isOpen) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ITEMS',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: Colors.grey,
                          letterSpacing: 1.5)),
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
                                        child: Text('${item.qty}x ${item.name}',
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
                                            borderRadius:
                                                BorderRadius.circular(4),
                                            border: Border.all(
                                                color: Colors.red.shade200),
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
                                    Text('Variant: ${item.variantName}',
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
                            Text(formatPeso(item.price * item.qty)),
                          ],
                        ),
                      )),
                  const Divider(height: 24),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.warmSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: AppColors.sage.withValues(alpha: 0.3)),
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
                              color:
                                  Theme.of(context).textTheme.bodySmall?.color,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('TOTAL AMOUNT',
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onSurface)),
                      Text(formatPeso(order.total),
                          style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 18,
                              color: GdcColors.terracotta)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          StatusBadge(order.status),
                          if (order.status == OrderStatus.collected ||
                              order.status == OrderStatus.cancelled) ...[
                            const SizedBox(width: 8),
                            OutlinedButton.icon(
                              onPressed: () async {
                                final inventory =
                                    context.read<InventoryProvider>();
                                final orderProvider =
                                    context.read<OrderProvider>();

                                final previews = orderProvider.previewReorder(
                                    order.items, inventory.products);

                                final bool hasIssues = previews.any(
                                    (p) => p.isUnavailable || p.isAdjusted);

                                if (hasIssues) {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => ReorderSummaryDialog(
                                      previews: previews,
                                      onConfirm: () {
                                        orderProvider.applyReorder(previews);
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content:
                                                Text('Items added to basket.'),
                                            backgroundColor: AppColors.forest,
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                      },
                                      onBrowseSimilar: (category) {
                                        if (onBrowseSimilar != null) {
                                          onBrowseSimilar!(category);
                                        }
                                      },
                                    ),
                                  );
                                } else {
                                  orderProvider.applyReorder(previews);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('All items added to basket.'),
                                      backgroundColor: AppColors.forest,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.refresh_rounded, size: 14),
                              label: const Text('Buy Again',
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: GdcColors.terracotta,
                                side: const BorderSide(
                                    color: GdcColors.terracotta),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                minimumSize: const Size(0, 32),
                              ),
                            ),
                          ],
                        ],
                      ),
                      if (order.status == OrderStatus.collected)
                        _RefundButton(order: order)
                      else if (order.status == OrderStatus.refundRequested)
                        _CancelRefundButton(order: order),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ]),
      );
}

class _RefundButton extends StatelessWidget {
  final PreOrder order;
  const _RefundButton({required this.order});

  @override
  Widget build(BuildContext context) {
    // Basic business rules for customer refund request
    final diff = DateTime.now().difference(order.createdAt).inDays;
    final canRefund = diff <= 3;

    if (!canRefund) return const SizedBox.shrink();

    return TextButton.icon(
      onPressed: () => _showRefundRequestDialog(context),
      icon: const Icon(Icons.assignment_return_outlined, size: 16),
      label: const Text('Request Refund',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      style: TextButton.styleFrom(foregroundColor: GdcColors.error),
    );
  }

  void _showRefundRequestDialog(BuildContext context) async {
    final descCtrl = TextEditingController();
    final List<String> selectedReasons = [];

    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSt) => AlertDialog(
          title: const Text('Request Refund'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('What is the issue with your items?',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                CheckboxListTile(
                  title: const Text('Damaged Item',
                      style: TextStyle(fontSize: 14)),
                  value: selectedReasons.contains('Damaged'),
                  onChanged: (v) => setSt(() => v!
                      ? selectedReasons.add('Damaged')
                      : selectedReasons.remove('Damaged')),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                CheckboxListTile(
                  title: const Text('Expired Item',
                      style: TextStyle(fontSize: 14)),
                  value: selectedReasons.contains('Expired'),
                  onChanged: (v) => setSt(() => v!
                      ? selectedReasons.add('Expired')
                      : selectedReasons.remove('Expired')),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                CheckboxListTile(
                  title: const Text('Wrong Item Received',
                      style: TextStyle(fontSize: 14)),
                  value: selectedReasons.contains('Wrong Item'),
                  onChanged: (v) => setSt(() => v!
                      ? selectedReasons.add('Wrong Item')
                      : selectedReasons.remove('Wrong Item')),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Provide more details...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('CANCEL')),
            ElevatedButton(
              onPressed: selectedReasons.isEmpty
                  ? null
                  : () => Navigator.pop(ctx, true),
              child: const Text('SUBMIT'),
            ),
          ],
        ),
      ),
    );

    if (res == true && context.mounted) {
      final fullReason =
          '${selectedReasons.join(", ")}: ${descCtrl.text.trim()}';
      try {
        await context.read<OrderProvider>().requestRefund(order.id, fullReason);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Refund request submitted successfully.')));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }
}

class _CancelRefundButton extends StatelessWidget {
  final PreOrder order;
  const _CancelRefundButton({required this.order});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Text('Cancel Refund Request?'),
            content: Text(
                'Are you sure you want to cancel your refund request for order ${order.orderId}?'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('NO, KEEP IT')),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: GdcColors.error,
                  foregroundColor: Colors.white,
                ),
                child: const Text('YES, CANCEL REFUND'),
              ),
            ],
          ),
        );

        if (confirm == true && context.mounted) {
          final messenger = ScaffoldMessenger.of(context);
          try {
            await context
                .read<OrderProvider>()
                .cancelRefundRequest(transactionId: order.orderId);
            messenger.showSnackBar(const SnackBar(
              content: Text('Refund request cancelled.'),
              backgroundColor: GdcColors.success,
            ));
          } catch (e) {
            messenger.showSnackBar(SnackBar(
              content: Text('Error cancelling refund: $e'),
              backgroundColor: GdcColors.error,
            ));
          }
        }
      },
      icon: const Icon(Icons.cancel_outlined, size: 16),
      label: const Text('Cancel Refund',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      style: TextButton.styleFrom(foregroundColor: GdcColors.error),
    );
  }
}
