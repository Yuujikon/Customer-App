import 'package:intl/intl.dart';

class StoreHours {
  // Current active store hours for pickup
  static const int openHour  = 9;  // 9:00 AM
  static const int closeHour = 22; // 10:00 PM

  /// Checks if the store is currently within active pickup hours.
  static bool isOpen() {
    final h = DateTime.now().hour;
    return h >= openHour && h < closeHour;
  }

  static List<Map<String, dynamic>> availableSlots({
    bool hasPerishables = false, 
    bool onlyPerishables = false,
  }) {
    final now = DateTime.now();
    List<Map<String, dynamic>> allSlots = [];

    // How many days to show based on item types
    int daysToShow = 1; 
    if (!onlyPerishables) {
      if (hasPerishables) daysToShow = 2; 
      else daysToShow = 4; 
    }

    for (int i = 0; i < daysToShow; i++) {
      final date = now.add(Duration(days: i));
      final isToday = i == 0;
      final dayName = isToday ? 'Today' : (i == 1 ? 'Tomorrow' : DateFormat('EEEE').format(date));
      final dateStr = DateFormat('MMM d');

      for (int h = openHour; h <= closeHour; h++) {
        final timeLabel = h == 12 ? '12:00 PM' : (h > 12 ? '${h - 12}:00 PM' : '$h:00 AM');
        final endLabel = (h + 1) == 12 ? '12:00 PM' : ((h + 1) > 12 ? '${(h + 1) - 12}:00 PM' : '${h + 1}:00 AM');
        
        bool isPast = isToday && h <= now.hour;

        allSlots.add({
          'value': '$dayName $timeLabel',
          'label': '$dayName (${dateStr.format(date)}): $timeLabel – $endLabel',
          'isPast': isPast,
          'hour': h,
        });
      }
    }

    return allSlots;
  }
}
