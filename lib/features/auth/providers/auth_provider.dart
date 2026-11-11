import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/material.dart';
import '../../../shared/services/notification_service.dart';
import '../../../core/utils/name_validator.dart';
import 'dart:typed_data';
import 'dart:convert';

class AppAuthProvider extends ChangeNotifier {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;
  final _googleSignIn = GoogleSignIn();

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _profileSubscription;

  String _bio = '';
  String? _phoneNumber;
  String? _base64Photo;
  List<String> _favorites = [];
  bool _hasEnteredFullName = false;
  bool _requiresNameSetup = false;

  User? get currentUser => _auth.currentUser;
  bool get hasEnteredFullName => _hasEnteredFullName;
  bool get requiresNameSetup => _requiresNameSetup;

  /// Returns true if the user has explicitly entered/confirmed a valid real full name
  bool get isFullNameSet {
    if (!_hasEnteredFullName || _requiresNameSetup) return false;
    final name = (currentUser?.displayName ?? '').trim();
    if (name.isEmpty || name == 'Customer' || name == 'Guest') return false;
    return isValidRealName(name);
  }

  String get displayName {
    if (!_hasEnteredFullName || _requiresNameSetup) return 'Customer';
    final name = (currentUser?.displayName ?? '').trim();
    return (name.isNotEmpty && name != 'Customer' && isValidRealName(name))
        ? name
        : 'Customer';
  }

  String get email => currentUser?.email ?? '';
  String? get photoUrl => _base64Photo;
  String get bio => _bio;
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
        _profileSubscription?.cancel();
        _profileSubscription = null;
        _bio = '';
        _phoneNumber = null;
        _base64Photo = null;
        _favorites = [];
        _hasEnteredFullName = false;
        _requiresNameSetup = false;
      }
      notifyListeners();
    }, onError: (e) {
      debugPrint('Auth state listener error: $e');
    });
  }

  void _listenToProfile() {
    final uid = currentUser?.uid;
    if (uid == null) return;
    _profileSubscription?.cancel();
    _profileSubscription =
        _db.collection('users').doc(uid).snapshots().listen((snap) {
      if (snap.exists) {
        final d = snap.data() ?? {};
        _bio = d['bio'] ?? '';
        _phoneNumber = d['phoneNumber'];
        _base64Photo = d['photoBase64'];
        final rawFavs = d['favorites'] as List? ?? [];
        _favorites = rawFavs
            .map((e) => e.toString().trim())
            .where((id) => id.isNotEmpty)
            .toList();
        _hasEnteredFullName = d['hasEnteredFullName'] == true;

        final savedName = d['fullName'] ?? d['displayName'];
        final bool isStoredNameValid = isValidRealName(savedName?.toString());

        _requiresNameSetup = d['requiresNameSetup'] == true ||
            !_hasEnteredFullName ||
            !isStoredNameValid;

        if (isStoredNameValid && _hasEnteredFullName) {
          final trimmed = savedName.toString().trim();
          if (currentUser?.displayName != trimmed) {
            currentUser?.updateDisplayName(trimmed);
          }
        }
        notifyListeners();
      }
    }, onError: (e) {
      debugPrint('Profile stream error: $e');
    });
  }

  Future<void> toggleFavorite(String productId) async {
    if (_favorites.contains(productId)) {
      _favorites.remove(productId);
    } else {
      _favorites.add(productId);
    }
    notifyListeners();

    final uid = currentUser?.uid;
    if (uid != null) {
      try {
        await _db.collection('users').doc(uid).set(
          {'favorites': _favorites},
          SetOptions(merge: true),
        );
      } catch (e) {
        debugPrint('Error syncing favorites to Firestore: $e');
      }
    }
  }

  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
    await _saveFcmToken();
  }

  /// Intercepts Google Sign-In and checks if Google name passes sanitization.
  /// If valid, saves user to Firestore with full name and proceeds.
  /// If invalid/weird, sets fullName: null, requiresNameSetup: true, and returns true for ProfileSetupScreen.
  Future<bool> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return false;

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      bool needsSetup = false;

      if (user != null) {
        final rawGoogleName = googleUser.displayName ?? user.displayName;
        final doc = await _db.collection('users').doc(user.uid).get();

        if (!doc.exists) {
          // New User
          if (isValidRealName(rawGoogleName)) {
            final validName = rawGoogleName!.trim();
            await user.updateDisplayName(validName);
            await _db.collection('users').doc(user.uid).set({
              'email': user.email,
              'displayName': validName,
              'fullName': validName,
              'googleDisplayName': rawGoogleName,
              'hasEnteredFullName': true,
              'requiresNameSetup': false,
              'createdAt': FieldValue.serverTimestamp(),
            });
            _hasEnteredFullName = true;
            _requiresNameSetup = false;
            needsSetup = false;
          } else {
            // Invalid / Weird Google Name -> Sanitize input, set fullName to null, require setup
            await _db.collection('users').doc(user.uid).set({
              'email': user.email,
              'displayName': null,
              'fullName': null,
              'googleDisplayName': rawGoogleName,
              'hasEnteredFullName': false,
              'requiresNameSetup': true,
              'createdAt': FieldValue.serverTimestamp(),
            });
            _hasEnteredFullName = false;
            _requiresNameSetup = true;
            needsSetup = true;
          }
        } else {
          // Existing User
          final data = doc.data() ?? {};
          final existingName = data['fullName'] ?? data['displayName'];
          final bool isStoredNameValid = data['hasEnteredFullName'] == true &&
              isValidRealName(existingName?.toString());

          if (isStoredNameValid) {
            _hasEnteredFullName = true;
            _requiresNameSetup = false;
            needsSetup = false;
          } else if (isValidRealName(rawGoogleName)) {
            final validName = rawGoogleName!.trim();
            await user.updateDisplayName(validName);
            await _db.collection('users').doc(user.uid).set({
              'displayName': validName,
              'fullName': validName,
              'hasEnteredFullName': true,
              'requiresNameSetup': false,
            }, SetOptions(merge: true));
            _hasEnteredFullName = true;
            _requiresNameSetup = false;
            needsSetup = false;
          } else {
            await _db.collection('users').doc(user.uid).set({
              'fullName': null,
              'displayName': null,
              'requiresNameSetup': true,
              'hasEnteredFullName': false,
            }, SetOptions(merge: true));
            _hasEnteredFullName = false;
            _requiresNameSetup = true;
            needsSetup = true;
          }
        }
      }

      await _saveFcmToken();
      notifyListeners();
      return needsSetup;
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      rethrow;
    }
  }

  /// Completes profile setup with a sanitized real name and optional phone number.
  Future<void> completeProfileSetup({
    required String fullName,
    String? phone,
  }) async {
    final user = currentUser;
    if (user == null) return;

    final trimmedName = fullName.trim();
    if (!isValidRealName(trimmedName)) {
      throw FormatException('Invalid real name provided: $trimmedName');
    }

    await user.updateDisplayName(trimmedName);
    _hasEnteredFullName = true;
    _requiresNameSetup = false;

    await _db.collection('users').doc(user.uid).set({
      'displayName': trimmedName,
      'fullName': trimmedName,
      'hasEnteredFullName': true,
      'requiresNameSetup': false,
      if (phone != null && phone.trim().isNotEmpty) 'phoneNumber': phone.trim(),
    }, SetOptions(merge: true));

    notifyListeners();
  }

  Future<void> signUp(String email, String password, String name,
      {String? phone}) async {
    final cred = await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
    final trimmedName = name.trim();
    if (!isValidRealName(trimmedName)) {
      throw FormatException('Please enter a valid First and Last name.');
    }
    await cred.user?.updateDisplayName(trimmedName);

    await _db.collection('users').doc(cred.user!.uid).set({
      'email': email,
      'displayName': trimmedName,
      'fullName': trimmedName,
      'hasEnteredFullName': true,
      'requiresNameSetup': false,
      if (phone != null) 'phoneNumber': phone,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _hasEnteredFullName = true;
    _requiresNameSetup = false;
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

    final trimmedName = name?.trim();
    final bool isNameProvided = trimmedName != null &&
        trimmedName.isNotEmpty &&
        isValidRealName(trimmedName);

    if (isNameProvided) {
      await user.updateDisplayName(trimmedName);
      _hasEnteredFullName = true;
      _requiresNameSetup = false;
    }

    await _db.collection('users').doc(user.uid).set({
      if (isNameProvided) 'displayName': trimmedName,
      if (isNameProvided) 'fullName': trimmedName,
      if (isNameProvided) 'hasEnteredFullName': true,
      if (isNameProvided) 'requiresNameSetup': false,
      if (bio != null) 'bio': bio,
      if (phone != null) 'phoneNumber': phone,
    }, SetOptions(merge: true));

    notifyListeners();
  }

  Future<void> uploadProfilePicture(Uint8List bytes) async {
    final user = currentUser;
    if (user == null) return;

    final base64String = base64Encode(bytes);

    await _db.collection('users').doc(user.uid).set({
      'photoBase64': base64String,
    }, SetOptions(merge: true));

    notifyListeners();
  }

  Future<void> signOut() async {
    final user = _auth.currentUser;

    if (user?.email != null) {
      try {
        await NotificationService.unsubscribeFromCustomerTopic(user!.email!)
            .timeout(const Duration(seconds: 3));
      } catch (e) {
        debugPrint('FCM topic unsubscribe error on sign out: $e');
      }
    }

    try {
      await _profileSubscription?.cancel();
      _profileSubscription = null;
    } catch (e) {
      debugPrint('Profile subscription cancel error on sign out: $e');
    }

    try {
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('Google Sign-In signOut error: $e');
    }

    try {
      await _auth.signOut();
    } catch (e) {
      debugPrint('Firebase Auth signOut error: $e');
    }

    _bio = '';
    _phoneNumber = null;
    _base64Photo = null;
    _favorites = [];
    _hasEnteredFullName = false;
    _requiresNameSetup = false;

    notifyListeners();
  }

  @override
  void dispose() {
    _profileSubscription?.cancel();
    super.dispose();
  }
}
