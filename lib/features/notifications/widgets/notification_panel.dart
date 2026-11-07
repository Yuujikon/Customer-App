import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/notification_provider.dart';
import '../models/app_notification.dart';

class NotificationPanel extends StatelessWidget {
  final VoidCallback onClose;
  final Function(int tabIndex) onNavigateToTab;

  const NotificationPanel({
    super.key,
    required this.onClose,
    required this.onNavigateToTab,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider?>();
    final notifications = provider?.notifications ?? _sampleNotifications;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 460),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 12, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'UPDATES',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.sage,
                        letterSpacing: 0.8,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryText,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (notifications.any((n) => !n.isRead))
                      TextButton(
                        onPressed: () {
                          provider?.markAllAsRead();
                        },
                        child: const Text(
                          'Mark all as read',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.forest,
                          ),
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          size: 20, color: AppColors.mutedText),
                      onPressed: onClose,
                      tooltip: '',
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.border),

          // List
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: notifications.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: AppColors.border),
              itemBuilder: (context, i) {
                final n = notifications[i];
                return _NotificationRow(
                  notification: n,
                  onTap: () {
                    if (!n.isRead && provider != null) {
                      provider.markAsRead(n.id);
                    }
                    onClose();
                    if (n.title.contains('prepared') ||
                        n.title.contains('Pickup completed') ||
                        n.type == NotificationType.order) {
                      onNavigateToTab(3); // Orders tab
                    } else if (n.title.contains('produce') ||
                        n.type == NotificationType.stock) {
                      onNavigateToTab(1); // Catalog tab
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static final List<AppNotification> _sampleNotifications = [
    AppNotification(
      id: 'n1',
      title: 'Your order is being prepared',
      body: 'Order #GDC-2841 is now being packed for pickup.',
      timestamp: DateTime.now(),
      type: NotificationType.order,
      isRead: false,
      relatedId: 'GDC-2841',
    ),
    AppNotification(
      id: 'n2',
      title: 'Fresh produce just arrived',
      body: "Shop today's new farm-fresh picks before 4 PM.",
      timestamp: DateTime.now().subtract(const Duration(minutes: 24)),
      type: NotificationType.stock,
      isRead: false,
    ),
    AppNotification(
      id: 'n3',
      title: 'Pickup completed',
      body: 'Thanks for collecting order #GDC-2795.',
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
      type: NotificationType.order,
      isRead: true,
      relatedId: 'GDC-2795',
    ),
  ];
}

class _NotificationRow extends StatelessWidget {
  final AppNotification notification;
  final VoidCallback onTap;

  const _NotificationRow({
    required this.notification,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        color: notification.isRead
            ? AppColors.surface
            : AppColors.sageTint.withValues(alpha: 0.35),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: notification.isRead
                    ? AppColors.warmSurface
                    : AppColors.sageTint,
                shape: BoxShape.circle,
              ),
              child: Icon(
                notification.type == NotificationType.order
                    ? Icons.shopping_basket_outlined
                    : Icons.storefront_outlined,
                color: AppColors.forest,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: notification.isRead
                                ? FontWeight.w600
                                : FontWeight.w800,
                            color: AppColors.primaryText,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (!notification.isRead) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.orangeCTA,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notification.body,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.mutedText,
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
