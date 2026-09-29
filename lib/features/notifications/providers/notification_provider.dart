import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/app_notification.dart';

class NotificationProvider extends ChangeNotifier {
  final String userId;
  List<AppNotification> _notifications = [];
  StreamSubscription? _sub;

  NotificationProvider(this.userId) {
    _init();
  }

  List<AppNotification> get notifications => _notifications;
  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  void _init() {
    _sub = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .limit(50)
        .snapshots()
        .listen((snap) {
      _notifications = snap.docs.map((doc) => AppNotification.fromFirestore(doc)).toList();
      notifyListeners();
    });
  }

  Future<void> markAsRead(String id) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(id)
        .update({'isRead': true});
  }

  Future<void> markAllAsRead() async {
    final batch = FirebaseFirestore.instance.batch();
    for (final n in _notifications.where((n) => !n.isRead)) {
      final doc = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(n.id);
      batch.update(doc, {'isRead': true});
    }
    await batch.commit();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
