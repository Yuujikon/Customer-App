import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final _local = FlutterLocalNotificationsPlugin();
  static final _fcm = FirebaseMessaging.instance;

  static const _customerChannel = AndroidNotificationChannel(
    'gdc_customer_popups',
    'GDC Customer Updates',
    description: 'High-priority pop-up updates for GDC Customer App',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
  );

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();

    await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      criticalAlert: true,
    );

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await _local.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    final androidImpl = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidImpl != null) {
      await androidImpl.requestNotificationsPermission();
      await androidImpl.createNotificationChannel(_customerChannel);
    }

    FirebaseMessaging.onMessage.listen((msg) => handleMessage(msg));

    try {
      final token = await _fcm.getToken();
      print('FCM Token: $token');
    } catch (e) {
      print('Failed to get FCM token: $e');
    }

    _initialized = true;
  }

  static Future<void> initializeBackground() async {
    tz.initializeTimeZones();
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _local.initialize(const InitializationSettings(android: androidSettings));
  }

  static Future<void> subscribeToCustomerTopic(String email) async {
    final topic = 'customer_${email.replaceAll(RegExp(r'[@.]'), '_')}';
    await _fcm.subscribeToTopic(topic);
    print('Subscribed to topic: $topic');
  }

  static Future<void> unsubscribeFromCustomerTopic(String email) async {
    final topic = 'customer_${email.replaceAll(RegExp(r'[@.]'), '_')}';
    await _fcm.unsubscribeFromTopic(topic);
    print('Unsubscribed from topic: $topic');
  }

  static void handleMessage(RemoteMessage message, {bool showIfNotification = true}) {
    // Strict Recipient Filter: Customer app ONLY handles customer messages
    final String recipient = message.data['recipient'] ?? '';
    if (recipient == 'admin') return;

    String? title = message.notification?.title ?? message.data['title'];
    String? body  = message.notification?.body  ?? message.data['body'];

    if (title == null && body == null) return;

    showSmsNotificationPopUp(
      id: message.hashCode,
      title: title ?? 'GDC Store Update',
      body: body ?? '',
    );
  }

  static Future<void> showSmsNotificationPopUp({
    required String title,
    required String body,
    int? id,
  }) {
    final String formattedTitle = title.startsWith('🛍️ GDC Store') || title.startsWith('💸 GDC Store') || title.startsWith('❌ GDC Store')
        ? title 
        : '🛍️ GDC Store • $title';

    return _local.show(
      id ?? DateTime.now().millisecondsSinceEpoch.remainder(100000),
      formattedTitle,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'gdc_customer_popups',
          'GDC Customer Updates',
          channelDescription: 'High-priority pop-up updates for GDC Customer App',
          importance: Importance.max,
          priority: Priority.high,
          visibility: NotificationVisibility.public,
          fullScreenIntent: true,
          playSound: true,
          enableVibration: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  static Future<void> sendOrderReady(String orderId) => showSmsNotificationPopUp(
        id: orderId.hashCode,
        title: 'Order Ready for Pickup! 📦',
        body: 'Your order $orderId is packed and ready for pickup at GDC Store.',
      );

  static Future<void> schedulePerishableReminder(String id, String orderId,
      {int hours = 2}) async {
    if (!_initialized) await initialize();
    
    final scheduleTime = tz.TZDateTime.now(tz.local).add(Duration(hours: hours));

    // 1. Immediate heads-up pop-up
    await showSmsNotificationPopUp(
      id: (id + 'placed').hashCode,
      title: 'Pre-Order Received ✅',
      body: 'Order $orderId placed successfully. Please collect within $hours hours.',
    );

    // 2. Schedule reminder 30 mins before expiry
    if (hours > 0) {
      final reminderTime = scheduleTime.subtract(const Duration(minutes: 30));
      if (reminderTime.isAfter(tz.TZDateTime.now(tz.local))) {
        try {
          await _local.zonedSchedule(
            (id + 'remind').hashCode,
            'Pickup Reminder ⏰',
            'Your order $orderId will expire in 30 minutes. Please collect it soon!',
            reminderTime,
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'gdc_customer_popups',
                'GDC Customer Updates',
                importance: Importance.max,
                priority: Priority.high,
                visibility: NotificationVisibility.public,
                fullScreenIntent: true,
                playSound: true,
                enableVibration: true,
              ),
            ),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          );
        } catch (e) {
          print('Exact alarm scheduling failed or exact alarm permission not granted: $e');
        }
      }
    }
  }

  static Future<void> notifyAdminRefundRequest(
      String orderId, String customerName) async {
    await showSmsNotificationPopUp(
      id: orderId.hashCode + 1,
      title: 'Refund Request Submitted 💸',
      body: 'Your refund request for $orderId has been submitted to GDC Admin.',
    );
  }
}
