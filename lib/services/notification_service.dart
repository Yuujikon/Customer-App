import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _local  = FlutterLocalNotificationsPlugin();
  static final _fcm    = FirebaseMessaging.instance;

  static const _ordersChannel = AndroidNotificationChannel(
    'gdc_orders', 'Order Updates',
    description: 'Order status and pickup reminders',
    importance: Importance.high,
  );

  static const _alertsChannel = AndroidNotificationChannel(
    'gdc_alerts', 'Store Alerts',
    description: 'Low stock and perishable warnings',
    importance: Importance.defaultImportance,
  );

  static Future<void> initialize() async {
    // Request permission (Android 13+, iOS)
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    // Set up local notifications (for foreground FCM messages)
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _local.initialize(const InitializationSettings(android: androidSettings));

    final androidImpl = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      await androidImpl.createNotificationChannel(_ordersChannel);
      await androidImpl.createNotificationChannel(_alertsChannel);
    }

    // Show notification when app is in foreground
    FirebaseMessaging.onMessage.listen((message) {
      final n = message.notification;
      if (n == null) return;
      _local.show(
        n.hashCode,
        n.title,
        n.body,
        NotificationDetails(android: AndroidNotificationDetails(
          'gdc_orders', 'Order Updates',
          importance: Importance.high, priority: Priority.high,
        )),
      );
    });

    // Get and print FCM token (send this to your server/Cloud Function)
    try {
      final token = await _fcm.getToken().timeout(const Duration(seconds: 10));
      print('FCM Token: $token');
    } catch (e) {
      print('Failed to get FCM token: $e');
    }
  }

  // Local notification — order ready
  static Future<void> sendOrderReady(String orderId) =>
      _local.show(
        orderId.hashCode,
        'Order Ready! 🛍️',
        'Order $orderId is packed and ready for pickup.',
        NotificationDetails(android: AndroidNotificationDetails(
          'gdc_orders', 'Order Updates',
          importance: Importance.high, priority: Priority.high,
        )),
      );

  // Schedule a local reminder for perishable orders
  static Future<void> schedulePerishableReminder(String id, String orderId) async {
    // Show a reminder notification now (true scheduling needs flutter_local_notifications zonedSchedule)
    await _local.show(
      (id + 'remind').hashCode,
      'Perishable Order Placed ⏰',
      'Order $orderId must be collected within 2 hours or it will be auto-cancelled.',
      NotificationDetails(android: AndroidNotificationDetails(
        'gdc_alerts', 'Store Alerts',
        importance: Importance.defaultImportance,
      )),
    );
  }

  // Notify Admin about a new refund request
  static Future<void> notifyAdminRefundRequest(String orderId, String customerName) async {
    // Admin is markjeo.hinampas@gmail.com
    // Topic is user_markjeo_hinampas_gmail_com
    const adminTopic = 'user_markjeo_hinampas_gmail_com';
    
    // In a real app, this would be triggered via a Cloud Function for security.
    // For this prototype, we show a local success notification.
    await _local.show(
      orderId.hashCode + 1,
      'Refund Requested 💸',
      'Your request for $orderId has been submitted to GDC Admin.',
      NotificationDetails(android: AndroidNotificationDetails(
        'gdc_orders', 'Order Updates',
        importance: Importance.high,
      )),
    );
  }
}