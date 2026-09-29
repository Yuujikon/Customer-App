import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/material.dart';
import '../../../shared/services/notification_service.dart';
import 'dart:io';
import 'dart:convert';

class AppAuthProvider extends ChangeNotifier {
  final _auth    = FirebaseAuth.instance;
  final _db      = FirebaseFirestore.instance;
  final _googleSignIn = GoogleSignIn();

  String    _bio = '';
  String?   _phoneNumber; 
  String?   _base64Photo; 
  List<String> _favorites = [];

  User? get currentUser  => _auth.currentUser;
  String get displayName => currentUser?.displayName ?? 'Customer';
  String get email       => currentUser?.email ?? '';
  String? get photoUrl   => _base64Photo; 
  String get bio         => _bio;
  String? get phoneNumber => _phoneNumber;
  List<String> get favorites => _favorites;

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
        _bio = d['bio'] ?? '';
        _phoneNumber = d['phoneNumber'];
        _base64Photo = d['photoBase64']; 
        _favorites = List<String>.from(d['favorites'] ?? []);
        notifyListeners();
      }
    });
  }

  Future<void> toggleFavorite(String productId) async {
    final uid = currentUser?.uid;
    if (uid == null) return;

    if (_favorites.contains(productId)) {
      _favorites.remove(productId);
    } else {
      _favorites.add(productId);
    }

    await _db.collection('users').doc(uid).update({'favorites': _favorites});
    notifyListeners();
  }

  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
    await _saveFcmToken();
  }

  /// Returns true if the user is logged in but missing a phone number.
  Future<bool> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return false;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      bool phoneMissing = false;
      if (user != null) {
        final doc = await _db.collection('users').doc(user.uid).get();
        if (!doc.exists) {
          await _db.collection('users').doc(user.uid).set({
            'email': user.email,
            'displayName': user.displayName,
            'createdAt': FieldValue.serverTimestamp(),
          });
          phoneMissing = true;
        } else {
          final data = doc.data() ?? {};
          phoneMissing = data['phoneNumber'] == null || data['phoneNumber'].toString().isEmpty;
        }
      }

      await _saveFcmToken();
      return phoneMissing;
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      rethrow;
    }
  }

  Future<void> signUp(String email, String password, String name, {String? phone}) async {
    final cred = await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
    await cred.user?.updateDisplayName(name);
    
    // Save phone number immediately
    if (phone != null) {
      await _db.collection('users').doc(cred.user!.uid).set({
        'phoneNumber': phone,
      }, SetOptions(merge: true));
    }

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
      await NotificationService.subscribeToCustomerTopic(user!.email!);
    }
  }

  Future<void> updateProfile({String? name, String? bio, String? phone}) async {
    final user = currentUser;
    if (user == null) return;

    if (name != null) await user.updateDisplayName(name);
    
    await _db.collection('users').doc(user.uid).set({
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

    // Save directly to Firestore document
    await _db.collection('users').doc(user.uid).set({
      'photoBase64': base64String,
    }, SetOptions(merge: true));
    
    notifyListeners();
  }

  Future<void> signOut() async {
    final user = _auth.currentUser;
    if (user?.email != null) {
      await NotificationService.unsubscribeFromCustomerTopic(user!.email!);
    }
    await _auth.signOut();
    notifyListeners();
  }
}
