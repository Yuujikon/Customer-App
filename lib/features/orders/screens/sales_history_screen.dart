import 'dart:async';
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
import '../../../shared/services/time_service.dart';

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

    if (email.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_rounded, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Sign in to view past transactions.',
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

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
          side: BorderSide(color: Theme.of(context).dividerColor),
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
                        const Icon(Icons.info_outline_rounded,
                            size: 16, color: GdcColors.terracotta),
                        const SizedBox(width: 8),
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
                                  unawaited(showDialog(
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
                                  ));
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
    final diff = TimeService.now.difference(order.createdAt).inDays;
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

  Future<void> _showRefundRequestDialog(BuildContext context) async {
    final result = await showDialog<({String reason, List<CartItem> items})>(
      context: context,
      builder: (_) => _RefundRequestDialog(order: order),
    );

    if (result != null && context.mounted) {
      try {
        await context.read<OrderProvider>().requestRefund(
              order.id,
              result.reason,
              result.items,
            );
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

class _RefundRequestDialog extends StatefulWidget {
  final PreOrder order;
  const _RefundRequestDialog({required this.order});

  @override
  State<_RefundRequestDialog> createState() => _RefundRequestDialogState();
}

class _RefundRequestDialogState extends State<_RefundRequestDialog> {
  final _descCtrl = TextEditingController();
  final List<String> _selectedReasons = [];
  final List<CartItem> _selectedItems = [];

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Widget _buildCustomCheckbox(
      String title, bool isSelected, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        onTap: () => onChanged(!isSelected),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.check_box_rounded
                  : Icons.check_box_outline_blank_rounded,
              color: isSelected ? AppColors.forest : Colors.grey,
            ),
            const SizedBox(width: 12),
            Text(title, style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dialogBg = isDark ? theme.cardColor : const Color(0xFFF1F4EB);
    final tileBg = isDark ? theme.colorScheme.surface : Colors.white;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: dialogBg,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Request Refund',
              style: TextStyle(fontWeight: FontWeight.w600)),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
      contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Select items to refund:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ...widget.order.items.map((item) {
              final isSelected = _selectedItems.contains(item);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedItems.remove(item);
                      } else {
                        _selectedItems.add(item);
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? tileBg : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            isSelected ? AppColors.forest : theme.dividerColor,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected
                              ? Icons.check_box_rounded
                              : Icons.check_box_outline_blank_rounded,
                          color: isSelected ? AppColors.forest : Colors.grey,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${item.qty}x ${item.name}',
                                  style: const TextStyle(fontSize: 14)),
                              Text(
                                formatPeso(item.price * item.qty),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.textTheme.bodySmall?.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
            const Text('What is the issue with your items?',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            _buildCustomCheckbox(
              'Damaged Item',
              _selectedReasons.contains('Damaged'),
              (v) => setState(() => v
                  ? _selectedReasons.add('Damaged')
                  : _selectedReasons.remove('Damaged')),
            ),
            _buildCustomCheckbox(
              'Expired Item',
              _selectedReasons.contains('Expired'),
              (v) => setState(() => v
                  ? _selectedReasons.add('Expired')
                  : _selectedReasons.remove('Expired')),
            ),
            _buildCustomCheckbox(
              'Wrong Item Received',
              _selectedReasons.contains('Wrong Item'),
              (v) => setState(() => v
                  ? _selectedReasons.add('Wrong Item')
                  : _selectedReasons.remove('Wrong Item')),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descCtrl,
              maxLines: 1,
              decoration: InputDecoration(
                hintText: 'Provide more details...',
                hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
                prefixIcon: const Icon(Icons.chat_bubble_outline_rounded,
                    size: 20, color: Colors.grey),
                filled: true,
                fillColor: tileBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.dividerColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.dividerColor),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      actions: [
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.forest,
                ),
                child: const Text('CANCEL',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: (_selectedReasons.isEmpty || _selectedItems.isEmpty)
                    ? null
                    : () {
                        final details = _descCtrl.text.trim();
                        final reason = details.isEmpty
                            ? _selectedReasons.join(', ')
                            : '${_selectedReasons.join(', ')}: $details';
                        Navigator.pop(
                          context,
                          (
                            reason: reason,
                            items: List<CartItem>.from(_selectedItems),
                          ),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.forest,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('SUBMIT',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CancelRefundButton extends StatelessWidget {
  final PreOrder order;
  const _CancelRefundButton({required this.order});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dialogBg = theme.brightness == Brightness.dark
        ? theme.cardColor
        : const Color(0xFFF1F4EB);

    return TextButton.icon(
      onPressed: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: dialogBg,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Column(
              children: [
                Icon(Icons.error_outline_rounded,
                    color: GdcColors.terracotta, size: 28),
                SizedBox(height: 8),
                Text('Cancel Refund?',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
            content: const Text(
                'Are you sure you want to cancel your refund request?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14)),
            actionsAlignment: MainAxisAlignment.center,
            actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            actions: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.forest,
                        side: const BorderSide(
                            color: AppColors.forest, width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('No, Keep It',
                          style: TextStyle(fontWeight: FontWeight.bold))),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GdcColors.error,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Yes, Cancel Refund',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
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
