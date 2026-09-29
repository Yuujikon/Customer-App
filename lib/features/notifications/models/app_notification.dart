import 'package:cloud_firestore/cloud_firestore.dart';

enum NotificationType { order, stock, store }

class AppNotification {
  final String id;
  final String title;
  final String body;
  final DateTime timestamp;
  final NotificationType type;
  final bool isRead;
  final String? relatedId; // e.g., orderId or productId

  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    required this.type,
    this.isRead = false,
    this.relatedId,
  });

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    return AppNotification(
      id: doc.id,
      title: d['title'] ?? '',
      body: d['body'] ?? '',
      timestamp: (d['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      type: NotificationType.values.firstWhere(
        (e) => e.name == (d['type'] ?? 'store'),
        orElse: () => NotificationType.store,
      ),
      isRead: d['isRead'] ?? false,
      relatedId: d['relatedId'],
    );
  }

  Map<String, dynamic> toFirestore() => {
    'title': title,
    'body': body,
    'timestamp': Timestamp.fromDate(timestamp),
    'type': type.name,
    'isRead': isRead,
    'relatedId': relatedId,
  };

  AppNotification copyWith({bool? isRead}) => AppNotification(
    id: id, title: title, body: body, timestamp: timestamp,
    type: type, relatedId: relatedId, isRead: isRead ?? this.isRead,
  );
}
