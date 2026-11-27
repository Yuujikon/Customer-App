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
    final notifications = provider?.notifications ?? const <AppNotification>[];

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 460),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).dividerColor, width: 1),
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
                  children: [
                    const Text(
                      'UPDATES',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: AppColors.sage,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Notifications',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onSurface,
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
                          'Mark All As Read',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.forest,
                          ),
                        ),
                      ),
                    IconButton(
                      icon: Icon(Icons.close_rounded,
                          size: 20,
                          color: Theme.of(context).textTheme.bodySmall?.color),
                      onPressed: onClose,
                      tooltip: 'Close notifications',
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Theme.of(context).dividerColor),

          // List or Empty State
          if (notifications.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.notifications_none_rounded,
                      size: 36,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No notifications yet',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Order and stock updates will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: notifications.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: Theme.of(context).dividerColor),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unreadBg = isDark
        ? AppColors.forest.withValues(alpha: 0.18)
        : AppColors.sageTint.withValues(alpha: 0.35);
    final readIconBg = isDark
        ? Theme.of(context).colorScheme.surfaceContainerLow
        : AppColors.warmSurface;
    final unreadIconBg =
        isDark ? AppColors.forest.withValues(alpha: 0.28) : AppColors.sageTint;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        color: notification.isRead ? Colors.transparent : unreadBg,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: notification.isRead ? readIconBg : unreadIconBg,
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
                            color: Theme.of(context).colorScheme.onSurface,
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
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).textTheme.bodySmall?.color,
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
