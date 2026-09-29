import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import 'active_orders_screen.dart';
import 'sales_history_screen.dart';
import 'refund_requests_screen.dart';

class MyOrdersScreen extends StatelessWidget {
  const MyOrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          title: const Text('Orders & History', style: TextStyle(fontWeight: FontWeight.w900)),
          centerTitle: false,
          backgroundColor: Colors.transparent,
          elevation: 0,
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: GdcColors.terracotta,
            unselectedLabelColor: Colors.grey,
            indicatorColor: GdcColors.terracotta,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: [
              Tab(text: 'ACTIVE ORDERS'),
              Tab(text: 'PAST PURCHASES'),
              Tab(text: 'REFUND CLAIMS'),
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
