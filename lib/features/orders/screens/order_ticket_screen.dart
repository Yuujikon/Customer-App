import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../shared/models/order.dart';
import '../providers/order_provider.dart';
import '../../../core/utils/format.dart';
import '../../../core/utils/launcher.dart';
import '../../../core/theme/app_theme.dart';

/// Material 3 Order Ticket Screen (Checkout Success UI)
/// Displays the 6-character alphanumeric Order ID, dynamic QR code,
/// strict Cash Only notice, order summary, and pickup details.
class OrderTicketScreen extends StatelessWidget {
  final PreOrder order;
  final VoidCallback onTrackOrder;
  final VoidCallback onBackToShop;

  const OrderTicketScreen({
    super.key,
    required this.order,
    required this.onTrackOrder,
    required this.onBackToShop,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text(
          'Order Ticket',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            // Success Header Icon & Title
            Center(
              child: Column(
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: Colors.green.shade300, width: 2),
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      size: 48,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Order Reserved Successfully!',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: GdcColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Order reserved. Show this QR code at the store counter upon pickup.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: GdcColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Main Ticket Card with QR Code and Order ID
            Card(
              elevation: 3,
              shadowColor: Colors.black12,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
                side: BorderSide(
                    color: GdcColors.terracotta.withValues(alpha: 0.2)),
              ),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    // Order ID Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: GdcColors.cream,
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(
                            color: GdcColors.terracotta.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.qr_code_2_rounded,
                              size: 18, color: GdcColors.terracotta),
                          const SizedBox(width: 8),
                          Text(
                            'ORDER ID: ${order.orderId}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              letterSpacing: 1.2,
                              color: GdcColors.warmBrown,
                            ),
                          ),
                          const SizedBox(width: 6),
                          InkWell(
                            onTap: () {
                              Clipboard.setData(
                                  ClipboardData(text: order.orderId));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Order ID copied to clipboard'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            child: const Icon(Icons.copy_rounded,
                                size: 16, color: GdcColors.terracotta),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Dynamic QR Code Display
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: Colors.grey.shade200, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: SizedBox(
                        width: 200,
                        height: 200,
                        child: QrImageView(
                          data: order.orderId.trim().isNotEmpty
                              ? order.orderId
                              : order.id,
                          version: QrVersions.auto,
                          size: 200.0,
                          backgroundColor: Colors.white,
                          eyeStyle: const QrEyeStyle(
                            eyeShape: QrEyeShape.square,
                            color: Colors.black,
                          ),
                          dataModuleStyle: const QrDataModuleStyle(
                            dataModuleShape: QrDataModuleShape.square,
                            color: Colors.black,
                          ),
                          errorStateBuilder: (c, err) => Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.qr_code_2_rounded,
                                  size: 80, color: GdcColors.forest),
                              const SizedBox(height: 8),
                              Text(order.orderId,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18)),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),
                    const Text(
                      'Scan QR code at store counter',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: GdcColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // STRICT CASH ONLY WARNING BANNER
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0), // Warm warning light orange
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFFB74D), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF57C00),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.payments_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CASH ONLY PAYMENT REQUIRED',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFE65100),
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              'Digital payments / online transfers are not accepted.',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFBF360C),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(color: Color(0xFFFFCC80), height: 1),
                  ),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF4E2700),
                        height: 1.4,
                      ),
                      children: [
                        const TextSpan(text: 'Please prepare exactly '),
                        TextSpan(
                          text: formatPeso(order.total),
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFD84315),
                            fontSize: 15,
                          ),
                        ),
                        const TextSpan(
                          text:
                              ' in cash to pay store personnel upon order pickup.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Pickup Details Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pickup Summary',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: GdcColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _DetailRow(
                      icon: Icons.location_on_rounded,
                      label: 'Location',
                      value: order.location.isNotEmpty
                          ? order.location
                          : 'GDC Main Store',
                    ),
                    const SizedBox(height: 8),
                    _DetailRow(
                      icon: Icons.schedule_rounded,
                      label: 'Pickup Window',
                      value: order.pickupTime.isNotEmpty
                          ? order.pickupTime
                          : 'Standard Store Hours',
                    ),
                    const SizedBox(height: 8),
                    _DetailRow(
                      icon: Icons.shopping_bag_rounded,
                      label: 'Total Items',
                      value:
                          '${order.items.fold(0, (acc, item) => acc + item.qty)} items',
                    ),
                    const SizedBox(height: 8),
                    const _DetailRow(
                      icon: Icons.account_balance_wallet_rounded,
                      label: 'Payment Method',
                      value: 'Cash Only (On Pickup)',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 28),

            // Action Buttons
            if (order.isExtended) ...[
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                decoration: BoxDecoration(
                  color: GdcColors.cream,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                      color: GdcColors.forest.withValues(alpha: 0.3),
                      width: 1.2),
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
              const SizedBox(height: 12),
            ] else if (OrderProvider.getAvailableExtensionMinutes(
                    order.expiresAt,
                    isExtended: order.isExtended) >
                0) ...[
              OutlinedButton.icon(
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
                icon: const Icon(Icons.timer_outlined, size: 18),
                label: Text(
                  'EXTEND PICKUP (+ ${OrderProvider.getAvailableExtensionMinutes(order.expiresAt, isExtended: order.isExtended)} MIN)',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w900),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: GdcColors.orangeCTA,
                  side:
                      const BorderSide(color: GdcColors.orangeCTA, width: 1.5),
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100)),
                ),
              ),
              const SizedBox(height: 12),
            ],

            ElevatedButton.icon(
              onPressed: onTrackOrder,
              icon: const Icon(Icons.delivery_dining_rounded),
              label: const Text('TRACK ORDER STATUS'),
              style: ElevatedButton.styleFrom(
                backgroundColor: GdcColors.orangeCTA,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100)),
                textStyle:
                    const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
              ),
            ),

            const SizedBox(height: 12),

            OutlinedButton(
              onPressed: onBackToShop,
              style: OutlinedButton.styleFrom(
                foregroundColor: GdcColors.terracotta,
                side: const BorderSide(color: GdcColors.terracotta, width: 1.5),
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100)),
              ),
              child: const Text(
                'RETURN TO SHOP',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ),

            const SizedBox(height: 12),

            TextButton.icon(
              onPressed: () => StoreLauncher.showSocialMedia(context),
              icon: const Icon(Icons.chat_rounded, size: 18, color: Color(0xFF1877F2)),
              label: const Text(
                'STORE SOCIAL MEDIA & CHAT',
                style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: Color(0xFF1877F2)),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: GdcColors.terracotta),
        const SizedBox(width: 10),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 13,
            color: GdcColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 13,
              color: GdcColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
