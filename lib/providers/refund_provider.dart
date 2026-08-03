import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../models/refund_request.dart';

class RefundProvider extends ChangeNotifier {
  final _db = FirebaseFirestore.instance;

  // Stream for the customer to see THEIR refunds only
  Stream<List<RefundRequest>> myRefundsStream(String email) {
    return _db.collection('refund_requests')
        .where('customerEmail', isEqualTo: email)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(RefundRequest.fromFirestore).toList());
  }

  // Method to submit a new request
  Future<void> requestRefund(RefundRequest request) async {
    await _db.collection('refund_requests').add(request.toFirestore());
    
    // Subscribe to notifications for this specific customer email topic
    if (request.customerEmail.isNotEmpty) {
      String topic = 'user_${request.customerEmail.replaceAll('@', '_')}';
      try {
        await FirebaseMessaging.instance.subscribeToTopic(topic);
      } catch (e) {
        debugPrint('Error subscribing to topic: $e');
      }
    }
  }
}
