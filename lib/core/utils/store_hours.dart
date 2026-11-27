import 'dart:math' as math;
import 'package:intl/intl.dart';
import '../../shared/models/order.dart';
import '../../shared/models/product.dart';
import '../../shared/models/store_settings.dart';
import '../../shared/services/time_service.dart';

enum BasketProductTier {
  perishableOnly,
  mixed,
  standard,
}

/// Captures the product-driven pickup reservation rules for a customer's basket,
/// combining per-product attributes (perishability, shelf life, custom pickup
/// window, FEFO expiry date) with Admin [StoreSettings] windows.
class BasketPickupPolicy {
  final BasketProductTier tier;
  final bool hasPerishables;
  final bool onlyPerishables;
  final int maxAdvanceDays;
  final int maxReservationHours;
  final int holdWindowHours;
  final int? minProductPickupWindowHours;
  final String? tightestWindowProductName;
  final int? minShelfDays;
  final DateTime? earliestExpiry;
  final String? earliestExpiryProductName;

  const BasketPickupPolicy({
    required this.tier,
    required this.hasPerishables,
    required this.onlyPerishables,
    required this.maxAdvanceDays,
    required this.maxReservationHours,
    required this.holdWindowHours,
    this.minProductPickupWindowHours,
    this.tightestWindowProductName,
    this.minShelfDays,
    this.earliestExpiry,
    this.earliestExpiryProductName,
  });

  /// Default policy when no cart items are supplied.
  factory BasketPickupPolicy.standard({StoreSettings? settings}) {
    final sHours = (settings?.standardWindowHours ?? 72).clamp(1, 336);
    return BasketPickupPolicy(
      tier: BasketProductTier.standard,
      hasPerishables: false,
      onlyPerishables: false,
      maxAdvanceDays: (sHours / 24).ceil().clamp(1, 14),
      maxReservationHours: sHours,
      holdWindowHours: sHours,
    );
  }

  /// Evaluates the reservation policy for [cart] using live [allProducts] and
  /// Admin-configured [settings].
  factory BasketPickupPolicy.fromCart({
    required List<CartItem> cart,
    required List<Product> allProducts,
    StoreSettings? settings,
  }) {
    if (cart.isEmpty) {
      return BasketPickupPolicy.standard(settings: settings);
    }

    final productById = <String, Product>{
      for (final p in allProducts) p.id: p,
    };

    bool hasPerishables = false;
    bool allPerishables = true;
    int? minPickupWindowHours;
    String? tightestWindowProductName;
    int? minShelfDays;
    DateTime? earliestExpiry;
    String? earliestExpiryProductName;

    for (final item in cart) {
      final product = productById[item.productId];
      final bool itemPerishable = (product?.isPerishable ?? false) ||
          item.isPerishable ||
          (product?.shelfDays != null) ||
          (product?.expiryDate != null);

      if (itemPerishable) {
        hasPerishables = true;
      } else {
        allPerishables = false;
      }

      if (product != null) {
        final pw = product.pickupWindowHours;
        if (pw != null && pw > 0) {
          if (minPickupWindowHours == null || pw < minPickupWindowHours) {
            minPickupWindowHours = pw;
            tightestWindowProductName = product.name;
          }
        }

        final sd = product.shelfDays;
        if (sd != null && sd > 0) {
          if (minShelfDays == null || sd < minShelfDays) {
            minShelfDays = sd;
          }
        }

        final exp = product.expiryDate;
        if (exp != null) {
          final normalizedExp = _normalizeExpiry(exp);
          if (earliestExpiry == null ||
              normalizedExp.isBefore(earliestExpiry)) {
            earliestExpiry = normalizedExp;
            earliestExpiryProductName = product.name;
          }
        }
      }
    }

    final int pWindow = (settings?.perishableWindowHours ?? 2).clamp(1, 168);
    final int mWindow = (settings?.mixedWindowHours ?? 24).clamp(1, 168);
    final int sWindow = (settings?.standardWindowHours ?? 72).clamp(1, 336);

    final BasketProductTier tier;
    int holdWindowHours;
    int maxReservationHours;
    int maxAdvanceDays;

    if (allPerishables) {
      tier = BasketProductTier.perishableOnly;
      holdWindowHours = minPickupWindowHours != null
          ? math.min(pWindow, minPickupWindowHours)
          : pWindow;
      // Allow reserving today or next open operating day (up to shelf life, max 2 days)
      final int shelfHours =
          minShelfDays != null ? (minShelfDays * 24).clamp(24, 48) : 24;
      maxReservationHours =
          math.max(24, math.min(shelfHours, math.max(24, pWindow)));
      if (minPickupWindowHours != null && minPickupWindowHours >= 24) {
        maxReservationHours =
            math.min(maxReservationHours, minPickupWindowHours);
      }
      maxAdvanceDays = (maxReservationHours / 24).ceil().clamp(1, 2);
    } else if (hasPerishables) {
      tier = BasketProductTier.mixed;
      holdWindowHours = minPickupWindowHours != null
          ? math.min(mWindow, minPickupWindowHours)
          : mWindow;
      maxReservationHours = math.max(24, mWindow);
      if (minShelfDays != null) {
        maxReservationHours =
            math.min(maxReservationHours, math.max(24, minShelfDays * 24));
      }
      if (minPickupWindowHours != null && minPickupWindowHours >= 24) {
        maxReservationHours =
            math.min(maxReservationHours, minPickupWindowHours);
      }
      maxAdvanceDays = (maxReservationHours / 24).ceil().clamp(1, 3);
    } else {
      tier = BasketProductTier.standard;
      holdWindowHours = sWindow;
      maxReservationHours = sWindow;
      if (minPickupWindowHours != null && minPickupWindowHours >= 24) {
        maxReservationHours =
            math.min(maxReservationHours, minPickupWindowHours);
      }
      maxAdvanceDays = (maxReservationHours / 24).ceil().clamp(1, 14);
    }

    return BasketPickupPolicy(
      tier: tier,
      hasPerishables: hasPerishables,
      onlyPerishables: allPerishables,
      maxAdvanceDays: maxAdvanceDays,
      maxReservationHours: maxReservationHours,
      holdWindowHours: holdWindowHours,
      minProductPickupWindowHours: minPickupWindowHours,
      tightestWindowProductName: tightestWindowProductName,
      minShelfDays: minShelfDays,
      earliestExpiry: earliestExpiry,
      earliestExpiryProductName: earliestExpiryProductName,
    );
  }

  /// If a Firestore expiry date is stored as midnight (date-only), treat the
  /// product as usable through the end of that calendar day.
  static DateTime _normalizeExpiry(DateTime exp) {
    if (exp.hour == 0 && exp.minute == 0 && exp.second == 0) {
      return DateTime(exp.year, exp.month, exp.day, 23, 59, 59);
    }
    return exp;
  }

  /// True when a product enforces a short intraday pickup window (< 24h).
  bool get hasStrictIntradayWindow =>
      minProductPickupWindowHours != null &&
      minProductPickupWindowHours! > 0 &&
      minProductPickupWindowHours! < 24;

  String get badgeTitle {
    switch (tier) {
      case BasketProductTier.perishableOnly:
        return 'Perishable Basket';
      case BasketProductTier.mixed:
        return 'Mixed Basket';
      case BasketProductTier.standard:
        return 'Standard Basket';
    }
  }

  String get shortRuleTag {
    final dayLabel = maxAdvanceDays == 1
        ? 'Up to 1 day ahead'
        : 'Up to $maxAdvanceDays days ahead';
    if (hasStrictIntradayWindow) {
      return '$dayLabel · ${minProductPickupWindowHours}h fresh window';
    }
    return dayLabel;
  }

  String get detailedNotice {
    final parts = <String>[];
    switch (tier) {
      case BasketProductTier.perishableOnly:
        parts.add(
          'Perishable items can be reserved for today or the next open day (up to $maxAdvanceDays day${maxAdvanceDays > 1 ? 's' : ''} ahead) to preserve freshness.',
        );
      case BasketProductTier.mixed:
        parts.add(
          'Your basket mixes fresh & standard items — pickup can be reserved up to $maxAdvanceDays day${maxAdvanceDays > 1 ? 's' : ''} ahead (${maxReservationHours}h window).',
        );
      case BasketProductTier.standard:
        parts.add(
          'Non-perishable items can be reserved up to $maxAdvanceDays day${maxAdvanceDays > 1 ? 's' : ''} ahead (${maxReservationHours}h window).',
        );
    }

    if (hasStrictIntradayWindow && tightestWindowProductName != null) {
      parts.add(
        '"$tightestWindowProductName" requires pickup within ${minProductPickupWindowHours}h of store opening/order.',
      );
    }

    if (earliestExpiry != null) {
      final expStr = DateFormat('MMM d').format(earliestExpiry!);
      final prodSuffix = earliestExpiryProductName != null
          ? ' ("$earliestExpiryProductName")'
          : '';
      parts.add('Bounded by batch expiry on $expStr$prodSuffix.');
    }

    return parts.join(' ');
  }
}

/// Represents a single concrete pickup slot selectable by the customer.
class PickupSlotOption {
  final DateTime startTime;
  final DateTime endTime;
  final String value;
  final String rangeLabel;
  final String dayLabel;
  final bool isExpressEligible;

  const PickupSlotOption({
    required this.startTime,
    required this.endTime,
    required this.value,
    required this.rangeLabel,
    required this.dayLabel,
    this.isExpressEligible = false,
  });

  int get durationMinutes => endTime.difference(startTime).inMinutes;
}

/// Represents a single calendar day in the customer pickup schedule selector.
class DayScheduleInfo {
  final DateTime date;
  final String shortDayLabel;
  final String dateSubtitle;
  final bool isToday;
  final bool isTomorrow;
  final bool isClosed;
  final bool isSpecialHours;
  final String? statusNote;
  final DayOperatingWindow? window;
  final List<PickupSlotOption> slots;

  const DayScheduleInfo({
    required this.date,
    required this.shortDayLabel,
    required this.dateSubtitle,
    required this.isToday,
    required this.isTomorrow,
    required this.isClosed,
    required this.isSpecialHours,
    this.statusNote,
    this.window,
    required this.slots,
  });

  bool get hasAvailableSlots => !isClosed && slots.isNotEmpty;
}

class StoreHours {
  // Default fallback hours (matches Admin StoreSettings defaults: 8:00 AM – 9:00 PM)
  static const int defaultOpenHour = 8;
  static const int defaultCloseHour = 21;
  static const int openHour = defaultOpenHour;
  static const int closeHour = defaultCloseHour;
  static const int prepBufferMinutes = 20; // 20-minute preparation buffer
  static const int minSlotDurationMinutes = 20;

  /// Checks if the store is currently within active operating/pickup hours.
  static bool isOpen({StoreSettings? settings, DateTime? nowTime}) {
    final now = nowTime ?? TimeService.now;
    if (settings != null) {
      return !settings.isClosedAt(now);
    }
    final mins = now.hour * 60 + now.minute;
    return mins >= defaultOpenHour * 60 && mins < defaultCloseHour * 60;
  }

  /// Returns ASAP express pickup label (e.g., "ASAP (Ready by ~1:32 PM)").
  static String asapPickupSlot({DateTime? nowTime}) {
    final readyTime = (nowTime ?? TimeService.now)
        .add(const Duration(minutes: prepBufferMinutes));
    final timeStr = DateFormat('h:mm a').format(readyTime);
    return 'ASAP (Ready by ~$timeStr)';
  }

  /// Resolves the effective [DayOperatingWindow] for [date], falling back to
  /// default hours (8:00 AM – 9:00 PM) when [settings] is null.
  static DayOperatingWindow? _effectiveWindowForDate(
    DateTime date,
    StoreSettings? settings,
  ) {
    if (settings != null) {
      return settings.getOperatingWindowForDate(date);
    }
    return const DayOperatingWindow(
      openMinutes: defaultOpenHour * 60,
      closeMinutes: defaultCloseHour * 60,
    );
  }

  /// Returns the next date & opening minute when the store will be open,
  /// scanning up to [maxDaysToScan] days ahead.
  static ({DateTime date, int openMinutes, String? reason})?
      getNextOpeningTime({
    StoreSettings? settings,
    DateTime? nowTime,
    int maxDaysToScan = 14,
  }) {
    if (settings != null && settings.isEmergencyClosed) return null;

    final now = nowTime ?? TimeService.now;
    final today = DateTime(now.year, now.month, now.day);

    for (int offset = 0; offset <= maxDaysToScan; offset++) {
      final candidate = today.add(Duration(days: offset));
      final window = _effectiveWindowForDate(candidate, settings);
      if (window == null) continue;

      final openDt = DateTime(
        candidate.year,
        candidate.month,
        candidate.day,
        window.openMinutes ~/ 60,
        window.openMinutes % 60,
      );
      final closeDt = DateTime(
        candidate.year,
        candidate.month,
        candidate.day,
        window.closeMinutes ~/ 60,
        window.closeMinutes % 60,
      );

      if (offset == 0) {
        if (now.isBefore(openDt)) {
          return (
            date: candidate,
            openMinutes: window.openMinutes,
            reason: window.overrideReason,
          );
        }
        // Check if currently inside a maintenance break and reopens later today
        if (now.isBefore(closeDt)) {
          final curMins = now.hour * 60 + now.minute;
          for (final b in window.blockedWindows) {
            if (curMins >= b.startMinutes &&
                curMins < b.endMinutes &&
                b.endMinutes < window.closeMinutes) {
              return (
                date: candidate,
                openMinutes: b.endMinutes,
                reason: b.reason,
              );
            }
          }
        }
      } else {
        return (
          date: candidate,
          openMinutes: window.openMinutes,
          reason: window.overrideReason,
        );
      }
    }
    return null;
  }

  /// Formats a human-readable next opening label (e.g. "Today at 1:00 PM",
  /// "Tomorrow at 8:00 AM", "Mon, Nov 30 at 8:00 AM").
  static String? formatNextOpeningLabel({
    StoreSettings? settings,
    DateTime? nowTime,
  }) {
    final next = getNextOpeningTime(settings: settings, nowTime: nowTime);
    if (next == null) return null;
    final now = nowTime ?? TimeService.now;
    final today = DateTime(now.year, now.month, now.day);
    final dayLabel = _formatDayLabel(next.date, today);
    final timeLabel = StoreSettings.formatMinutes(next.openMinutes);
    return '$dayLabel at $timeLabel';
  }

  /// Generates all valid [PickupSlotOption]s for [date] honoring Admin
  /// operating hours, custom holiday hours, maintenance windows, prep buffer,
  /// and the basket's [BasketPickupPolicy].
  static List<PickupSlotOption> getSlotsForDate(
    DateTime date, {
    StoreSettings? settings,
    BasketPickupPolicy? policy,
    DateTime? nowTime,
    bool isEarliestOpenDay = false,
  }) {
    if (settings != null && settings.isEmergencyClosed) return const [];

    final window = _effectiveWindowForDate(date, settings);
    if (window == null) return const [];

    final now = nowTime ?? TimeService.now;
    final today = DateTime(now.year, now.month, now.day);
    final normalizedDate = DateTime(date.year, date.month, date.day);
    if (normalizedDate.isBefore(today)) return const [];

    final bool isToday = normalizedDate.isAtSameMomentAs(today);
    final DateTime minReadyTime =
        now.add(const Duration(minutes: prepBufferMinutes));

    final DateTime? earliestExpiry = policy?.earliestExpiry;
    if (earliestExpiry != null) {
      final dayOpenDt = DateTime(
        normalizedDate.year,
        normalizedDate.month,
        normalizedDate.day,
        window.openMinutes ~/ 60,
        window.openMinutes % 60,
      );
      if (dayOpenDt.isAfter(earliestExpiry)) {
        return const [];
      }
    }

    // Intraday product pickup window cap (for products with explicit pickupWindowHours < 24)
    DateTime? intradayCapEnd;
    if (policy != null && policy.hasStrictIntradayWindow) {
      final int pwHours = policy.minProductPickupWindowHours!;
      final dayOpenDt = DateTime(
        normalizedDate.year,
        normalizedDate.month,
        normalizedDate.day,
        window.openMinutes ~/ 60,
        window.openMinutes % 60,
      );
      if (isToday) {
        final anchor = now.isAfter(dayOpenDt) ? now : dayOpenDt;
        intradayCapEnd = anchor.add(Duration(hours: pwHours));
      } else {
        intradayCapEnd = dayOpenDt.add(Duration(hours: pwHours));
      }
    }

    // Build contiguous open sub-intervals by subtracting blocked maintenance windows
    final openSegments = _subtractBlockedWindows(
      window.openMinutes,
      window.closeMinutes,
      window.blockedWindows,
    );

    final dayLabel = _formatDayLabel(normalizedDate, today);
    final List<PickupSlotOption> slots = [];

    for (final segment in openSegments) {
      int cursor = segment.startMinutes;
      while (cursor < segment.endMinutes) {
        final int nextCursor = math.min(cursor + 60, segment.endMinutes);
        if (nextCursor - cursor < minSlotDurationMinutes) {
          break;
        }

        final slotStart = DateTime(
          normalizedDate.year,
          normalizedDate.month,
          normalizedDate.day,
          cursor ~/ 60,
          cursor % 60,
        );
        final slotEnd = DateTime(
          normalizedDate.year,
          normalizedDate.month,
          normalizedDate.day,
          nextCursor ~/ 60,
          nextCursor % 60,
        );

        // Skip slots whose end time cannot satisfy preparation buffer
        if (isToday && !minReadyTime.isBefore(slotEnd)) {
          cursor = nextCursor;
          continue;
        }

        // Skip slots that extend past FEFO earliest product expiry
        if (earliestExpiry != null && slotEnd.isAfter(earliestExpiry)) {
          cursor = nextCursor;
          continue;
        }

        // Enforce strict intraday product pickup window if configured
        if (intradayCapEnd != null &&
            slotEnd.isAfter(intradayCapEnd) &&
            (slots.isNotEmpty || slotStart.isAfter(intradayCapEnd))) {
          cursor = nextCursor;
          continue;
        }

        final startStr = StoreSettings.formatMinutes(cursor);
        final endStr = StoreSettings.formatMinutes(nextCursor);
        final rangeLabel = '$startStr – $endStr';
        final value = '$dayLabel, $rangeLabel';

        slots.add(PickupSlotOption(
          startTime: slotStart,
          endTime: slotEnd,
          value: value,
          rangeLabel: rangeLabel,
          dayLabel: dayLabel,
          isExpressEligible: isToday &&
              slots.isEmpty &&
              !now.isBefore(slotStart) &&
              minReadyTime.isBefore(slotEnd),
        ));

        cursor = nextCursor;
      }
    }

    return slots;
  }

  /// Builds the full day-by-day pickup schedule calendar for the customer
  /// basket, connecting Admin operating hours & overrides with [policy].
  static List<DayScheduleInfo> getScheduleCalendar({
    StoreSettings? settings,
    BasketPickupPolicy? policy,
    DateTime? nowTime,
  }) {
    final now = nowTime ?? TimeService.now;
    final today = DateTime(now.year, now.month, now.day);
    final effectivePolicy =
        policy ?? BasketPickupPolicy.standard(settings: settings);

    if (settings != null && settings.isEmergencyClosed) {
      return [
        DayScheduleInfo(
          date: today,
          shortDayLabel: 'Today',
          dateSubtitle: DateFormat('MMM d').format(today),
          isToday: true,
          isTomorrow: false,
          isClosed: true,
          isSpecialHours: false,
          statusNote: settings.dayClosureReason(today) ?? 'Temporarily Closed',
          window: null,
          slots: const [],
        ),
      ];
    }

    // Determine the last calendar date allowed by the basket's product policy
    DateTime lastDate =
        today.add(Duration(days: effectivePolicy.maxAdvanceDays));
    final DateTime? expiryDay = effectivePolicy.earliestExpiry != null
        ? DateTime(
            effectivePolicy.earliestExpiry!.year,
            effectivePolicy.earliestExpiry!.month,
            effectivePolicy.earliestExpiry!.day,
          )
        : null;

    if (expiryDay != null && expiryDay.isBefore(lastDate)) {
      lastDate = expiryDay;
    }

    if (lastDate.isBefore(today)) {
      return const [];
    }

    DayScheduleInfo buildDayInfo(DateTime dayDate, bool isEarliestOpenDay) {
      final isToday = dayDate.isAtSameMomentAs(today);
      final isTomorrow = dayDate.difference(today).inDays == 1;
      final window = _effectiveWindowForDate(dayDate, settings);
      final bool isClosedDay = window == null;

      final List<PickupSlotOption> daySlots = isClosedDay
          ? const []
          : getSlotsForDate(
              dayDate,
              settings: settings,
              policy: effectivePolicy,
              nowTime: now,
              isEarliestOpenDay: isEarliestOpenDay,
            );

      String? statusNote;
      if (isClosedDay) {
        statusNote = settings?.dayClosureReason(dayDate) ?? 'Closed';
      } else if (window.isSpecialHours) {
        statusNote = window.overrideReason != null
            ? '${window.overrideReason} (${window.formattedRange})'
            : 'Special Hours (${window.formattedRange})';
      } else if (window.hasMaintenanceWindows) {
        final b = window.blockedWindows.first;
        statusNote =
            'Maintenance ${StoreSettings.formatMinutes(b.startMinutes)} – ${StoreSettings.formatMinutes(b.endMinutes)}';
      } else if (isToday && daySlots.isEmpty) {
        statusNote = 'Hours passed for today';
      }

      return DayScheduleInfo(
        date: dayDate,
        shortDayLabel: isToday
            ? 'Today'
            : (isTomorrow ? 'Tomorrow' : DateFormat('EEE').format(dayDate)),
        dateSubtitle: DateFormat('MMM d').format(dayDate),
        isToday: isToday,
        isTomorrow: isTomorrow,
        isClosed: isClosedDay,
        isSpecialHours: window?.isSpecialHours ?? false,
        statusNote: statusNote,
        window: window,
        slots: daySlots,
      );
    }

    final List<DayScheduleInfo> days = [];
    bool foundEarliestOpenWithSlots = false;

    DateTime cursor = today;
    while (!cursor.isAfter(lastDate)) {
      final info = buildDayInfo(cursor, !foundEarliestOpenWithSlots);
      if (info.hasAvailableSlots && !foundEarliestOpenWithSlots) {
        foundEarliestOpenWithSlots = true;
      }
      days.add(info);
      cursor = cursor.add(const Duration(days: 1));
    }

    // If every day in the base window had no slots purely due to a short
    // closure (e.g., Sunday rest day or 1-day holiday after closing time),
    // bridge forward by a bounded grace margin so customers can still reserve
    // for the immediate next open operating day (never exceeding product expiry).
    if (!foundEarliestOpenWithSlots) {
      final int extraGraceDays =
          effectivePolicy.tier == BasketProductTier.perishableOnly ? 1 : 3;
      DateTime extendedEnd = lastDate.add(Duration(days: extraGraceDays));
      if (expiryDay != null && expiryDay.isBefore(extendedEnd)) {
        extendedEnd = expiryDay;
      }

      while (!cursor.isAfter(extendedEnd) && !foundEarliestOpenWithSlots) {
        final info = buildDayInfo(cursor, true);
        days.add(info);
        if (info.hasAvailableSlots) {
          foundEarliestOpenWithSlots = true;
          break;
        }
        cursor = cursor.add(const Duration(days: 1));
      }
    }

    return days;
  }

  /// Calculates the earliest valid pickup date considering Admin operating
  /// hours, overrides, and product policy.
  static DateTime getEarliestPickupDate({
    StoreSettings? settings,
    BasketPickupPolicy? policy,
    DateTime? nowTime,
  }) {
    final now = nowTime ?? TimeService.now;
    final today = DateTime(now.year, now.month, now.day);
    final calendar = getScheduleCalendar(
      settings: settings,
      policy: policy,
      nowTime: now,
    );
    for (final day in calendar) {
      if (day.hasAvailableSlots) {
        return day.date;
      }
    }
    return today.add(const Duration(days: 1));
  }

  /// Returns the earliest valid [PickupSlotOption] for the basket & settings,
  /// or `null` if no valid pickup slots exist within the product policy window.
  static PickupSlotOption? getDefaultSlotOption({
    StoreSettings? settings,
    BasketPickupPolicy? policy,
    DateTime? nowTime,
  }) {
    final calendar = getScheduleCalendar(
      settings: settings,
      policy: policy,
      nowTime: nowTime,
    );
    for (final day in calendar) {
      if (day.hasAvailableSlots) {
        return day.slots.first;
      }
    }
    return null;
  }

  /// Returns the default formatted pickup slot string respecting Admin
  /// operating hours, schedule overrides, and basket product policy.
  static String defaultPickupSlot({
    StoreSettings? settings,
    BasketPickupPolicy? policy,
    DateTime? nowTime,
  }) {
    final option = getDefaultSlotOption(
      settings: settings,
      policy: policy,
      nowTime: nowTime,
    );
    if (option != null) return option.value;

    // Fallback label if no slots are currently available
    final now = nowTime ?? TimeService.now;
    final nextOpen = getNextOpeningTime(settings: settings, nowTime: now);
    if (nextOpen != null) {
      final today = DateTime(now.year, now.month, now.day);
      final dayLabel = _formatDayLabel(nextOpen.date, today);
      final window = _effectiveWindowForDate(nextOpen.date, settings);
      final endMins = math.min(
        nextOpen.openMinutes + 60,
        window?.closeMinutes ?? (nextOpen.openMinutes + 60),
      );
      return '$dayLabel, ${StoreSettings.formatMinutes(nextOpen.openMinutes)} – ${StoreSettings.formatMinutes(endMins)}';
    }
    return 'No pickup slots available';
  }

  /// Validates whether [slotStr] is currently a valid, un-expired pickup slot
  /// under the live Admin [settings] and basket [policy].
  static bool isSlotValidForSettings(
    String slotStr, {
    StoreSettings? settings,
    BasketPickupPolicy? policy,
    DateTime? nowTime,
  }) {
    if (slotStr.trim().isEmpty || slotStr == 'No pickup slots available') {
      return false;
    }
    if (settings != null && settings.isEmergencyClosed) return false;
    if (isSlotExpired(slotStr, settings: settings, nowTime: nowTime)) {
      return false;
    }

    final calendar = getScheduleCalendar(
      settings: settings,
      policy: policy,
      nowTime: nowTime,
    );
    for (final day in calendar) {
      for (final slot in day.slots) {
        if (slot.value == slotStr) {
          return true;
        }
      }
    }
    return false;
  }

  /// Checks whether a formatted pickup slot string has passed its usable window.
  static bool isSlotExpired(
    String slotStr, {
    StoreSettings? settings,
    DateTime? nowTime,
  }) {
    if (slotStr.trim().isEmpty || slotStr == 'No pickup slots available') {
      return true;
    }
    if (slotStr.contains('ASAP')) {
      return !isOpen(settings: settings, nowTime: nowTime);
    }

    final now = nowTime ?? TimeService.now;
    try {
      final parsed = _splitDateAndTimeRange(slotStr);
      if (parsed == null) return false;

      final rangeParts = parsed.timeRange.split(RegExp(r'\s*[\-–—]\s*'));
      final endTimePart =
          (rangeParts.length > 1 ? rangeParts[1] : rangeParts[0]).trim();
      final parsedEndTime = DateFormat('h:mm a').parse(endTimePart);
      final baseDate = _parseBaseDate(parsed.datePart, now);

      final slotEndTime = DateTime(
        baseDate.year,
        baseDate.month,
        baseDate.day,
        parsedEndTime.hour,
        parsedEndTime.minute,
      );

      return !now
          .add(const Duration(minutes: prepBufferMinutes))
          .isBefore(slotEndTime);
    } catch (_) {
      return false;
    }
  }

  /// Parses a pickup slot string into the START [DateTime] of the slot.
  static DateTime parseSlotTargetDateTime(String slotStr, {DateTime? nowTime}) {
    final now = nowTime ?? TimeService.now;
    if (slotStr.contains('ASAP')) {
      return now.add(const Duration(minutes: prepBufferMinutes));
    }

    try {
      final parsed = _splitDateAndTimeRange(slotStr);
      if (parsed == null) {
        return now.add(const Duration(minutes: prepBufferMinutes));
      }

      final startTimePart =
          parsed.timeRange.split(RegExp(r'\s*[\-–—]\s*'))[0].trim();
      final parsedTime = DateFormat('h:mm a').parse(startTimePart);
      final baseDate = _parseBaseDate(parsed.datePart, now);

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

  /// Parses a pickup slot string into the END [DateTime] of the slot.
  static DateTime parseSlotEndDateTime(String slotStr, {DateTime? nowTime}) {
    final now = nowTime ?? TimeService.now;
    if (slotStr.contains('ASAP')) {
      return now.add(const Duration(minutes: prepBufferMinutes));
    }

    try {
      final parsed = _splitDateAndTimeRange(slotStr);
      if (parsed == null) {
        return now.add(const Duration(minutes: prepBufferMinutes));
      }

      final rangeParts = parsed.timeRange.split(RegExp(r'\s*[\-–—]\s*'));
      final endTimePart =
          (rangeParts.length > 1 ? rangeParts[1] : rangeParts[0]).trim();
      final parsedEndTime = DateFormat('h:mm a').parse(endTimePart);
      final baseDate = _parseBaseDate(parsed.datePart, now);

      final targetEnd = DateTime(
        baseDate.year,
        baseDate.month,
        baseDate.day,
        parsedEndTime.hour,
        parsedEndTime.minute,
      );

      if (targetEnd.isBefore(now)) {
        return now.add(const Duration(minutes: prepBufferMinutes));
      }

      return targetEnd;
    } catch (_) {
      return now.add(const Duration(minutes: prepBufferMinutes));
    }
  }

  /// Returns allowed pickup dates up to [maxHours] (or [policy]), bounded by
  /// [earliestExpiry] and skipping closed days.
  static List<DateTime> getAvailableDates({
    int maxHours = 72,
    DateTime? earliestExpiry,
    StoreSettings? settings,
    BasketPickupPolicy? policy,
    DateTime? nowTime,
  }) {
    final effectivePolicy = policy ??
        BasketPickupPolicy(
          tier: BasketProductTier.standard,
          hasPerishables: false,
          onlyPerishables: false,
          maxAdvanceDays: (maxHours / 24).ceil().clamp(1, 14),
          maxReservationHours: maxHours,
          holdWindowHours: maxHours,
          earliestExpiry: earliestExpiry != null
              ? BasketPickupPolicy._normalizeExpiry(earliestExpiry)
              : null,
        );
    final calendar = getScheduleCalendar(
      settings: settings,
      policy: effectivePolicy,
      nowTime: nowTime,
    );
    return calendar
        .where((d) => d.hasAvailableSlots)
        .map((d) => d.date)
        .toList();
  }

  /// Legacy map-based helper preserved for compatibility, now backed by
  /// dynamic Admin [StoreSettings].
  static List<Map<String, dynamic>> getTimeSlotsForDate(
    DateTime date, {
    int maxHours = 72,
    DateTime? earliestExpiry,
    StoreSettings? settings,
    DateTime? nowTime,
  }) {
    final policy = BasketPickupPolicy(
      tier: BasketProductTier.standard,
      hasPerishables: false,
      onlyPerishables: false,
      maxAdvanceDays: (maxHours / 24).ceil().clamp(1, 14),
      maxReservationHours: maxHours,
      holdWindowHours: maxHours,
      earliestExpiry: earliestExpiry != null
          ? BasketPickupPolicy._normalizeExpiry(earliestExpiry)
          : null,
    );
    final slots = getSlotsForDate(
      date,
      settings: settings,
      policy: policy,
      nowTime: nowTime,
    );
    return slots
        .map((s) => {
              'dateTime': s.startTime,
              'hour': s.startTime.hour,
              'timeLabel': StoreSettings.formatMinutes(
                s.startTime.hour * 60 + s.startTime.minute,
              ),
              'rangeLabel': s.rangeLabel,
              'value': s.value,
            })
        .toList();
  }

  static List<Map<String, dynamic>> availableSlots({
    int maxHours = 72,
    DateTime? earliestExpiry,
    StoreSettings? settings,
    BasketPickupPolicy? policy,
    DateTime? nowTime,
  }) {
    final effectivePolicy = policy ??
        BasketPickupPolicy(
          tier: BasketProductTier.standard,
          hasPerishables: false,
          onlyPerishables: false,
          maxAdvanceDays: (maxHours / 24).ceil().clamp(1, 14),
          maxReservationHours: maxHours,
          holdWindowHours: maxHours,
          earliestExpiry: earliestExpiry != null
              ? BasketPickupPolicy._normalizeExpiry(earliestExpiry)
              : null,
        );
    final calendar = getScheduleCalendar(
      settings: settings,
      policy: effectivePolicy,
      nowTime: nowTime,
    );

    final List<Map<String, dynamic>> allSlots = [];
    for (final day in calendar) {
      if (!day.hasAvailableSlots) continue;
      for (final slot in day.slots) {
        allSlots.add({
          'value': slot.value,
          'label':
              '${day.shortDayLabel} (${day.dateSubtitle}): ${slot.rangeLabel}',
          'isPast': false,
          'hour': slot.startTime.hour,
          'day': day.shortDayLabel,
          'dateLabel': day.dateSubtitle,
        });
      }
    }
    return allSlots;
  }

  // ── Internal Helpers ───────────────────────────────────────────────────────

  /// Splits `"Fri, Nov 27, 8:00 AM – 9:00 AM"` cleanly on the LAST comma so
  /// dates containing a comma (like `"Fri, Nov 27"`) parse accurately.
  static ({String datePart, String timeRange})? _splitDateAndTimeRange(
      String slotStr) {
    final lastComma = slotStr.lastIndexOf(',');
    if (lastComma <= 0 || lastComma >= slotStr.length - 1) return null;
    final datePart = slotStr.substring(0, lastComma).trim();
    final timeRange = slotStr.substring(lastComma + 1).trim();
    if (datePart.isEmpty || timeRange.isEmpty) return null;
    return (datePart: datePart, timeRange: timeRange);
  }

  static String _formatDayLabel(DateTime date, DateTime today) {
    final d = DateTime(date.year, date.month, date.day);
    final diff = d.difference(today).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    return DateFormat('EEE, MMM d').format(d);
  }

  static DateTime _parseBaseDate(String datePart, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final clean = datePart.trim();
    if (clean == 'Today') return today;
    if (clean == 'Tomorrow') return today.add(const Duration(days: 1));

    const dayNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    final idx = dayNames.indexOf(clean);
    if (idx != -1) {
      final int targetWeekday = idx + 1;
      int daysAhead = targetWeekday - today.weekday;
      if (daysAhead < 0) daysAhead += 7;
      return today.add(Duration(days: daysAhead));
    }

    for (final pattern in const ['EEE, MMM d', 'EEEE, MMM d', 'MMM d']) {
      try {
        final parsed = DateFormat(pattern).parse(clean);
        DateTime base = DateTime(now.year, parsed.month, parsed.day);
        if (base.isBefore(today.subtract(const Duration(days: 30)))) {
          base = DateTime(now.year + 1, parsed.month, parsed.day);
        }
        return base;
      } catch (_) {}
    }

    return today;
  }

  static List<({int startMinutes, int endMinutes})> _subtractBlockedWindows(
    int openMinutes,
    int closeMinutes,
    List<({int startMinutes, int endMinutes, String reason})> blockedWindows,
  ) {
    if (blockedWindows.isEmpty) {
      return [(startMinutes: openMinutes, endMinutes: closeMinutes)];
    }

    final sorted = List.of(blockedWindows)
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

    final segments = <({int startMinutes, int endMinutes})>[];
    int current = openMinutes;

    for (final b in sorted) {
      final bStart = b.startMinutes.clamp(openMinutes, closeMinutes);
      final bEnd = b.endMinutes.clamp(openMinutes, closeMinutes);
      if (bEnd <= current) continue;
      if (bStart > current) {
        segments.add((startMinutes: current, endMinutes: bStart));
      }
      current = math.max(current, bEnd);
    }

    if (current < closeMinutes) {
      segments.add((startMinutes: current, endMinutes: closeMinutes));
    }

    return segments;
  }
}
