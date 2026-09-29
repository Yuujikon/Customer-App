import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';
import 'firebase_options.dart';
import 'shared/services/notification_service.dart';

@pragma('vm:entry-point')
Future<void> _bgHandler(RemoteMessage message) async {
  final String recipient = message.data['recipient'] ?? '';
  if (recipient == 'admin') return;

  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.initializeBackground();
  
  final String title = message.notification?.title ?? message.data['title'] ?? 'Update';
  final String body = message.notification?.body ?? message.data['body'] ?? 'You have a new update.';
  
  await NotificationService.showSmsNotificationPopUp(
    title: title,
    body: body,
  );
}

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        systemNavigationBarColor: Colors.transparent,
        statusBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    FirebaseMessaging.onBackgroundMessage(_bgHandler);
    
    // Initialize notifications (permissions, channels, timezone)
    await NotificationService.initialize();
    
    runApp(const GdcCustomerApp());
  } catch (e) {
    debugPrint("Fatal startup error: $e");
    runApp(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Text("Startup Error: $e", textAlign: TextAlign.center),
          ),
        ),
      ),
    ));
  }
}
