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

  /// Returns allowed pickup dates starting from today up to maxHours window from now.
  static List<DateTime> getAvailableDates({int maxHours = 72}) {
    final now = DateTime.now();
    final windowEnd = now.add(Duration(hours: maxHours));
    final List<DateTime> dates = [];

    DateTime current = DateTime(now.year, now.month, now.day);
    final endDate = DateTime(windowEnd.year, windowEnd.month, windowEnd.day);

    while (!current.isAfter(endDate)) {
      dates.add(current);
      current = current.add(const Duration(days: 1));
    }

    return dates;
  }

  /// Returns available time slots for a specific date within store hours (9 AM - 10 PM) and maxHours window.
  static List<Map<String, dynamic>> getTimeSlotsForDate(DateTime date, {int maxHours = 72}) {
    final now = DateTime.now();
    final windowEnd = now.add(Duration(hours: maxHours));
    final List<Map<String, dynamic>> slots = [];

    final isToday = date.year == now.year && date.month == now.month && date.day == now.day;

    for (int h = openHour; h < closeHour; h++) {
      final slotDateTime = DateTime(date.year, date.month, date.day, h);

      // Skip past hours for today
      if (isToday && h <= now.hour) continue;

      // Skip hours that exceed the maxHours window
      if (slotDateTime.isAfter(windowEnd)) continue;

      final hStart = h;
      final hEnd   = h + 1;

      final startStr = hStart == 12 ? '12:00 PM' : (hStart > 12 ? '${hStart - 12}:00 PM' : '$hStart:00 AM');
      final endStr   = hEnd == 12 ? '12:00 PM' : (hEnd > 12 ? '${hEnd - 12}:00 PM' : '$hEnd:00 AM');

      final dateLabel = isToday ? 'Today' : DateFormat('EEE, MMM d').format(date);
      final slotValue = '$dateLabel $startStr';

      slots.add({
        'dateTime': slotDateTime,
        'hour': h,
        'timeLabel': startStr,
        'rangeLabel': '$startStr – $endStr',
        'value': slotValue,
      });
    }

    return slots;
  }

  static List<Map<String, dynamic>> availableSlots({
    int maxHours = 72,
  }) {
    final dates = getAvailableDates(maxHours: maxHours);
    final List<Map<String, dynamic>> allSlots = [];

    for (final date in dates) {
      final daySlots = getTimeSlotsForDate(date, maxHours: maxHours);
      final isToday = date.year == DateTime.now().year && date.month == DateTime.now().month && date.day == DateTime.now().day;
      final isTomorrow = date.difference(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)).inDays == 1;
      final dayName = isToday ? 'Today' : (isTomorrow ? 'Tomorrow' : DateFormat('EEEE').format(date));
      final dateStr = DateFormat('MMM d').format(date);

      for (final slot in daySlots) {
        final timeOnly = slot['timeLabel'] as String;
        final h = slot['hour'] as int;

        allSlots.add({
          'value': '$dayName $timeOnly',
          'label': '$dayName ($dateStr): ${slot['rangeLabel']}',
          'isPast': false,
          'hour': h,
          'day': dayName,
          'dateLabel': dateStr,
        });
      }
    }

    return allSlots;
  }
}
