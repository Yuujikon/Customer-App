import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/responsive.dart';
import '../auth/providers/auth_provider.dart';
import '../shop/screens/shop_screen.dart';
import '../orders/screens/pre_order_screen.dart';
import '../orders/screens/my_orders_screen.dart';
import '../account/screens/account_screen.dart';
import '../orders/providers/order_provider.dart';
import '../../../core/theme/app_theme.dart';

class CustomerApp extends StatefulWidget {
  const CustomerApp({super.key});
  @override State<CustomerApp> createState() => _CustomerAppState();
}

class _CustomerAppState extends State<CustomerApp> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final bool isLargeScreen = Responsive.isLargeScreen(context);

    final List<Widget> screens = [
      ShopScreen(onViewCart: () => setState(() => _tab = 1)),
      PreOrderScreen(
        onSubmitted: () => setState(() => _tab = 2),
        onBrowseMore: () => setState(() => _tab = 0),
      ),
      const MyOrdersScreen(),
      AccountScreen(onLogout: () {
        context.read<AppAuthProvider>().signOut();
      }),
    ];

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        body: Row(
          children: [
            if (isLargeScreen)
              NavigationRail(
                selectedIndex: _tab,
                onDestinationSelected: (i) => setState(() => _tab = i),
                labelType: NavigationRailLabelType.all,
                backgroundColor: Colors.white,
                indicatorColor: GdcColors.peachLight,
                selectedIconTheme: const IconThemeData(color: GdcColors.terracotta, size: 28),
                unselectedIconTheme: const IconThemeData(color: GdcColors.textMuted, size: 24),
                selectedLabelTextStyle: const TextStyle(color: GdcColors.terracotta, fontWeight: FontWeight.bold, fontSize: 12),
                unselectedLabelTextStyle: const TextStyle(color: GdcColors.textMuted, fontWeight: FontWeight.w500, fontSize: 12),
                destinations: [
                  const NavigationRailDestination(
                    icon: Icon(Icons.storefront_rounded), 
                    selectedIcon: Icon(Icons.storefront_rounded),
                    label: Text('Shop')
                  ),
                  NavigationRailDestination(
                    icon: _CartBadge(tab: 1, currentTab: _tab, icon: Icons.shopping_bag_outlined),
                    selectedIcon: _CartBadge(tab: 1, currentTab: _tab, icon: Icons.shopping_bag_rounded),
                    label: const Text('Pre-Order'),
                  ),
                  const NavigationRailDestination(
                    icon: Icon(Icons.receipt_long_outlined), 
                    selectedIcon: Icon(Icons.receipt_long_rounded),
                    label: Text('Orders')
                  ),
                  const NavigationRailDestination(
                    icon: Icon(Icons.person_outline_rounded), 
                    selectedIcon: Icon(Icons.person_rounded),
                    label: Text('Account')
                  ),
                ],
              ),
            if (isLargeScreen) const VerticalDivider(thickness: 1, width: 1),
            Expanded(
              child: IndexedStack(
                index: _tab,
                children: screens,
              ),
            ),
          ],
        ),
        bottomNavigationBar: isLargeScreen 
          ? null 
          : NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: (i) => setState(() => _tab = i),
              destinations: [
                const NavigationDestination(
                  icon: Icon(Icons.storefront_outlined),
                  selectedIcon: Icon(Icons.storefront_rounded),
                  label: 'Shop'
                ),
                NavigationDestination(
                  icon: _CartBadge(tab: 1, currentTab: _tab, icon: Icons.shopping_bag_outlined),
                  selectedIcon: _CartBadge(tab: 1, currentTab: _tab, icon: Icons.shopping_bag_rounded),
                  label: 'Pre-Order',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long_rounded),
                  label: 'My Orders'
                ),
                const NavigationDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  selectedIcon: Icon(Icons.person_rounded),
                  label: 'Account'
                ),
              ],
            ),
      ),
    );
  }
}

class _CartBadge extends StatelessWidget {
  final int tab;
  final int currentTab;
  final IconData icon;
  
  const _CartBadge({required this.tab, required this.currentTab, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Consumer<OrderProvider>(
      builder: (context, order, _) {
        final count = order.preCart.fold(0, (sum, item) => sum + item.qty);
        return Badge(
          label: Text('$count'),
          isLabelVisible: count > 0,
          backgroundColor: GdcColors.terracotta,
          child: Icon(icon),
        );
      },
    );
  }
}
