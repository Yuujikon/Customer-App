import 'package:flutter/foundation.dart';

/// Central Time Service enabling Fast-Forward / Time Simulation
/// for Capstone Presentations, Testing & Order Expiration Demonstrations.
class TimeService with ChangeNotifier {
  static final TimeService instance = TimeService._internal();
  factory TimeService() => instance;
  TimeService._internal();

  Duration _offset = Duration.zero;

  /// Returns simulated system time (real-world DateTime + fast-forward offset)
  static DateTime get now => DateTime.now().add(instance._offset);

  /// Returns current offset
  Duration get offset => _offset;

  /// Returns true if time is currently fast-forwarded / simulated
  bool get isSimulated => _offset != Duration.zero;

  /// Fast forwards time by the specified duration
  void fastForward(Duration duration) {
    _offset += duration;
    notifyListeners();
  }

  /// Fast forwards time by minutes
  void addMinutes(int minutes) {
    _offset += Duration(minutes: minutes);
    notifyListeners();
  }

  /// Fast forwards time by hours
  void addHours(int hours) {
    _offset += Duration(hours: hours);
    notifyListeners();
  }

  /// Fast forwards time by days
  void addDays(int days) {
    _offset += Duration(days: days);
    notifyListeners();
  }

  /// Resets simulated time back to live real-world system clock
  void reset() {
    _offset = Duration.zero;
    notifyListeners();
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
}
