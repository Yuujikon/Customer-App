import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../shared/models/refund_request.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/order_provider.dart';
import '../../../core/utils/format.dart';
import '../../../core/theme/app_theme.dart';

class RefundRequestsScreen extends StatefulWidget {
  const RefundRequestsScreen({super.key});

  @override
  State<RefundRequestsScreen> createState() => _RefundRequestsScreenState();
}

class _RefundRequestsScreenState extends State<RefundRequestsScreen> with AutomaticKeepAliveClientMixin {
  int _displayedCount = 10;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final auth = context.watch<AppAuthProvider>();
    final orderProvider = context.watch<OrderProvider>();
    final email = auth.email;

    return StreamBuilder<List<RefundRequest>>(
      stream: orderProvider.refundRequestsStreamForEmail(email),
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Error: ${snap.error}'));
        
        if (!snap.hasData && snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final reqs = snap.data ?? [];
        if (reqs.isEmpty) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.assignment_return_rounded, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('No refund claims found.', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              ],
            ),
          );
        }

        final hasMore = reqs.length > _displayedCount;
        final displayedReqs = reqs.take(_displayedCount).toList();

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: displayedReqs.length + (hasMore ? 1 : 0),
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) {
            if (i == displayedReqs.length) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: OutlinedButton.icon(
                  onPressed: () => setState(() => _displayedCount += 10),
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Load 10 More Refund Claims'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: GdcColors.terracotta,
                    side: const BorderSide(color: GdcColors.terracotta),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              );
            }
            return _RefundRequestCard(req: displayedReqs[i]);
          },
        );
      },
    );
  }
}

class _RefundRequestCard extends StatelessWidget {
  final RefundRequest req;
  const _RefundRequestCard({required this.req});

  Future<void> _confirmCancelRefund(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cancel Refund Request?'),
        content: Text('Are you sure you want to cancel the refund request for #${req.transactionId}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('NO, KEEP IT'),
          ),
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
      final op = context.read<OrderProvider>();
      try {
        await op.cancelRefundRequest(transactionId: req.transactionId, requestId: req.id);
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Refund request cancelled successfully.'),
            backgroundColor: GdcColors.success,
          ),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error cancelling refund: $e'),
            backgroundColor: GdcColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color color = switch (req.status) {
      RefundStatus.pending => GdcColors.warning,
      RefundStatus.approved => GdcColors.success,
      RefundStatus.rejected => GdcColors.error,
    };

    final hasResponse = req.adminNotes != null && req.adminNotes!.trim().isNotEmpty;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: color.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(DateFormat('MMM dd, yyyy').format(req.createdAt), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(req.status.name.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Ref #: ${req.transactionId}', style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Reason: ${req.reason}', style: const TextStyle(fontSize: 13, color: GdcColors.textSecondary)),
            if (hasResponse) ...[
              const Divider(height: 16),
              const Text('STORE RESPONSE:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey)),
              const SizedBox(height: 4),
              Text(req.adminNotes!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic)),
            ],
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${req.items.length} item(s)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                Text(formatPeso(req.total), style: const TextStyle(fontWeight: FontWeight.w900, color: GdcColors.terracotta)),
              ],
            ),
            if (req.status == RefundStatus.pending) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _confirmCancelRefund(context),
                  icon: const Icon(Icons.cancel_outlined, size: 16),
                  label: const Text('CANCEL REFUND REQUEST', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: GdcColors.error,
                    side: BorderSide(color: GdcColors.error.withValues(alpha: 0.4)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
