import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/inventory_provider.dart';
import 'providers/order_provider.dart';
import 'providers/refund_provider.dart';
import 'screens/landing_screen.dart';
import 'screens/customer_app.dart';
import 'services/notification_service.dart';

@pragma('vm:entry-point')
Future<void> _bgHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
}

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    FirebaseMessaging.onBackgroundMessage(_bgHandler);
    
    // Initialize notifications without blocking app startup indefinitely
    NotificationService.initialize().catchError((e) => print("Notification init error: $e"));
    
    runApp(const GdcCustomerApp());
  } catch (e) {
    print("Fatal startup error: $e");
    // Still try to run the app, or show a crash screen
    runApp(MaterialApp(home: Scaffold(body: Center(child: Text("Startup Error: $e")))));
  }
}

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
      ],
      child: MaterialApp(
        title:                    'GDC Store',
        debugShowCheckedModeBanner: false,
        theme:                    GdcTheme.light,
        // Use StreamBuilder to decide home screen based on auth state
        home:                     const _Root(),
      ),
    );
  }
}

/// Listens to Firebase Auth state — redirects automatically on login/logout
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
          // Already logged in — go straight to the app
          return const CustomerApp();
        }
        return const LandingScreen();
      },
    );
  }
}