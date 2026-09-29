import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/providers/auth_provider.dart';
import 'features/auth/screens/landing_screen.dart';
import 'features/home/customer_app.dart';
import 'features/orders/providers/order_provider.dart';
import 'features/orders/providers/refund_provider.dart';
import 'features/shop/providers/inventory_provider.dart';

import 'features/notifications/providers/notification_provider.dart';

class GdcCustomerApp extends StatelessWidget {
  const GdcCustomerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppAuthProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => InventoryProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => OrderProvider()..initialize()),
        ChangeNotifierProvider(create: (_) => RefundProvider()),
        ChangeNotifierProxyProvider<AppAuthProvider, NotificationProvider?>(
          create: (_) => null,
          update: (_, auth, prev) {
            final uid = auth.currentUser?.uid;
            if (uid == null) return null;
            if (prev?.userId == uid) return prev;
            return NotificationProvider(uid);
          },
        ),
      ],
      child: MaterialApp(
        title:                    'GDC Store',
        debugShowCheckedModeBanner: false,
        theme:                    GdcTheme.light,
        home:                     const _Root(),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasData) {
          return const CustomerApp();
        }
        return const LandingScreen();
      },
    );
  }
}
