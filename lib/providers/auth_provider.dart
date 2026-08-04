import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';

class AppAuthProvider extends ChangeNotifier {
  final _auth    = FirebaseAuth.instance;
  final _db      = FirebaseFirestore.instance;

  String?   _gender;
  String    _bio = '';
  String?   _phoneNumber; // Added phone number
  String?   _base64Photo; 
  int       _loyaltyPoints = 0;

  User? get currentUser  => _auth.currentUser;
  String get displayName => currentUser?.displayName ?? 'Customer';
  String get email       => currentUser?.email ?? '';
  String? get photoUrl   => _base64Photo; 
  String? get gender     => _gender;
  String get bio         => _bio;
  String? get phoneNumber => _phoneNumber;
  int get loyaltyPoints  => _loyaltyPoints;

  bool get initialized => _auth.currentUser != null;

  void initialize() {
    if (currentUser != null) {
      _saveFcmToken();
      _listenToProfile();
    }
    _auth.authStateChanges().listen((user) {
      if (user != null) {
        _listenToProfile();
      } else {
        _gender = null;
        _bio = '';
        _phoneNumber = null;
        _base64Photo = null;
      }
      notifyListeners();
    });
  }

  void _listenToProfile() {
    final uid = currentUser?.uid;
    if (uid == null) return;
    _db.collection('users').doc(uid).snapshots().listen((snap) {
      if (snap.exists) {
        final d = snap.data() ?? {};
        _gender = d['gender'];
        _bio = d['bio'] ?? '';
        _phoneNumber = d['phoneNumber']; // Read phone from Firestore
        _base64Photo = d['photoBase64']; 
        _loyaltyPoints = d['loyaltyPoints'] ?? 0;
        notifyListeners();
      }
    });
  }

  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
    await _saveFcmToken();
  }

  Future<void> signUp(String email, String password, String name) async {
    final cred = await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
    await cred.user?.updateDisplayName(name);
    await _saveFcmToken();
  }

  // Save FCM token and subscribe to user-specific topic
  Future<void> _saveFcmToken() async {
    final user = _auth.currentUser;
    final uid = user?.uid;
    final token = await FirebaseMessaging.instance.getToken();
    
    if (uid != null && token != null) {
      await _db.collection('users').doc(uid).set({
        'email': user?.email,
        'fcmToken': token,
      }, SetOptions(merge: true));
    }

    if (user?.email != null) {
      // Create a safe topic name (alphanumeric, underscores, hyphens only)
      final topic = 'user_${user!.email!.replaceAll('@', '_').replaceAll('.', '_')}';
      await FirebaseMessaging.instance.subscribeToTopic(topic);
      debugPrint('Subscribed to topic: $topic');
    }
  }

  Future<void> updateProfile({String? name, String? gender, String? bio, String? phone}) async {
    final user = currentUser;
    if (user == null) return;

    if (name != null) await user.updateDisplayName(name);
    
    await _db.collection('users').doc(user.uid).set({
      if (gender != null) 'gender': gender,
      if (bio != null) 'bio': bio,
      if (phone != null) 'phoneNumber': phone,
    }, SetOptions(merge: true));
    
    notifyListeners();
  }

  Future<void> uploadProfilePicture(File file) async {
    final user = currentUser;
    if (user == null) return;

    // Convert file to base64 string
    final bytes = await file.readAsBytes();
    final base64String = base64Encode(bytes);

    // Save directly to Firestore document (1MB limit is plenty for compressed profile pics)
    await _db.collection('users').doc(user.uid).set({
      'photoBase64': base64String,
    }, SetOptions(merge: true));
    
    notifyListeners();
  }

  Future<void> signOut() async {
    final user = _auth.currentUser;
    if (user?.email != null) {
      final topic = 'user_${user!.email!.replaceAll('@', '_').replaceAll('.', '_')}';
      await FirebaseMessaging.instance.unsubscribeFromTopic(topic);
      debugPrint('Unsubscribed from topic: $topic');
    }
    await _auth.signOut();
    notifyListeners();
  }
}
