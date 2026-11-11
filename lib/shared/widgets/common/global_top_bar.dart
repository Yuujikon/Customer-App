import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/theme_provider.dart';
import 'brand_logo.dart';

class StoreStatusPill extends StatelessWidget {
  final bool isOpen;

  const StoreStatusPill({super.key, this.isOpen = true});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color:
            isDark ? primaryColor.withValues(alpha: 0.2) : AppColors.sageTint,
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
              color: isOpen ? primaryColor : AppColors.error,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            isOpen ? 'Store Open · Pickup Available' : 'Store Closed',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: primaryColor,
              letterSpacing: 0.3,
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

  String _getGreeting() {
    final hour = DateTime.now().hour;
    final greeting = (hour >= 5 && hour < 12)
        ? 'Good morning'
        : (hour >= 12 && hour < 18)
            ? 'Good afternoon'
            : 'Good evening';
    return userName.trim().isNotEmpty ? '$greeting, $userName' : greeting;
  }

  @override
  Widget build(BuildContext context) {
    final double topPadding = MediaQuery.paddingOf(context).top;
    final themeProvider = context.watch<ThemeProvider>();
    final bool isDark = themeProvider.isDarkMode(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isTablet = constraints.maxWidth >= 600;

        return Container(
          width: double.infinity,
          height: preferredSize.height + topPadding,
          padding: EdgeInsets.only(
            top: topPadding,
            left: 12,
            right: isTablet ? 4 : 12,
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
                Flexible(
                  child: Text(
                    _getGreeting(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _TopBarIconButton(
                  icon: isDark
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                  onTap: () {
                    themeProvider.toggleTheme(!isDark);
                  },
                ),
                const SizedBox(width: 8),
                _TopBarIconButton(
                  icon: Icons.notifications_outlined,
                  badgeCount: unreadNotifications,
                  onTap: onOpenNotifications,
                ),
              ] else ...[
                // Tablet Mode Header
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _getGreeting(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Theme.of(context).colorScheme.onSurface,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    StoreStatusPill(isOpen: isStoreOpen),
                  ],
                ),
                const SizedBox(width: 16),
                const Spacer(),

                // Theme Toggle Button
                _TopBarIconButton(
                  icon: isDark
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                  onTap: () {
                    themeProvider.toggleTheme(!isDark);
                  },
                ),
                const SizedBox(width: 8),

                // Search Button
                if (onSearchTap != null) ...[
                  _TopBarIconButton(
                    icon: Icons.search_rounded,
                    onTap: onSearchTap!,
                  ),
                  const SizedBox(width: 8),
                ],

                // Notification Bell
                _TopBarIconButton(
                  icon: Icons.notifications_outlined,
                  badgeCount: unreadNotifications,
                  onTap: onOpenNotifications,
                ),

                const SizedBox(width: 8),

                // User Profile Pill (Far Right Corner Alignment)
                _ProfilePillButton(
                  userName: userName,
                  userInitials: userInitials,
                  onTap: onProfileTap,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Unified 40x40 Circular Top Bar Button for Pixel-Perfect Alignment
class _TopBarIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final int badgeCount;

  const _TopBarIconButton({
    required this.icon,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        shape: BoxShape.circle,
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: IconButton(
        icon: Badge(
          label: Text('$badgeCount', style: const TextStyle(fontSize: 9)),
          isLabelVisible: badgeCount > 0,
          backgroundColor: AppColors.orangeCTA,
          child: Icon(
            icon,
            color: Theme.of(context).colorScheme.onSurface,
            size: 20,
          ),
        ),
        onPressed: onTap,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        splashRadius: 20,
      ),
    );
  }
}

/// Unified 40px Profile Pill Button for Pixel-Perfect Alignment
class _ProfilePillButton extends StatelessWidget {
  final String userName;
  final String userInitials;
  final VoidCallback? onTap;

  const _ProfilePillButton({
    required this.userName,
    required this.userInitials,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: Theme.of(context).dividerColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.forest,
              child: Text(
                userInitials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 80),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    userName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    'Member',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 16,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ],
        ),
      ),
    );
  }
}
