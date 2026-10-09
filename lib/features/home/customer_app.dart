import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/common/brand_logo.dart';
import '../../../shared/widgets/common/global_top_bar.dart';
import '../account/screens/account_screen.dart';
import '../auth/providers/auth_provider.dart';
import '../notifications/providers/notification_provider.dart';
import '../notifications/widgets/notification_panel.dart';
import '../orders/providers/order_provider.dart';
import '../orders/screens/my_orders_screen.dart';
import '../orders/screens/pre_order_screen.dart';
import '../shop/screens/shop_screen.dart';
import 'screens/customer_dashboard_screen.dart';

class CustomerApp extends StatefulWidget {
  const CustomerApp({super.key});

  @override
  State<CustomerApp> createState() => _CustomerAppState();
}

class _CustomerAppState extends State<CustomerApp> {
  int _tab = 0;
  bool _showNotifications = false;

  void _navigateToTab(int tabIndex) {
    setState(() {
      _tab = tabIndex;
      _showNotifications = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AppAuthProvider>();
    final notificationProvider = context.watch<NotificationProvider?>();
    final unreadCount = notificationProvider?.unreadCount ?? 2;

    final List<Widget> screens = [
      CustomerDashboardScreen(
        onBrowseCatalog: () => _navigateToTab(1),
        onViewCart: () => _navigateToTab(2),
        onViewOrders: () => _navigateToTab(3),
      ),
      ShopScreen(onViewCart: () => _navigateToTab(2)),
      PreOrderScreen(
        onSubmitted: () => _navigateToTab(3),
        onBrowseMore: () => _navigateToTab(1),
        onGoToAccount: () => _navigateToTab(4),
      ),
      const MyOrdersScreen(),
      AccountScreen(onLogout: () {
        _navigateToTab(0);
      }),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool isMobile = constraints.maxWidth < 600;
          final bool isLargeTablet = constraints.maxWidth >= 1024;

          if (isMobile) {
            // PHONE SHELL
            return Scaffold(
              backgroundColor: AppColors.cream,
              body: Stack(
                children: [
                  Column(
                    children: [
                      // Top Bar
                      GlobalTopBar(
                        userName: auth.displayName.split(' ').first,
                        unreadNotifications: unreadCount,
                        onOpenNotifications: () {
                          setState(
                              () => _showNotifications = !_showNotifications);
                        },
                      ),
                      // Main Content Area
                      Expanded(
                        child: IndexedStack(
                          index: _tab,
                          children: screens,
                        ),
                      ),
                    ],
                  ),

                  // Floating Notification Panel Overlay for Phone
                  if (_showNotifications)
                    Positioned(
                      top: 76,
                      left: 12,
                      right: 12,
                      child: SafeArea(
                        child: NotificationPanel(
                          onClose: () =>
                              setState(() => _showNotifications = false),
                          onNavigateToTab: _navigateToTab,
                        ),
                      ),
                    ),
                ],
              ),
              bottomNavigationBar: NavigationBar(
                selectedIndex: _tab,
                onDestinationSelected: (i) {
                  setState(() {
                    _tab = i;
                    _showNotifications = false;
                  });
                },
                backgroundColor: Colors.white,
                indicatorColor: AppColors.sageTint,
                elevation: 8,
                shadowColor: Colors.black.withValues(alpha: 0.08),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home_outlined),
                    selectedIcon:
                        Icon(Icons.home_rounded, color: AppColors.forest),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.storefront_outlined),
                    selectedIcon:
                        Icon(Icons.storefront_rounded, color: AppColors.forest),
                    label: 'Catalog',
                  ),
                  NavigationDestination(
                    icon: _CartBadgeIcon(isSelected: false),
                    selectedIcon: _CartBadgeIcon(isSelected: true),
                    label: 'Basket',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.receipt_long_outlined),
                    selectedIcon: Icon(Icons.receipt_long_rounded,
                        color: AppColors.forest),
                    label: 'Orders',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.person_outline_rounded),
                    selectedIcon:
                        Icon(Icons.person_rounded, color: AppColors.forest),
                    label: 'Account',
                  ),
                ],
              ),
            );
          }

          // TABLET SHELL (Medium: 600-1023, Large: >=1024)
          final double sidebarWidth = isLargeTablet ? 210 : 86;

          return Scaffold(
            backgroundColor: AppColors.cream,
            body: Stack(
              children: [
                Row(
                  children: [
                    // Tablet Navigation Sidebar / Rail
                    Container(
                      width: sidebarWidth,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          right: BorderSide(color: AppColors.border, width: 1),
                        ),
                      ),
                      child: Column(
                        children: [
                          const SizedBox(height: 18),
                          // Top GDC Logo Tile
                          const GdcLogo(size: 42),
                          const SizedBox(height: 28),

                          // Destinations
                          Expanded(
                            child: Column(
                              children: [
                                _SidebarDestinationTile(
                                  icon: Icons.home_outlined,
                                  selectedIcon: Icons.home_rounded,
                                  label: 'Home',
                                  isSelected: _tab == 0,
                                  isExpanded: isLargeTablet,
                                  onTap: () => _navigateToTab(0),
                                ),
                                _SidebarDestinationTile(
                                  icon: Icons.storefront_outlined,
                                  selectedIcon: Icons.storefront_rounded,
                                  label: 'Catalog',
                                  isSelected: _tab == 1,
                                  isExpanded: isLargeTablet,
                                  onTap: () => _navigateToTab(1),
                                ),
                                _SidebarDestinationTile(
                                  iconWidget:
                                      const _CartBadgeIcon(isSelected: false),
                                  selectedIconWidget:
                                      const _CartBadgeIcon(isSelected: true),
                                  label: 'Basket',
                                  isSelected: _tab == 2,
                                  isExpanded: isLargeTablet,
                                  onTap: () => _navigateToTab(2),
                                ),
                                _SidebarDestinationTile(
                                  icon: Icons.receipt_long_outlined,
                                  selectedIcon: Icons.receipt_long_rounded,
                                  label: 'Orders',
                                  isSelected: _tab == 3,
                                  isExpanded: isLargeTablet,
                                  onTap: () => _navigateToTab(3),
                                ),
                                _SidebarDestinationTile(
                                  icon: Icons.person_outline_rounded,
                                  selectedIcon: Icons.person_rounded,
                                  label: 'Account',
                                  isSelected: _tab == 4,
                                  isExpanded: isLargeTablet,
                                  onTap: () => _navigateToTab(4),
                                ),
                              ],
                            ),
                          ),

                          // Bottom Pickup Store Pin Icon Control
                          Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: const BoxDecoration(
                                color: AppColors.sageTint,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.location_on_rounded,
                                color: AppColors.forest,
                                size: 22,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Main Right Content
                    Expanded(
                      child: Column(
                        children: [
                          GlobalTopBar(
                            userName: auth.displayName.split(' ').first,
                            unreadNotifications: unreadCount,
                            onOpenNotifications: () {
                              setState(() =>
                                  _showNotifications = !_showNotifications);
                            },
                            onSearchTap: () => _navigateToTab(1),
                            onProfileTap: () => _navigateToTab(4),
                          ),
                          Expanded(
                            child: Center(
                              child: ConstrainedBox(
                                constraints:
                                    const BoxConstraints(maxWidth: 1200),
                                child: IndexedStack(
                                  index: _tab,
                                  children: screens,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Tablet Anchored Notification Panel Dropdown
                if (_showNotifications)
                  Positioned(
                    top: MediaQuery.paddingOf(context).top + 76,
                    right: 24,
                    width: 360,
                    child: NotificationPanel(
                      onClose: () => setState(() => _showNotifications = false),
                      onNavigateToTab: _navigateToTab,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SidebarDestinationTile extends StatelessWidget {
  final IconData? icon;
  final IconData? selectedIcon;
  final Widget? iconWidget;
  final Widget? selectedIconWidget;
  final String label;
  final bool isSelected;
  final bool isExpanded;
  final VoidCallback onTap;

  const _SidebarDestinationTile({
    this.icon,
    this.selectedIcon,
    this.iconWidget,
    this.selectedIconWidget,
    required this.label,
    required this.isSelected,
    required this.isExpanded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Widget displayIcon = isSelected
        ? (selectedIconWidget ??
            Icon(selectedIcon ?? icon, color: AppColors.forest, size: 24))
        : (iconWidget ?? Icon(icon, color: AppColors.mutedText, size: 24));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.sageTint : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: isExpanded
              ? Row(
                  children: [
                    const SizedBox(width: 8),
                    displayIcon,
                    const SizedBox(width: 12),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w800 : FontWeight.w600,
                        color:
                            isSelected ? AppColors.forest : AppColors.mutedText,
                      ),
                    ),
                  ],
                )
              : Center(child: displayIcon),
        ),
      ),
    );
  }
}

class _CartBadgeIcon extends StatelessWidget {
  final bool isSelected;

  const _CartBadgeIcon({required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return Consumer<OrderProvider>(
      builder: (context, order, _) {
        final count = order.preCart.fold(0, (sum, item) => sum + item.qty);
        return Badge(
          label: Text('$count'),
          isLabelVisible: count > 0,
          backgroundColor: AppColors.orangeCTA,
          child: Icon(
            isSelected
                ? Icons.shopping_bag_rounded
                : Icons.shopping_bag_outlined,
            color: isSelected ? AppColors.forest : AppColors.mutedText,
            size: 24,
          ),
        );
      },
    );
  }
}
