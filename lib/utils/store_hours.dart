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
    int maxHours = 72,
  }) {
    final now = DateTime.now();
    List<Map<String, dynamic>> allSlots = [];

    // Calculate the absolute deadline for pickup
    final windowEnd = now.add(Duration(hours: maxHours));

    // We check up to 4 days just to be safe with date transitions
    for (int i = 0; i < 4; i++) {
      final date = now.add(Duration(days: i));
      final isToday = i == 0;
      final dayName = isToday ? 'Today' : (i == 1 ? 'Tomorrow' : DateFormat('EEEE').format(date));
      final dateStr = DateFormat('MMM d');

      // Only process days that fall within our window
      if (DateTime(date.year, date.month, date.day, openHour).isAfter(windowEnd)) {
        break; 
      }

      for (int h = openHour; h < closeHour; h++) {
        final slotTime = DateTime(date.year, date.month, date.day, h);
        
        // Skip if slot is in the past
        if (isToday && h <= now.hour) continue;
        
        // Skip if slot is outside the allowed window
        if (slotTime.isAfter(windowEnd)) continue;

        final hStart = h;
        final hEnd   = h + 1;
        
        final timeLabel = hStart == 12 ? '12:00 PM' : (hStart > 12 ? '${hStart - 12}:00 PM' : '$hStart:00 AM');
        final endLabel  = hEnd == 12 ? '12:00 PM' : (hEnd > 12 ? '${hEnd - 12}:00 PM' : '$hEnd:00 AM');

        allSlots.add({
          'value': '$dayName $timeLabel',
          'label': '$dayName (${dateStr.format(date)}): $timeLabel – $endLabel',
          'isPast': false,
          'hour': h,
        });
      }
    }

    return allSlots;
  }
}
