import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'customer/shop_screen.dart';
import 'customer/pre_order_screen.dart';
import 'customer/my_orders_screen.dart';
import 'customer/account_screen.dart';

class CustomerApp extends StatefulWidget {
  const CustomerApp({super.key});
  @override State<CustomerApp> createState() => _CustomerAppState();
}

class _CustomerAppState extends State<CustomerApp> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          ShopScreen(onViewCart: () => setState(() => _tab = 1)),
          PreOrderScreen(
            onSubmitted: () => setState(() => _tab = 2),
            onBrowseMore: () => setState(() => _tab = 0),
          ),
          const MyOrdersScreen(),
          AccountScreen(onLogout: () {
            // Firebase Auth state change in main.dart navigates back to LandingScreen
            context.read<AppAuthProvider>().signOut();
          }),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.store_outlined),         label: 'Shop'),
          NavigationDestination(icon: Icon(Icons.shopping_cart_outlined), label: 'Pre-Order'),
          NavigationDestination(icon: Icon(Icons.receipt_outlined),       label: 'My Orders'),
          NavigationDestination(icon: Icon(Icons.person_outline),         label: 'Account'),
        ],
      ),
    );
  }
}