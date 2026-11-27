import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/time_service.dart';

enum OverrideType {
  fullClosure, // e.g., Dec 24 - Jan 1: Closed All Day ("Holidays")
  customOpenHours, // e.g., Dec 20 - Dec 23: Open 1:00 PM - 3:00 PM ("Preparing for Holidays")
  maintenanceWindow, // e.g., Dec 20 - Dec 23: Closed 1:00 PM - 3:00 PM for maintenance
}

class ScheduleOverride {
  final String id;
  final DateTime startDate;
  final DateTime endDate;
  final OverrideType type;
  final int? startMinutes; // Minutes from midnight (e.g. 780 = 1:00 PM)
  final int? endMinutes; // Minutes from midnight (e.g. 900 = 3:00 PM)
  final String reason;

  const ScheduleOverride({
    required this.id,
    required this.startDate,
    required this.endDate,
    required this.type,
    this.startMinutes,
    this.endMinutes,
    required this.reason,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'type': type.name,
        'startMinutes': startMinutes,
        'endMinutes': endMinutes,
        'reason': reason,
      };

  factory ScheduleOverride.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.tryParse(val) ?? TimeService.now;
      return TimeService.now;
    }

    return ScheduleOverride(
      id: map['id']?.toString() ?? '',
      startDate: parseDate(map['startDate']),
      endDate: parseDate(map['endDate']),
      type: OverrideType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => OverrideType.fullClosure,
      ),
      startMinutes: (map['startMinutes'] as num?)?.toInt(),
      endMinutes: (map['endMinutes'] as num?)?.toInt(),
      reason: map['reason']?.toString() ?? '',
    );
  }

  /// Checks whether [date] falls inside this override's calendar date range.
  bool appliesToDate(DateTime date) {
    final dayStart = DateTime(startDate.year, startDate.month, startDate.day);
    final dayEnd =
        DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
    return !date.isBefore(dayStart) && !date.isAfter(dayEnd);
  }

  /// Checks whether a specific moment [checkTime] is blocked by this override.
  bool isDateTimeClosed(DateTime checkTime) {
    if (!appliesToDate(checkTime)) return false;

    if (type == OverrideType.fullClosure) {
      return true;
    }

    final int checkMins = checkTime.hour * 60 + checkTime.minute;
    final int sMins = startMinutes ?? 0;
    final int eMins = endMinutes ?? 1439;

    if (type == OverrideType.customOpenHours) {
      return checkMins < sMins || checkMins >= eMins;
    } else {
      return checkMins >= sMins && checkMins < eMins;
    }
  }

  String get typeLabel {
    switch (type) {
      case OverrideType.fullClosure:
        return 'Closed All Day';
      case OverrideType.customOpenHours:
        return 'Special Open Hours';
      case OverrideType.maintenanceWindow:
        return 'Maintenance Window';
    }
  }

  String formatTimeRange() {
    if (type == OverrideType.fullClosure) return 'Closed All Day';
    final sMins = startMinutes ?? 0;
    final eMins = endMinutes ?? 1439;
    return '${StoreSettings.formatMinutes(sMins)} – ${StoreSettings.formatMinutes(eMins)}';
  }
}

/// Represents the effective operating window for a single calendar date,
/// combining regular daily operating hours with any active schedule overrides.
class DayOperatingWindow {
  final int openMinutes;
  final int closeMinutes;
  final List<({int startMinutes, int endMinutes, String reason})>
      blockedWindows;
  final String? overrideReason;
  final OverrideType? overrideType;

  const DayOperatingWindow({
    required this.openMinutes,
    required this.closeMinutes,
    this.blockedWindows = const [],
    this.overrideReason,
    this.overrideType,
  });

  bool get isSpecialHours => overrideType == OverrideType.customOpenHours;
  bool get hasMaintenanceWindows => blockedWindows.isNotEmpty;

  String get formattedRange =>
      '${StoreSettings.formatMinutes(openMinutes)} – ${StoreSettings.formatMinutes(closeMinutes)}';
}

class StoreSettings {
  static const String defaultOpenTimeStr = '08:00';
  static const String defaultCloseTimeStr = '21:00';
  static const int defaultOpenMinutes = 8 * 60; // 8:00 AM
  static const int defaultCloseMinutes = 21 * 60; // 9:00 PM

  final bool isClosed;
  final String? closureMessage;
  final DateTime? scheduledCloseAt;
  final DateTime? scheduledOpenAt;
  final DateTime? updatedAt;

  // Admin-synced Operating Hours & Schedule Overrides
  final bool operatingHoursEnabled;
  final String? dailyOpenTime; // "HH:mm", e.g. "08:00"
  final String? dailyCloseTime; // "HH:mm", e.g. "21:00"
  final List<int> closedDaysOfWeek; // 1 = Mon ... 7 = Sun
  final List<ScheduleOverride> overrides;

  // Expiration / reservation windows in hours (Admin configurable)
  final int perishableWindowHours;
  final int mixedWindowHours;
  final int standardWindowHours;

  // Global Thresholds & Master Data
  final int globalLowStockThreshold;
  final List<String> masterCategories;
  final String? announcement;
  final String websiteUrl;

  const StoreSettings({
    required this.isClosed,
    this.closureMessage,
    this.scheduledCloseAt,
    this.scheduledOpenAt,
    this.updatedAt,
    this.operatingHoursEnabled = false,
    this.dailyOpenTime = defaultOpenTimeStr,
    this.dailyCloseTime = defaultCloseTimeStr,
    this.closedDaysOfWeek = const [],
    this.overrides = const [],
    this.perishableWindowHours = 2,
    this.mixedWindowHours = 24,
    this.standardWindowHours = 72,
    this.globalLowStockThreshold = 5,
    this.masterCategories = const [
      'Fresh',
      'Grains',
      'Snacks',
      'Beverages',
      'Canned Goods',
      'Personal Care',
      'Condiments',
      'Others'
    ],
    this.announcement,
    this.websiteUrl = 'https://gdc-sari-sari.web.app',
  });

  factory StoreSettings.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    final rawOverrides = d['overrides'] as List?;
    final overridesList = rawOverrides != null
        ? rawOverrides
            .whereType<Map>()
            .map((item) =>
                ScheduleOverride.fromMap(Map<String, dynamic>.from(item)))
            .toList()
        : const <ScheduleOverride>[];

    final rawClosedDays = d['closedDaysOfWeek'] as List?;
    final closedDays = rawClosedDays != null
        ? rawClosedDays.map((e) => (e as num).toInt()).toList()
        : const <int>[];

    return StoreSettings(
      isClosed: d['isClosed'] == true,
      closureMessage: d['closureMessage']?.toString(),
      scheduledCloseAt: (d['scheduledCloseAt'] as Timestamp?)?.toDate(),
      scheduledOpenAt: (d['scheduledOpenAt'] as Timestamp?)?.toDate(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
      operatingHoursEnabled: d['operatingHoursEnabled'] == true,
      dailyOpenTime: d['dailyOpenTime']?.toString() ?? defaultOpenTimeStr,
      dailyCloseTime: d['dailyCloseTime']?.toString() ?? defaultCloseTimeStr,
      closedDaysOfWeek: closedDays,
      overrides: overridesList,
      perishableWindowHours: (d['perishableWindowHours'] as num?)?.toInt() ?? 2,
      mixedWindowHours: (d['mixedWindowHours'] as num?)?.toInt() ?? 24,
      standardWindowHours: (d['standardWindowHours'] as num?)?.toInt() ?? 72,
      globalLowStockThreshold:
          (d['globalLowStockThreshold'] as num? ?? 5).toInt(),
      masterCategories: List<String>.from(d['masterCategories'] ??
          const [
            'Fresh',
            'Grains',
            'Snacks',
            'Beverages',
            'Canned Goods',
            'Personal Care',
            'Condiments',
            'Others'
          ]),
      announcement: d['announcement']?.toString(),
      websiteUrl: d['websiteUrl'] as String? ?? 'https://gdc-sari-sari.web.app',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'isClosed': isClosed,
        'closureMessage': closureMessage,
        'scheduledCloseAt': scheduledCloseAt != null
            ? Timestamp.fromDate(scheduledCloseAt!)
            : null,
        'scheduledOpenAt': scheduledOpenAt != null
            ? Timestamp.fromDate(scheduledOpenAt!)
            : null,
        'operatingHoursEnabled': operatingHoursEnabled,
        'dailyOpenTime': dailyOpenTime,
        'dailyCloseTime': dailyCloseTime,
        'closedDaysOfWeek': closedDaysOfWeek,
        'overrides': overrides.map((o) => o.toMap()).toList(),
        'updatedAt': updatedAt != null
            ? Timestamp.fromDate(updatedAt!)
            : FieldValue.serverTimestamp(),
        'perishableWindowHours': perishableWindowHours,
        'mixedWindowHours': mixedWindowHours,
        'standardWindowHours': standardWindowHours,
        'globalLowStockThreshold': globalLowStockThreshold,
        'masterCategories': masterCategories,
        'announcement': announcement,
        'websiteUrl': websiteUrl,
      };

  StoreSettings copyWith({
    bool? isClosed,
    String? closureMessage,
    DateTime? scheduledCloseAt,
    DateTime? scheduledOpenAt,
    DateTime? updatedAt,
    bool? operatingHoursEnabled,
    String? dailyOpenTime,
    String? dailyCloseTime,
    List<int>? closedDaysOfWeek,
    List<ScheduleOverride>? overrides,
    int? perishableWindowHours,
    int? mixedWindowHours,
    int? standardWindowHours,
    int? globalLowStockThreshold,
    List<String>? masterCategories,
    String? announcement,
    String? websiteUrl,
  }) =>
      StoreSettings(
        isClosed: isClosed ?? this.isClosed,
        closureMessage: closureMessage ?? this.closureMessage,
        scheduledCloseAt: scheduledCloseAt ?? this.scheduledCloseAt,
        scheduledOpenAt: scheduledOpenAt ?? this.scheduledOpenAt,
        updatedAt: updatedAt ?? this.updatedAt,
        operatingHoursEnabled:
            operatingHoursEnabled ?? this.operatingHoursEnabled,
        dailyOpenTime: dailyOpenTime ?? this.dailyOpenTime,
        dailyCloseTime: dailyCloseTime ?? this.dailyCloseTime,
        closedDaysOfWeek: closedDaysOfWeek ?? this.closedDaysOfWeek,
        overrides: overrides ?? this.overrides,
        perishableWindowHours:
            perishableWindowHours ?? this.perishableWindowHours,
        mixedWindowHours: mixedWindowHours ?? this.mixedWindowHours,
        standardWindowHours: standardWindowHours ?? this.standardWindowHours,
        globalLowStockThreshold:
            globalLowStockThreshold ?? this.globalLowStockThreshold,
        masterCategories: masterCategories ?? this.masterCategories,
        announcement: announcement ?? this.announcement,
        websiteUrl: websiteUrl ?? this.websiteUrl,
      );

  // ── Time Parsing & Formatting Helpers ──────────────────────────────────────

  static int? parseTimeMinutes(String? timeStr) {
    if (timeStr == null || timeStr.trim().isEmpty) return null;
    try {
      final parts = timeStr.trim().split(':');
      if (parts.length < 2) return null;
      final h = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      if (h < 0 || h > 23 || m < 0 || m > 59) return null;
      return h * 60 + m;
    } catch (_) {
      return null;
    }
  }

  static String formatMinutes(int totalMinutes) {
    final clamped = totalMinutes.clamp(0, 24 * 60);
    final h = (clamped ~/ 60) % 24;
    final m = clamped % 60;
    final period = h >= 12 ? 'PM' : 'AM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    final mStr = m.toString().padLeft(2, '0');
    return '$h12:$mStr $period';
  }

  static String formatTimeStr(String? timeStr, {String fallback = ''}) {
    final mins = parseTimeMinutes(timeStr);
    if (mins == null) return fallback.isNotEmpty ? fallback : (timeStr ?? '');
    return formatMinutes(mins);
  }

  int get dailyOpenMinutes =>
      parseTimeMinutes(dailyOpenTime) ?? defaultOpenMinutes;

  int get dailyCloseMinutes {
    final parsed = parseTimeMinutes(dailyCloseTime) ?? defaultCloseMinutes;
    return parsed > dailyOpenMinutes ? parsed : defaultCloseMinutes;
  }

  String get formattedOpenTime => formatMinutes(dailyOpenMinutes);
  String get formattedCloseTime => formatMinutes(dailyCloseMinutes);
  String get formattedDailyHours => '$formattedOpenTime – $formattedCloseTime';

  bool get isEmergencyClosed => isClosed;

  // ── Override & Day-Schedule Resolution ─────────────────────────────────────

  List<ScheduleOverride> overridesForDate(DateTime date) {
    return overrides.where((o) => o.appliesToDate(date)).toList();
  }

  /// Returns the highest-priority active override for [date] if any
  /// (fullClosure > customOpenHours > maintenanceWindow).
  ScheduleOverride? activeOverrideFor(DateTime date) {
    final matching = overridesForDate(date);
    if (matching.isEmpty) return null;
    for (final o in matching) {
      if (o.type == OverrideType.fullClosure) return o;
    }
    for (final o in matching) {
      if (o.type == OverrideType.customOpenHours) return o;
    }
    return matching.first;
  }

  /// Returns the effective operating window for [date], or `null` if the store
  /// is closed for the entire day.
  DayOperatingWindow? getOperatingWindowForDate(DateTime date) {
    if (isClosed) return null;

    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = DateTime(date.year, date.month, date.day, 23, 59, 59);

    final matchingOverrides = overridesForDate(date);

    // 1. Full closure override blocks the entire day
    for (final o in matchingOverrides) {
      if (o.type == OverrideType.fullClosure) {
        return null;
      }
    }

    // 2. Check full-day scheduledCloseAt..scheduledOpenAt outage
    final sClose = scheduledCloseAt;
    final sOpen = scheduledOpenAt;
    if (sClose != null && sOpen != null) {
      if (!sClose.isAfter(dayStart) && !sOpen.isBefore(dayEnd)) {
        return null;
      }
    }

    // 3. Determine base open/close minutes (customOpenHours overrides regular hours & closedDaysOfWeek)
    int openMins = dailyOpenMinutes;
    int closeMins = dailyCloseMinutes;
    String? overrideReason;
    OverrideType? overrideType;

    ScheduleOverride? customHoursOverride;
    for (final o in matchingOverrides) {
      if (o.type == OverrideType.customOpenHours) {
        customHoursOverride = o;
        break;
      }
    }

    if (customHoursOverride != null) {
      openMins = customHoursOverride.startMinutes ?? openMins;
      closeMins = customHoursOverride.endMinutes ?? closeMins;
      overrideReason = customHoursOverride.reason.trim().isNotEmpty
          ? customHoursOverride.reason.trim()
          : 'Special Operating Hours';
      overrideType = OverrideType.customOpenHours;
    } else if (operatingHoursEnabled &&
        closedDaysOfWeek.contains(date.weekday)) {
      return null;
    }

    if (closeMins <= openMins) {
      return null;
    }

    // 4. Collect any maintenance windows or partial scheduled outages on this day
    final blocked = <({int startMinutes, int endMinutes, String reason})>[];
    for (final o in matchingOverrides) {
      if (o.type == OverrideType.maintenanceWindow) {
        final s = o.startMinutes ?? openMins;
        final e = o.endMinutes ?? closeMins;
        if (e > s) {
          blocked.add((
            startMinutes: s,
            endMinutes: e,
            reason: o.reason.trim().isNotEmpty
                ? o.reason.trim()
                : 'Scheduled Maintenance',
          ));
          overrideReason ??= o.reason.trim().isNotEmpty
              ? o.reason.trim()
              : 'Scheduled Maintenance';
          overrideType ??= OverrideType.maintenanceWindow;
        }
      }
    }

    if (sClose != null &&
        sOpen != null &&
        sClose.isBefore(dayEnd) &&
        sOpen.isAfter(dayStart)) {
      final int startM =
          sClose.isBefore(dayStart) ? 0 : (sClose.hour * 60 + sClose.minute);
      final int endM =
          sOpen.isAfter(dayEnd) ? 24 * 60 : (sOpen.hour * 60 + sOpen.minute);
      if (endM > startM) {
        blocked.add((
          startMinutes: startM,
          endMinutes: endM,
          reason: (closureMessage != null && closureMessage!.trim().isNotEmpty)
              ? closureMessage!.trim()
              : 'Scheduled Closure',
        ));
      }
    }

    return DayOperatingWindow(
      openMinutes: openMins,
      closeMinutes: closeMins,
      blockedWindows: blocked,
      overrideReason: overrideReason,
      overrideType: overrideType,
    );
  }

  /// Returns `true` if the store has no operating hours at all on [date].
  bool isDayClosed(DateTime date) => getOperatingWindowForDate(date) == null;

  /// Human-readable reason why [date] is closed all day, or `null` if open.
  String? dayClosureReason(DateTime date) {
    if (isClosed) {
      final raw = closureMessage?.trim() ?? '';
      return raw.isNotEmpty ? raw : 'Emergency Maintenance';
    }
    for (final o in overridesForDate(date)) {
      if (o.type == OverrideType.fullClosure) {
        return o.reason.trim().isNotEmpty ? o.reason.trim() : 'Holiday Closure';
      }
    }
    if (operatingHoursEnabled && closedDaysOfWeek.contains(date.weekday)) {
      return 'Closed on ${DateFormat('EEEE').format(date)}s';
    }
    final sClose = scheduledCloseAt;
    final sOpen = scheduledOpenAt;
    if (sClose != null && sOpen != null) {
      final dayStart = DateTime(date.year, date.month, date.day);
      final dayEnd = DateTime(date.year, date.month, date.day, 23, 59, 59);
      if (!sClose.isAfter(dayStart) && !sOpen.isBefore(dayEnd)) {
        return (closureMessage != null && closureMessage!.trim().isNotEmpty)
            ? closureMessage!.trim()
            : 'Scheduled Closure';
      }
    }
    return null;
  }

  /// Returns the closing [DateTime] for [date] based on active schedule/overrides.
  DateTime? closingDateTimeForDate(DateTime date) {
    final window = getOperatingWindowForDate(date);
    if (window == null) return null;
    final h = window.closeMinutes ~/ 60;
    final m = window.closeMinutes % 60;
    return DateTime(date.year, date.month, date.day, h, m);
  }

  String closingTimeLabelForDate(DateTime date) {
    final window = getOperatingWindowForDate(date);
    if (window == null) return formattedCloseTime;
    return formatMinutes(window.closeMinutes);
  }

  /// Evaluates manual emergency closure, scheduled overrides, scheduled outage,
  /// and daily operating hours at [checkTime].
  bool isClosedAt(DateTime checkTime) {
    if (isClosed) return true;

    // 1. Scheduled Overrides take precedence
    final matchingOverrides = overridesForDate(checkTime);
    for (final o in matchingOverrides) {
      if (o.type == OverrideType.fullClosure) return true;
    }
    for (final o in matchingOverrides) {
      if (o.type == OverrideType.customOpenHours) {
        if (o.isDateTimeClosed(checkTime)) return true;
      }
    }
    for (final o in matchingOverrides) {
      if (o.type == OverrideType.maintenanceWindow) {
        if (o.isDateTimeClosed(checkTime)) return true;
      }
    }

    // 2. Scheduled Outage
    final sClose = scheduledCloseAt;
    final sOpen = scheduledOpenAt;
    if (sClose != null && sOpen != null) {
      if (checkTime.isAfter(sClose) && checkTime.isBefore(sOpen)) {
        return true;
      }
    }

    // 3. Daily Operating Hours & Closed Days
    final bool hasCustomOpenOverride =
        matchingOverrides.any((o) => o.type == OverrideType.customOpenHours);
    if (!hasCustomOpenOverride) {
      if (operatingHoursEnabled &&
          closedDaysOfWeek.contains(checkTime.weekday)) {
        return true;
      }
      final curMins = checkTime.hour * 60 + checkTime.minute;
      if (curMins < dailyOpenMinutes || curMins >= dailyCloseMinutes) {
        return true;
      }
    }

    return false;
  }

  bool get effectivelyClosed => isClosedAt(TimeService.now);

  String closureReasonAt(DateTime checkTime) {
    if (isClosed) {
      final String rawMsg = closureMessage?.trim() ?? '';
      final String reasonText = rawMsg.isNotEmpty
          ? rawMsg
          : 'Store is temporarily under maintenance.';
      final DateTime time = updatedAt ?? scheduledCloseAt ?? checkTime;
      final String formattedTime = DateFormat('MMM d, h:mm a').format(time);
      return '$formattedTime — $reasonText';
    }

    final matchingOverrides = overridesForDate(checkTime);
    for (final o in matchingOverrides) {
      final reason = o.reason.trim().isNotEmpty
          ? o.reason.trim()
          : 'Holiday / Special Schedule';
      if (o.type == OverrideType.fullClosure) {
        return 'Closed today: $reason.';
      }
      if (o.type == OverrideType.customOpenHours &&
          o.isDateTimeClosed(checkTime)) {
        return '$reason (Open ${o.formatTimeRange()} only).';
      }
      if (o.type == OverrideType.maintenanceWindow &&
          o.isDateTimeClosed(checkTime)) {
        return 'Maintenance break: $reason (${o.formatTimeRange()}).';
      }
    }

    final sClose = scheduledCloseAt;
    final sOpen = scheduledOpenAt;
    if (sClose != null && sOpen != null) {
      if (checkTime.isAfter(sClose) && checkTime.isBefore(sOpen)) {
        final reopens = DateFormat('MMM d, h:mm a').format(sOpen);
        return (closureMessage != null && closureMessage!.trim().isNotEmpty)
            ? closureMessage!.trim()
            : 'Scheduled closure active until $reopens.';
      }
    }

    if (operatingHoursEnabled && closedDaysOfWeek.contains(checkTime.weekday)) {
      return 'Store is closed on ${DateFormat('EEEE').format(checkTime)}s.';
    }

    final curMins = checkTime.hour * 60 + checkTime.minute;
    if (curMins < dailyOpenMinutes || curMins >= dailyCloseMinutes) {
      return 'Outside store hours ($formattedDailyHours). You can still reserve pickup for open hours.';
    }

    return 'Store is open for pickup orders.';
  }

  String get closureReason => closureReasonAt(TimeService.now);

  /// Concise summary of today's operating status & hours for cards/banners.
  String todayHoursSummary({DateTime? nowTime}) {
    final now = nowTime ?? TimeService.now;
    if (isClosed) {
      final raw = closureMessage?.trim() ?? '';
      return raw.isNotEmpty ? 'Closed · $raw' : 'Temporarily Closed';
    }
    final window = getOperatingWindowForDate(now);
    if (window == null) {
      final reason = dayClosureReason(now);
      return reason != null ? 'Closed Today · $reason' : 'Closed Today';
    }
    if (window.isSpecialHours) {
      final reason = window.overrideReason;
      return reason != null
          ? 'Special Hours: ${window.formattedRange} ($reason)'
          : 'Special Hours: ${window.formattedRange}';
    }
    final isOpenNow = !isClosedAt(now);
    if (isOpenNow) {
      return 'Open today until ${formatMinutes(window.closeMinutes)}';
    }
    final curMins = now.hour * 60 + now.minute;
    if (curMins < window.openMinutes) {
      return 'Opens today at ${formatMinutes(window.openMinutes)}';
    }
    return 'Closed · Regular hours ${window.formattedRange}';
  }

  /// Human-readable regular operating schedule summary (e.g. "Daily, 8:00 AM – 9:00 PM").
  String get regularHoursSummary {
    if (!operatingHoursEnabled || closedDaysOfWeek.isEmpty) {
      return 'Open Daily, $formattedDailyHours';
    }
    const dayAbbr = {
      1: 'Mon',
      2: 'Tue',
      3: 'Wed',
      4: 'Thu',
      5: 'Fri',
      6: 'Sat',
      7: 'Sun',
    };
    final openDays = [1, 2, 3, 4, 5, 6, 7]
        .where((d) => !closedDaysOfWeek.contains(d))
        .toList();
    if (openDays.isEmpty) {
      return 'Closed per schedule';
    }
    if (openDays.length == 7) {
      return 'Open Daily, $formattedDailyHours';
    }
    final closedNames = closedDaysOfWeek
        .where((d) => dayAbbr.containsKey(d))
        .map((d) => dayAbbr[d]!)
        .join(', ');
    return '$formattedDailyHours (Closed $closedNames)';
  }
}
