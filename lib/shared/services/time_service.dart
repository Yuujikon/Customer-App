import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Central Time Service enabling Fast-Forward / Time Simulation
/// Synchronized across all devices via Firestore for Capstone Testing.
class TimeService with ChangeNotifier {
  static final TimeService instance = TimeService._internal();
  factory TimeService() => instance;
  
  TimeService._internal() {
    _initRealtimeSync();
  }

  Duration _offset = Duration.zero;
  StreamSubscription? _syncSubscription;

  /// Returns simulated system time (real-world DateTime + fast-forward offset)
  static DateTime get now => DateTime.now().add(instance._offset);

  /// Returns current offset
  Duration get offset => _offset;

  /// Returns true if time is currently fast-forwarded / simulated
  bool get isSimulated => _offset != Duration.zero;

  void _initRealtimeSync() {
    _syncSubscription = FirebaseFirestore.instance
        .collection('system_config')
        .doc('time_simulation')
        .snapshots()
        .listen((doc) {
      if (doc.exists && doc.data() != null) {
        final mins = (doc.data()!['offsetMinutes'] as num? ?? 0).toInt();
        if (_offset.inMinutes != mins) {
          _offset = Duration(minutes: mins);
          notifyListeners();
        }
      }
    });
  }

  /// Pushes the new time offset to Firestore to sync all devices globally.
  Future<void> _syncToFirestore(Duration newOffset) async {
    await FirebaseFirestore.instance
        .collection('system_config')
        .doc('time_simulation')
        .set({'offsetMinutes': newOffset.inMinutes}, SetOptions(merge: true));
  }

  /// Fast forwards time by minutes
  Future<void> addMinutes(int minutes) async {
    final newOffset = _offset + Duration(minutes: minutes);
    await _syncToFirestore(newOffset);
  }

  /// Fast forwards time by hours
  Future<void> addHours(int hours) async {
    final newOffset = _offset + Duration(hours: hours);
    await _syncToFirestore(newOffset);
  }

  /// Fast forwards time by days
  Future<void> addDays(int days) async {
    final newOffset = _offset + Duration(days: days);
    await _syncToFirestore(newOffset);
  }

  /// Resets simulated time back to live real-world system clock globally
  Future<void> reset() async {
    await _syncToFirestore(Duration.zero);
  }

  /// Formatted string describing current offset (e.g. "+2 hrs", "+1 day")
  String get offsetFormatted {
    if (_offset == Duration.zero) return 'Real Time';
    if (_offset.inDays > 0) {
      return '+${_offset.inDays}d ${_offset.inHours % 24}h';
    }
    if (_offset.inHours > 0) {
      return '+${_offset.inHours}h ${_offset.inMinutes % 60}m';
    }
    return '+${_offset.inMinutes}m';
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
  }
}
