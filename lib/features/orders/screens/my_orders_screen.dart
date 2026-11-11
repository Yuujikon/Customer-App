import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/order_provider.dart';
import 'active_orders_screen.dart';
import 'refund_requests_screen.dart';
import 'sales_history_screen.dart';

class MyOrdersScreen extends StatelessWidget {
  const MyOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AppAuthProvider>();
    final orderProvider = context.watch<OrderProvider>();

    if (auth.email.isNotEmpty) {
      orderProvider.ordersStreamForEmail(auth.email);
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
          elevation: 0,
          toolbarHeight: 70,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ORDER TRACKING',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: AppColors.sage,
                  letterSpacing: 1.2,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'My orders',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Theme.of(context).textTheme.bodySmall?.color,
            indicatorColor: Theme.of(context).colorScheme.primary,
            indicatorWeight: 3,
            labelStyle:
                const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
            unselectedLabelStyle:
                const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
            tabs: const [
              Tab(text: 'ACTIVE ORDERS'),
              Tab(text: 'ORDER HISTORY'),
              Tab(text: 'REFUNDS'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            ActiveOrdersScreen(),
            SalesHistoryScreen(),
            RefundRequestsScreen(),
          ],
        ),
      ),
    );
  }
}
