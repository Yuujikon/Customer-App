import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/notification_provider.dart';
import '../models/app_notification.dart';

class NotificationHistoryScreen extends StatelessWidget {
  const NotificationHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider?>();
    final notifications = provider?.notifications ?? [];

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (notifications.any((n) => !n.isRead))
            TextButton(
              onPressed: () => provider?.markAllAsRead(),
              child: const Text('Mark all as read'),
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: notifications.isEmpty
          ? _buildEmptyState(context)
          : RefreshIndicator(
              onRefresh: () async => await Future.delayed(const Duration(milliseconds: 500)),
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: notifications.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final n = notifications[i];
                  return _NotificationTile(notification: n);
                },
              ),
            ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.notifications_none_rounded, size: 64, color: GdcColors.terracotta.withValues(alpha: 0.1)),
          const SizedBox(height: 20),
          const Text('No notifications yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: GdcColors.textPrimary)),
          const SizedBox(height: 6),
          const Text('We\'ll let you know when something happens!', style: TextStyle(fontSize: 13, color: GdcColors.textMuted)),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  const _NotificationTile({required this.notification});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<NotificationProvider>();
    
    return InkWell(
      onTap: () {
        if (!notification.isRead) provider.markAsRead(notification.id);
        // Handle navigation to order/product if relatedId exists
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: notification.isRead ? Colors.white : GdcColors.terracotta.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: notification.isRead ? Colors.black12 : GdcColors.terracotta.withValues(alpha: 0.1)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildIcon(),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _getTypeLabel(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: _getTypeColor(),
                            letterSpacing: 0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('MMM d, h:mm a').format(notification.timestamp),
                        style: const TextStyle(fontSize: 10, color: GdcColors.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: notification.isRead ? FontWeight.w700 : FontWeight.w900,
                      color: GdcColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notification.body,
                    style: const TextStyle(fontSize: 13, color: GdcColors.textSecondary, height: 1.3),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    IconData icon;
    Color color;

    switch (notification.type) {
      case NotificationType.order:
        icon = Icons.shopping_bag_outlined;
        color = Colors.blue;
        break;
      case NotificationType.stock:
        icon = Icons.inventory_2_outlined;
        color = Colors.orange;
        break;
      case NotificationType.store:
      default:
        icon = Icons.storefront_outlined;
        color = GdcColors.terracotta;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }

  String _getTypeLabel() {
    switch (notification.type) {
      case NotificationType.order: return 'ORDER UPDATE';
      case NotificationType.stock: return 'STOCK ALERT';
      case NotificationType.store: return 'STORE NEWS';
    }
  }

  Color _getTypeColor() {
    switch (notification.type) {
      case NotificationType.order: return Colors.blue;
      case NotificationType.stock: return Colors.orange;
      case NotificationType.store: return GdcColors.terracotta;
    }
  }
}
