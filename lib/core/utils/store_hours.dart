import 'package:intl/intl.dart';
import '../../shared/models/store_settings.dart';
import '../../shared/services/time_service.dart';

class StoreHours {
  // Default store pickup hours (11:00 AM to 3:00 PM) when operatingHoursEnabled is false
  static const int openHour = 11; // 11:00 AM
  static const int closeHour = 15; // 3:00 PM (15:00)
  static const int prepBufferMinutes = 20; // 20-minute preparation buffer

  // Matches:
  //   "Today, 1:00 PM – 2:00 PM"
  //   "Tomorrow, 11:00 AM - 12:00 PM"
  //   "Wed, Nov 25, 11:00 AM – 12:00 PM"
  //   "Wednesday, Nov 25, 11:30 AM – 12:30 PM"
  //   "Nov 25, 11:00 AM – 12:00 PM"
  //   "Today, 1:30 PM" (single time without range)
  static final RegExp _slotRegex = RegExp(
    r'^(.+?),\s*(\d{1,2}:\d{2}\s*[AP]M)(?:\s*[\-–—]\s*(\d{1,2}:\d{2}\s*[AP]M))?$',
    caseSensitive: false,
  );

  static int effectiveOpenHour(StoreSettings? settings) {
    if (settings != null && settings.operatingHoursEnabled) {
      return settings.openHour;
    }
    return openHour;
  }

  static int effectiveCloseHour(StoreSettings? settings) {
    if (settings != null && settings.operatingHoursEnabled) {
      final close = settings.closeHour;
      final open = settings.openHour;
      if (close > open) return close;
    }
    return closeHour;
  }

  static String _formatHour(int h) {
    final normalized = h % 24;
    if (normalized == 0) return '12:00 AM';
    if (normalized == 12) return '12:00 PM';
    if (normalized > 12) return '${normalized - 12}:00 PM';
    return '$normalized:00 AM';
  }

  /// Parses a slot string into its exact `(start, end)` DateTimes, or `null` if unparseable.
  /// Handles "Today", "Tomorrow", "EEE, MMM d" (2 commas), "EEEE, MMM d", and "MMM d".
  static ({DateTime start, DateTime end})? parseSlotRange(
    String slotStr, {
    DateTime? nowTime,
  }) {
    final now = nowTime ?? TimeService.now;
    final trimmed = slotStr.trim();
    if (trimmed.contains('ASAP')) {
      final ready = now.add(const Duration(minutes: prepBufferMinutes));
      return (start: ready, end: ready);
    }

    final match = _slotRegex.firstMatch(trimmed);
    if (match == null) return null;

    final datePart = match.group(1)!.trim();
    final startStr = match.group(2)!.trim().toUpperCase();
    final endStr = (match.group(3) ?? match.group(2))!.trim().toUpperCase();

    DateTime parsedStartTime;
    DateTime parsedEndTime;
    try {
      final timeFormat = DateFormat('h:mm a');
      parsedStartTime = timeFormat.parseStrict(startStr);
      parsedEndTime = timeFormat.parseStrict(endStr);
    } catch (_) {
      return null;
    }

    final today = DateTime(now.year, now.month, now.day);
    DateTime? baseDate;

    if (datePart.toLowerCase() == 'today') {
      baseDate = today;
    } else if (datePart.toLowerCase() == 'tomorrow') {
      baseDate = today.add(const Duration(days: 1));
    } else {
      for (final fmt in ['EEE, MMM d', 'EEEE, MMM d', 'MMM d', 'MMMM d']) {
        try {
          final parsed = DateFormat(fmt).parseStrict(datePart);
          var candidate = DateTime(now.year, parsed.month, parsed.day);
          if (candidate.isBefore(today.subtract(const Duration(days: 30)))) {
            candidate = DateTime(now.year + 1, parsed.month, parsed.day);
          }
          baseDate = candidate;
          break;
        } catch (_) {}
      }
    }

    if (baseDate == null) return null;

    final start = DateTime(
      baseDate.year,
      baseDate.month,
      baseDate.day,
      parsedStartTime.hour,
      parsedStartTime.minute,
    );

    var end = DateTime(
      baseDate.year,
      baseDate.month,
      baseDate.day,
      parsedEndTime.hour,
      parsedEndTime.minute,
    );

    // Handle range crossing midnight (e.g., 11:00 PM – 12:00 AM)
    if (match.group(3) != null && !end.isAfter(start)) {
      end = end.add(const Duration(days: 1));
    }

    return (start: start, end: end);
  }

  /// Checks if the store is currently within active pickup hours.
  static bool isOpen({DateTime? nowTime, StoreSettings? settings}) {
    final now = nowTime ?? TimeService.now;
    if (settings != null && settings.isClosed) return false;
    final openH = effectiveOpenHour(settings);
    final closeH = effectiveCloseHour(settings);
    return now.hour >= openH && now.hour < closeH;
  }

  /// Returns ASAP express pickup label (e.g., "ASAP (Ready by ~1:32 PM)").
  static String asapPickupSlot({DateTime? nowTime}) {
    final readyTime = (nowTime ?? TimeService.now)
        .add(const Duration(minutes: prepBufferMinutes));
    final timeStr = DateFormat('h:mm a').format(readyTime);
    return 'ASAP (Ready by ~$timeStr)';
  }

  /// Calculates the earliest valid pickup date considering operating hours and prep buffer.
  /// Returns Tomorrow if Today's last slot can no longer satisfy the prep buffer.
  static DateTime getEarliestPickupDate({
    DateTime? nowTime,
    StoreSettings? settings,
  }) {
    final now = nowTime ?? TimeService.now;
    final today = DateTime(now.year, now.month, now.day);
    final closeH = effectiveCloseHour(settings);
    final todayClose =
        DateTime(today.year, today.month, today.day, closeH, 0);
    final readyAt = now.add(const Duration(minutes: prepBufferMinutes));

    if (!readyAt.isBefore(todayClose)) {
      return today.add(const Duration(days: 1));
    }
    return today;
  }

  /// Returns dynamic initial default pickup slot formatted string within operating hours.
  /// Selects the current active slot or next upcoming slot whose END time can satisfy prep buffer.
  static String defaultPickupSlot({
    DateTime? nowTime,
    StoreSettings? settings,
  }) {
    final now = nowTime ?? TimeService.now;
    final today = DateTime(now.year, now.month, now.day);
    final openH = effectiveOpenHour(settings);
    final closeH = effectiveCloseHour(settings);
    final earliestDate =
        getEarliestPickupDate(nowTime: now, settings: settings);
    final readyAt = now.add(const Duration(minutes: prepBufferMinutes));

    final bool isTodayAvailable = earliestDate.year == today.year &&
        earliestDate.month == today.month &&
        earliestDate.day == today.day;

    if (isTodayAvailable) {
      for (int h = openH; h < closeH; h++) {
        final slotEndTime =
            DateTime(today.year, today.month, today.day, h + 1);
        if (readyAt.isBefore(slotEndTime)) {
          return 'Today, ${_formatHour(h)} – ${_formatHour(h + 1)}';
        }
      }
    }

    final firstRange = '${_formatHour(openH)} – ${_formatHour(openH + 1)}';
    final tomorrow = today.add(const Duration(days: 1));
    if (earliestDate.year == tomorrow.year &&
        earliestDate.month == tomorrow.month &&
        earliestDate.day == tomorrow.day) {
      return 'Tomorrow, $firstRange';
    }

    final dateLabel = DateFormat('EEE, MMM d').format(earliestDate);
    return '$dateLabel, $firstRange';
  }

  /// Checks whether a formatted pickup slot string has passed its usable window.
  /// A slot is considered expired when `now + prepBufferMinutes` reaches or passes its END time.
  static bool isSlotExpired(
    String slotStr, {
    DateTime? nowTime,
    StoreSettings? settings,
    DateTime? pickupEnd,
  }) {
    if (slotStr.contains('ASAP')) {
      return !isOpen(nowTime: nowTime, settings: settings);
    }

    final now = nowTime ?? TimeService.now;
    final endTime =
        pickupEnd ?? parseSlotRange(slotStr, nowTime: now)?.end;
    if (endTime == null) return false;

    final readyAt = now.add(const Duration(minutes: prepBufferMinutes));
    return !readyAt.isBefore(endTime);
  }

  /// Parses a pickup slot string into the START DateTime of the slot.
  /// Prefers [pickupStart] when already stored as a structured Timestamp.
  static DateTime parseSlotTargetDateTime(
    String slotStr, {
    DateTime? nowTime,
    DateTime? pickupStart,
  }) {
    if (pickupStart != null) return pickupStart;
    final now = nowTime ?? TimeService.now;
    final parsed = parseSlotRange(slotStr, nowTime: now);
    if (parsed != null) return parsed.start;
    return now.add(const Duration(minutes: prepBufferMinutes));
  }

  /// Parses a pickup slot string into the END DateTime of the slot.
  /// Prefers [pickupEnd] when already stored as a structured Timestamp.
  static DateTime parseSlotEndDateTime(
    String slotStr, {
    DateTime? nowTime,
    DateTime? pickupEnd,
  }) {
    if (pickupEnd != null) return pickupEnd;
    final now = nowTime ?? TimeService.now;
    final parsed = parseSlotRange(slotStr, nowTime: now);
    if (parsed != null) return parsed.end;
    return now.add(const Duration(minutes: prepBufferMinutes));
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
      final expiryDay = DateTime(
          earliestExpiry.year, earliestExpiry.month, earliestExpiry.day);
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

  /// Returns available time slots for a specific date within store hours,
  /// filtered by prep buffer and FEFO batch expiration date.
  static List<Map<String, dynamic>> getTimeSlotsForDate(
    DateTime date, {
    int maxHours = 72,
    DateTime? earliestExpiry,
    DateTime? nowTime,
    StoreSettings? settings,
  }) {
    final now = nowTime ?? TimeService.now;
    final windowEnd = now.add(Duration(hours: maxHours));
    final List<Map<String, dynamic>> slots = [];

    final openH = effectiveOpenHour(settings);
    final closeH = effectiveCloseHour(settings);

    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final isToday =
        date.year == today.year && date.month == today.month && date.day == today.day;
    final isTomorrow = date.year == tomorrow.year &&
        date.month == tomorrow.month &&
        date.day == tomorrow.day;

    for (int h = openH; h < closeH; h++) {
      final slotDateTime = DateTime(date.year, date.month, date.day, h);
      final slotEndTime = DateTime(date.year, date.month, date.day, h + 1);

      // Skip slots whose end time cannot satisfy prep buffer
      if (isToday &&
          !now
              .add(const Duration(minutes: prepBufferMinutes))
              .isBefore(slotEndTime)) {
        continue;
      }

      // Skip hours exceeding window or batch expiry
      if (slotDateTime.isAfter(windowEnd)) continue;
      if (earliestExpiry != null && slotEndTime.isAfter(earliestExpiry)) {
        continue;
      }

      final startStr = _formatHour(h);
      final endStr = _formatHour(h + 1);

      final dateLabel = isToday
          ? 'Today'
          : (isTomorrow ? 'Tomorrow' : DateFormat('EEE, MMM d').format(date));
      final slotValue = '$dateLabel, $startStr – $endStr';

      slots.add({
        'dateTime': slotDateTime,
        'endDateTime': slotEndTime,
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
    StoreSettings? settings,
  }) {
    final dates = getAvailableDates(
        maxHours: maxHours, earliestExpiry: earliestExpiry, nowTime: nowTime);
    final List<Map<String, dynamic>> allSlots = [];

    for (final date in dates) {
      final daySlots = getTimeSlotsForDate(
        date,
        maxHours: maxHours,
        earliestExpiry: earliestExpiry,
        nowTime: nowTime,
        settings: settings,
      );
      final now = nowTime ?? TimeService.now;
      final today = DateTime(now.year, now.month, now.day);
      final isToday = date.year == today.year &&
          date.month == today.month &&
          date.day == today.day;
      final isTomorrow = date.difference(today).inDays == 1;
      final dayName = isToday
          ? 'Today'
          : (isTomorrow ? 'Tomorrow' : DateFormat('EEE, MMM d').format(date));
      final dateStr = DateFormat('MMM d').format(date);

      for (final slot in daySlots) {
        final h = slot['hour'] as int;

        allSlots.add({
          'value': slot['value'],
          'label': '$dayName ($dateStr): ${slot['rangeLabel']}',
          'isPast': false,
          'hour': h,
          'day': dayName,
          'dateLabel': dateStr,
          'dateTime': slot['dateTime'],
          'endDateTime': slot['endDateTime'],
        });
      }
    }

    return allSlots;
  }
}
