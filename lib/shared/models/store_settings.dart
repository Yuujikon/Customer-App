import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../services/time_service.dart';

enum OverrideType {
  fullClosure,
  customOpenHours,
  maintenanceWindow,
}

class ScheduleOverride {
  final String id;
  final DateTime startDate;
  final DateTime endDate;
  final OverrideType type;
  final int? startMinutes;
  final int? endMinutes;
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

  bool appliesToDate(DateTime date) {
    final dayStart = DateTime(startDate.year, startDate.month, startDate.day);
    final dayEnd =
        DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
    return !date.isBefore(dayStart) && !date.isAfter(dayEnd);
  }

  bool isDateTimeClosed(DateTime checkTime) {
    if (!appliesToDate(checkTime)) return false;

    if (type == OverrideType.fullClosure) {
      return true;
    }

    final int checkMins = checkTime.hour * 60 + checkTime.minute;
    final int sMins = startMinutes ?? 0;
    final int eMins = endMinutes ?? 1439;

    if (type == OverrideType.customOpenHours) {
      return checkMins < sMins || checkMins > eMins;
    } else {
      return checkMins >= sMins && checkMins <= eMins;
    }
  }

  String formatTimeRange() {
    if (type == OverrideType.fullClosure) return 'Closed All Day';
    final sMins = startMinutes ?? 0;
    final eMins = endMinutes ?? 1439;
    return '${_formatMins(sMins)} – ${_formatMins(eMins)}';
  }

  static String _formatMins(int mins) {
    final h = mins ~/ 60;
    final m = mins % 60;
    final period = h >= 12 ? 'PM' : 'AM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    final mStr = m.toString().padLeft(2, '0');
    return '$h12:$mStr $period';
  }
}

class StoreSettings {
  final bool isClosed;
  final String? closureMessage;
  final DateTime? scheduledCloseAt;
  final DateTime? scheduledOpenAt;
  final DateTime? updatedAt;

  // Operating Hours Settings (synced with Admin-App)
  final bool operatingHoursEnabled;
  final String? dailyOpenTime; // e.g. "11:00"
  final String? dailyCloseTime; // e.g. "15:00"
  final List<int> closedDaysOfWeek; // 1 = Mon ... 7 = Sun
  final List<ScheduleOverride> overrides;

  // Expiration windows in hours
  final int perishableWindowHours;
  final int mixedWindowHours;
  final int standardWindowHours;

  // NEW FIELDS
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
    this.dailyOpenTime = '11:00',
    this.dailyCloseTime = '15:00',
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

    return StoreSettings(
      isClosed: d['isClosed'] ?? false,
      closureMessage: d['closureMessage'],
      scheduledCloseAt: (d['scheduledCloseAt'] as Timestamp?)?.toDate(),
      scheduledOpenAt: (d['scheduledOpenAt'] as Timestamp?)?.toDate(),
      updatedAt: (d['updatedAt'] as Timestamp?)?.toDate(),
      operatingHoursEnabled: d['operatingHoursEnabled'] ?? false,
      dailyOpenTime: d['dailyOpenTime']?.toString() ?? '11:00',
      dailyCloseTime: d['dailyCloseTime']?.toString() ?? '15:00',
      closedDaysOfWeek: (d['closedDaysOfWeek'] as List?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [],
      overrides: overridesList,
      perishableWindowHours: d['perishableWindowHours'] ?? 2,
      mixedWindowHours: d['mixedWindowHours'] ?? 24,
      standardWindowHours: d['standardWindowHours'] ?? 72,
      globalLowStockThreshold:
          (d['globalLowStockThreshold'] as num? ?? 5).toInt(),
      masterCategories: List<String>.from(d['masterCategories'] ??
          [
            'Fresh',
            'Grains',
            'Snacks',
            'Beverages',
            'Canned Goods',
            'Personal Care',
            'Condiments',
            'Others'
          ]),
      announcement: d['announcement'],
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
        'updatedAt': updatedAt != null
            ? Timestamp.fromDate(updatedAt!)
            : FieldValue.serverTimestamp(),
        'operatingHoursEnabled': operatingHoursEnabled,
        'dailyOpenTime': dailyOpenTime,
        'dailyCloseTime': dailyCloseTime,
        'closedDaysOfWeek': closedDaysOfWeek,
        'overrides': overrides.map((o) => o.toMap()).toList(),
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

  /// Parsed opening hour (default 11 if unset/invalid).
  int get openHour {
    if (!operatingHoursEnabled || dailyOpenTime == null) return 11;
    final mins = _parseMinutes(dailyOpenTime!);
    return mins != null ? mins ~/ 60 : 11;
  }

  /// Parsed closing hour (default 15 if unset/invalid).
  int get closeHour {
    if (!operatingHoursEnabled || dailyCloseTime == null) return 15;
    final mins = _parseMinutes(dailyCloseTime!);
    if (mins == null) return 15;
    // If e.g. 15:30, include hour 15 as last slot start or round up carefully
    return mins ~/ 60;
  }

  bool get effectivelyClosed {
    if (isClosed) return true;
    final now = TimeService.now;

    // 1. Check Scheduled Overrides
    for (final override in overrides) {
      if (override.appliesToDate(now)) {
        if (override.isDateTimeClosed(now)) {
          return true;
        }
      }
    }

    // 2. Check Scheduled Outage
    if (scheduledCloseAt != null && scheduledOpenAt != null) {
      if (now.isAfter(scheduledCloseAt!) && now.isBefore(scheduledOpenAt!)) {
        return true;
      }
    }

    // 3. Check Daily Operating Hours & Closed Days if enabled
    if (operatingHoursEnabled) {
      if (closedDaysOfWeek.contains(now.weekday)) {
        return true;
      }
      final openStr = dailyOpenTime;
      final closeStr = dailyCloseTime;
      if (openStr != null && closeStr != null) {
        final openMins = _parseMinutes(openStr);
        final closeMins = _parseMinutes(closeStr);
        final curMins = now.hour * 60 + now.minute;
        if (openMins != null && closeMins != null) {
          if (openMins < closeMins) {
            if (curMins < openMins || curMins >= closeMins) {
              return true;
            }
          } else if (openMins > closeMins) {
            if (curMins < openMins && curMins >= closeMins) {
              return true;
            }
          }
        }
      }
    }

    return false;
  }

  String get closureReason {
    if (isClosed) {
      final String rawMsg = closureMessage?.trim() ?? '';
      final String reasonText =
          rawMsg.isNotEmpty ? rawMsg : 'Will be back soon.';
      final DateTime time = updatedAt ?? scheduledCloseAt ?? TimeService.now;
      final String formattedTime = DateFormat('MMM d, h:mm a').format(time);
      return '$formattedTime — $reasonText';
    }

    final now = TimeService.now;

    for (final override in overrides) {
      if (override.appliesToDate(now)) {
        final reason = override.reason.isNotEmpty
            ? override.reason
            : 'Holiday / Special Schedule';
        if (override.type == OverrideType.fullClosure) {
          return 'Closed: $reason';
        } else if (override.type == OverrideType.customOpenHours) {
          if (override.isDateTimeClosed(now)) {
            return '$reason (Open ${override.formatTimeRange()} only).';
          } else {
            return 'Open: $reason (${override.formatTimeRange()})';
          }
        } else {
          if (override.isDateTimeClosed(now)) {
            return 'Closed for maintenance: $reason (${override.formatTimeRange()}).';
          }
        }
      }
    }

    if (scheduledCloseAt != null && scheduledOpenAt != null) {
      if (now.isAfter(scheduledCloseAt!) && now.isBefore(scheduledOpenAt!)) {
        final reopens = DateFormat('MMM d, h:mm a').format(scheduledOpenAt!);
        return (closureMessage != null && closureMessage!.trim().isNotEmpty)
            ? closureMessage!
            : 'Scheduled closure active until $reopens.';
      }
    }

    if (operatingHoursEnabled) {
      if (closedDaysOfWeek.contains(now.weekday)) {
        return 'Store is closed today per operating schedule.';
      }
      final openStr = dailyOpenTime;
      final closeStr = dailyCloseTime;
      if (openStr != null && closeStr != null) {
        final openMins = _parseMinutes(openStr);
        final closeMins = _parseMinutes(closeStr);
        final curMins = now.hour * 60 + now.minute;
        if (openMins != null && closeMins != null) {
          final outside = openMins < closeMins
              ? (curMins < openMins || curMins >= closeMins)
              : (openMins > closeMins &&
                  curMins < openMins &&
                  curMins >= closeMins);
          if (outside) {
            return 'Outside daily operating hours (${_formatTimeStr(openStr)} – ${_formatTimeStr(closeStr)}).';
          }
        }
      }
    }

    return 'Store is open for pickup orders.';
  }

  static int? _parseMinutes(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length < 2) return null;
      final h = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      return h * 60 + m;
    } catch (_) {
      return null;
    }
  }

  static String _formatTimeStr(String timeStr) {
    final mins = _parseMinutes(timeStr);
    if (mins == null) return timeStr;
    final h = mins ~/ 60;
    final m = mins % 60;
    final period = h >= 12 ? 'PM' : 'AM';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    final mStr = m.toString().padLeft(2, '0');
    return '$h12:$mStr $period';
  }
}
