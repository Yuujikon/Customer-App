import 'package:intl/intl.dart';
import '../../shared/services/time_service.dart';

class StoreHours {
  // Designated store pickup hours (11:00 AM to 3:00 PM)
  static const int openHour = 11; // 11:00 AM
  static const int closeHour = 15; // 3:00 PM (15:00)
  static const int prepBufferMinutes = 20; // 20-minute preparation buffer

  /// Checks if the store is currently within active pickup hours (11:00 AM – 3:00 PM).
  static bool isOpen({DateTime? nowTime}) {
    final h = (nowTime ?? TimeService.now).hour;
    return h >= openHour && h < closeHour;
  }

  /// Returns ASAP express pickup label (e.g., "ASAP (Ready by ~1:32 PM)").
  static String asapPickupSlot({DateTime? nowTime}) {
    final readyTime = (nowTime ?? TimeService.now).add(const Duration(minutes: prepBufferMinutes));
    final timeStr = DateFormat('h:mm a').format(readyTime);
    return 'ASAP (Ready by ~$timeStr)';
  }

  /// Returns dynamic initial default pickup slot formatted string within 11:00 AM – 3:00 PM hours.
  static String defaultPickupSlot({DateTime? nowTime}) {
    final now = nowTime ?? TimeService.now;
    final today = DateTime(now.year, now.month, now.day);

    for (int h = openHour; h < closeHour; h++) {
      final slotEndTime = DateTime(today.year, today.month, today.day, h + 1);
      if (now.add(const Duration(minutes: prepBufferMinutes)).isBefore(slotEndTime)) {
        final startStr = h == 12 ? '12:00 PM' : (h > 12 ? '${h - 12}:00 PM' : '$h:00 AM');
        final endH = h + 1;
        final endStr = endH == 12 ? '12:00 PM' : (endH > 12 ? '${endH - 12}:00 PM' : '$endH:00 AM');
        return 'Today, $startStr – $endStr';
      }
    }

    return 'Tomorrow, 11:00 AM – 12:00 PM';
  }

  /// Checks whether a formatted pickup slot string has passed its usable window.
  static bool isSlotExpired(String slotStr, {DateTime? nowTime}) {
    if (slotStr.contains('ASAP')) {
      return !isOpen(nowTime: nowTime);
    }

    final now = nowTime ?? TimeService.now;
    try {
      final parts = slotStr.split(',');
      if (parts.length < 2) return false;

      final datePart = parts[0].trim();
      final rangeParts = parts[1].split('–');
      final timePart = (rangeParts.length > 1 ? rangeParts[1] : rangeParts[0]).trim();
      final timeFormat = DateFormat('h:mm a');
      final parsedTime = timeFormat.parse(timePart);

      final today = DateTime(now.year, now.month, now.day);
      DateTime baseDate;

      if (datePart == 'Today') {
        baseDate = today;
      } else if (datePart == 'Tomorrow') {
        baseDate = today.add(const Duration(days: 1));
      } else {
        final parsed = DateFormat('EEE, MMM d').parse(datePart);
        baseDate = DateTime(now.year, parsed.month, parsed.day);
        if (baseDate.isBefore(today.subtract(const Duration(days: 30)))) {
          baseDate = DateTime(now.year + 1, parsed.month, parsed.day);
        }
      }

      final slotEndTime = DateTime(
        baseDate.year,
        baseDate.month,
        baseDate.day,
        parsedTime.hour,
        parsedTime.minute,
      );

      return now.add(const Duration(minutes: prepBufferMinutes)).isAfter(slotEndTime) ||
          now.add(const Duration(minutes: prepBufferMinutes)).isAtSameMomentAs(slotEndTime);
    } catch (_) {
      return false;
    }
  }

  /// Parses a pickup slot string into a target DateTime for scheduling & expiration calculation.
  static DateTime parseSlotTargetDateTime(String slotStr, {DateTime? nowTime}) {
    final now = nowTime ?? TimeService.now;
    if (slotStr.contains('ASAP')) {
      return now.add(const Duration(minutes: prepBufferMinutes));
    }

    try {
      final parts = slotStr.split(',');
      if (parts.length < 2) return now.add(const Duration(minutes: prepBufferMinutes));

      final datePart = parts[0].trim();
      final timePart = parts[1].split('–')[0].trim();
      final timeFormat = DateFormat('h:mm a');
      final parsedTime = timeFormat.parse(timePart);

      final today = DateTime(now.year, now.month, now.day);
      DateTime baseDate;

      if (datePart == 'Today') {
        baseDate = today;
      } else if (datePart == 'Tomorrow') {
        baseDate = today.add(const Duration(days: 1));
      } else {
        final parsed = DateFormat('EEE, MMM d').parse(datePart);
        baseDate = DateTime(now.year, parsed.month, parsed.day);
        if (baseDate.isBefore(today.subtract(const Duration(days: 30)))) {
          baseDate = DateTime(now.year + 1, parsed.month, parsed.day);
        }
      }

      return DateTime(
        baseDate.year,
        baseDate.month,
        baseDate.day,
        parsedTime.hour,
        parsedTime.minute,
      );
    } catch (_) {
      return now.add(const Duration(minutes: prepBufferMinutes));
    }
  }

  /// Returns allowed pickup dates starting from today up to maxHours window from now,
  /// bounded by the earliest FEFO batch expiry date if provided.
  static List<DateTime> getAvailableDates({
    int maxHours = 72,
    DateTime? earliestExpiry,
    DateTime? nowTime,
  }) {
    final now = nowTime ?? TimeService.now;
    final windowEnd = now.add(Duration(hours: maxHours));
    final List<DateTime> dates = [];

    DateTime current = DateTime(now.year, now.month, now.day);
    DateTime endDate = DateTime(windowEnd.year, windowEnd.month, windowEnd.day);

    if (earliestExpiry != null) {
      final expiryDay = DateTime(earliestExpiry.year, earliestExpiry.month, earliestExpiry.day);
      if (expiryDay.isBefore(endDate)) {
        endDate = expiryDay;
      }
    }

    while (!current.isAfter(endDate)) {
      dates.add(current);
      current = current.add(const Duration(days: 1));
    }

    return dates;
  }

  /// Returns available time slots for a specific date within store hours (11 AM - 3 PM),
  /// filtered by prep buffer and FEFO batch expiration date.
  static List<Map<String, dynamic>> getTimeSlotsForDate(
    DateTime date, {
    int maxHours = 72,
    DateTime? earliestExpiry,
    DateTime? nowTime,
  }) {
    final now = nowTime ?? TimeService.now;
    final windowEnd = now.add(Duration(hours: maxHours));
    final List<Map<String, dynamic>> slots = [];

    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;

    for (int h = openHour; h < closeHour; h++) {
      final slotDateTime = DateTime(date.year, date.month, date.day, h);
      final slotEndTime = DateTime(date.year, date.month, date.day, h + 1);

      // Skip slots whose end time cannot satisfy prep buffer
      if (isToday && now.add(const Duration(minutes: prepBufferMinutes)).isAfter(slotEndTime)) {
        continue;
      }

      // Skip hours exceeding window or batch expiry
      if (slotDateTime.isAfter(windowEnd)) continue;
      if (earliestExpiry != null && slotEndTime.isAfter(earliestExpiry)) continue;

      final hStart = h;
      final hEnd = h + 1;

      final startStr = hStart == 12
          ? '12:00 PM'
          : (hStart > 12 ? '${hStart - 12}:00 PM' : '$hStart:00 AM');
      final endStr = hEnd == 12
          ? '12:00 PM'
          : (hEnd > 12 ? '${hEnd - 12}:00 PM' : '$hEnd:00 AM');

      final dateLabel =
          isToday ? 'Today' : DateFormat('EEE, MMM d').format(date);
      final slotValue = '$dateLabel, $startStr – $endStr';

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
    DateTime? earliestExpiry,
    DateTime? nowTime,
  }) {
    final dates = getAvailableDates(maxHours: maxHours, earliestExpiry: earliestExpiry, nowTime: nowTime);
    final List<Map<String, dynamic>> allSlots = [];

    for (final date in dates) {
      final daySlots = getTimeSlotsForDate(date, maxHours: maxHours, earliestExpiry: earliestExpiry, nowTime: nowTime);
      final now = nowTime ?? TimeService.now;
      final isToday = date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
      final isTomorrow = date
              .difference(DateTime(now.year, now.month, now.day))
              .inDays ==
          1;
      final dayName = isToday
          ? 'Today'
          : (isTomorrow ? 'Tomorrow' : DateFormat('EEEE').format(date));
      final dateStr = DateFormat('MMM d').format(date);

      for (final slot in daySlots) {
        final timeOnly = slot['timeLabel'] as String;
        final h = slot['hour'] as int;

        allSlots.add({
          'value': '$dayName, ${slot['rangeLabel']}',
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
