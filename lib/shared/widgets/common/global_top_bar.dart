import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import 'brand_logo.dart';

class StoreStatusPill extends StatelessWidget {
  final bool isOpen;

  const StoreStatusPill({super.key, this.isOpen = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.sageTint,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isOpen ? AppColors.forest : AppColors.error,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isOpen ? 'STORE OPEN · PICKUP AVAILABLE' : 'STORE CLOSED',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: AppColors.forest,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class GlobalTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String userName;
  final String userInitials;
  final bool isStoreOpen;
  final int unreadNotifications;
  final VoidCallback onOpenNotifications;
  final VoidCallback? onSearchTap;
  final VoidCallback? onProfileTap;

  const GlobalTopBar({
    super.key,
    this.userName = 'Andrea',
    this.userInitials = 'AM',
    this.isStoreOpen = true,
    this.unreadNotifications = 2,
    required this.onOpenNotifications,
    this.onSearchTap,
    this.onProfileTap,
  });

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    final double topPadding = MediaQuery.paddingOf(context).top;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isTablet = constraints.maxWidth >= 600;

        return Container(
          height: preferredSize.height + topPadding,
          padding: EdgeInsets.only(
            top: topPadding,
            left: 20,
            right: 20,
          ),
          decoration: const BoxDecoration(
            color: AppColors.warmSurface,
            border: Border(
              bottom: BorderSide(color: AppColors.border, width: 1),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (!isTablet) ...[
                // Phone Mode Header
                const GdcLogo(
                  size: 38,
                  isExpanded: true,
                  showSubtitle: true,
                ),
                const Spacer(),
                _NotificationBellButton(
                  unreadCount: unreadNotifications,
                  onTap: onOpenNotifications,
                ),
              ] else ...[
                // Tablet Mode Header
                Flexible(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Good morning, $userName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryText,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      StoreStatusPill(isOpen: isStoreOpen),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                const Spacer(),

                // Search button
                if (onSearchTap != null)
                  IconButton(
                    onPressed: onSearchTap,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.all(10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                        side: const BorderSide(color: AppColors.border),
                      ),
                    ),
                    icon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.primaryText,
                      size: 20,
                    ),
                    tooltip: 'Search catalog',
                  ),

                const SizedBox(width: 10),

                // Notification Bell
                _NotificationBellButton(
                  unreadCount: unreadNotifications,
                  onTap: onOpenNotifications,
                ),

                const SizedBox(width: 12),

                // User Avatar & Name
                InkWell(
                  onTap: onProfileTap,
                  borderRadius: BorderRadius.circular(100),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.forest,
                          child: Text(
                            userInitials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              userName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryText,
                              ),
                            ),
                            const Text(
                              'Member',
                              style: TextStyle(
                                fontSize: 10,
                                color: AppColors.mutedText,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: AppColors.mutedText,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _NotificationBellButton extends StatelessWidget {
  final int unreadCount;
  final VoidCallback onTap;

  const _NotificationBellButton({
    required this.unreadCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white,
        padding: const EdgeInsets.all(10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      icon: Badge(
        label: Text('$unreadCount'),
        isLabelVisible: unreadCount > 0,
        backgroundColor: AppColors.orangeCTA,
        child: const Icon(
          Icons.notifications_outlined,
          color: AppColors.primaryText,
          size: 20,
        ),
      ),
      tooltip: 'Notifications',
    );
  }
}
