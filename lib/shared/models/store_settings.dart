import 'package:cloud_firestore/cloud_firestore.dart';

class StoreSettings {
  final bool isClosed;
  final String? closureMessage;
  final DateTime? scheduledCloseAt;
  final DateTime? scheduledOpenAt;

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
    return StoreSettings(
      isClosed: d['isClosed'] ?? false,
      closureMessage: d['closureMessage'],
      scheduledCloseAt: (d['scheduledCloseAt'] as Timestamp?)?.toDate(),
      scheduledOpenAt: (d['scheduledOpenAt'] as Timestamp?)?.toDate(),
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

  bool get effectivelyClosed {
    if (isClosed) return true;
    final now = DateTime.now();
    if (scheduledCloseAt != null && scheduledOpenAt != null) {
      return now.isAfter(scheduledCloseAt!) && now.isBefore(scheduledOpenAt!);
    }
    return false;
  }
}
