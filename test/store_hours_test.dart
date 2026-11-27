import 'package:flutter_test/flutter_test.dart';
import 'package:gdc_customer_app/core/utils/store_hours.dart';
import 'package:gdc_customer_app/features/orders/providers/order_provider.dart';
import 'package:gdc_customer_app/shared/models/order.dart';
import 'package:gdc_customer_app/shared/models/product.dart';
import 'package:gdc_customer_app/shared/models/store_settings.dart';

void main() {
  group('StoreHours Admin Operating Hours Sync', () {
    test('defaultPickupSlot honors Admin custom dailyOpenTime & dailyCloseTime',
        () {
      const settings = StoreSettings(
        isClosed: false,
        operatingHoursEnabled: true,
        dailyOpenTime: '11:00',
        dailyCloseTime: '15:00',
      );

      final simulated112PM = DateTime(2025, 10, 24, 13, 12); // 1:12 PM
      expect(
        StoreHours.defaultPickupSlot(
          settings: settings,
          nowTime: simulated112PM,
        ),
        equals('Today, 1:00 PM – 2:00 PM'),
      );

      final simulated145PM = DateTime(2025, 10, 24, 13, 45); // 1:45 PM
      expect(
        StoreHours.defaultPickupSlot(
          settings: settings,
          nowTime: simulated145PM,
        ),
        equals('Today, 2:00 PM – 3:00 PM'),
      );

      // After 3:00 PM close -> rolls over to Tomorrow opening hour (11:00 AM)
      final simulated330PM = DateTime(2025, 10, 24, 15, 30); // 3:30 PM
      expect(
        StoreHours.defaultPickupSlot(
          settings: settings,
          nowTime: simulated330PM,
        ),
        equals('Tomorrow, 11:00 AM – 12:00 PM'),
      );
    });

    test('supports non-zero opening & closing minutes (e.g. 08:30 – 17:30)',
        () {
      const settings = StoreSettings(
        isClosed: false,
        operatingHoursEnabled: true,
        dailyOpenTime: '08:30',
        dailyCloseTime: '17:30',
      );
      final morning = DateTime(2026, 11, 26, 7, 0);
      final slots = StoreHours.getSlotsForDate(
        DateTime(2026, 11, 26),
        settings: settings,
        nowTime: morning,
      );

      expect(slots.first.rangeLabel, equals('8:30 AM – 9:30 AM'));
      expect(slots.last.rangeLabel, equals('4:30 PM – 5:30 PM'));
      expect(slots.length, equals(9));
    });

    test(
        'handles fullClosure, customOpenHours, and maintenanceWindow overrides',
        () {
      final settings = StoreSettings(
        isClosed: false,
        operatingHoursEnabled: true,
        dailyOpenTime: '08:00',
        dailyCloseTime: '17:00',
        overrides: [
          ScheduleOverride(
            id: 'hol1',
            startDate: DateTime(2026, 12, 24),
            endDate: DateTime(2026, 12, 24),
            type: OverrideType.fullClosure,
            reason: 'Christmas Eve',
          ),
          ScheduleOverride(
            id: 'spec1',
            startDate: DateTime(2026, 12, 25),
            endDate: DateTime(2026, 12, 25),
            type: OverrideType.customOpenHours,
            startMinutes: 13 * 60, // 1:00 PM
            endMinutes: 15 * 60, // 3:00 PM
            reason: 'Holiday Special Hours',
          ),
          ScheduleOverride(
            id: 'maint1',
            startDate: DateTime(2026, 12, 26),
            endDate: DateTime(2026, 12, 26),
            type: OverrideType.maintenanceWindow,
            startMinutes: 12 * 60, // 12:00 PM
            endMinutes: 14 * 60, // 2:00 PM
            reason: 'Midday Restocking',
          ),
        ],
      );

      final now = DateTime(2026, 12, 24, 9, 0);

      // Dec 24 is fullClosure -> no slots; default jumps to Dec 25 special hours
      expect(
        StoreHours.getSlotsForDate(
          DateTime(2026, 12, 24),
          settings: settings,
          nowTime: now,
        ),
        isEmpty,
      );
      expect(
        StoreHours.defaultPickupSlot(settings: settings, nowTime: now),
        equals('Tomorrow, 1:00 PM – 2:00 PM'),
      );

      // Dec 25 only allows 1 PM – 3 PM
      final dec25Slots = StoreHours.getSlotsForDate(
        DateTime(2026, 12, 25),
        settings: settings,
        nowTime: now,
      );
      expect(dec25Slots.map((s) => s.rangeLabel).toList(),
          equals(['1:00 PM – 2:00 PM', '2:00 PM – 3:00 PM']));

      // Dec 26 excludes 12:00 PM – 2:00 PM maintenance window
      final dec26Slots = StoreHours.getSlotsForDate(
        DateTime(2026, 12, 26),
        settings: settings,
        nowTime: now,
      );
      expect(
        dec26Slots.any((s) => s.rangeLabel == '12:00 PM – 1:00 PM'),
        isFalse,
      );
      expect(
        dec26Slots.any((s) => s.rangeLabel == '1:00 PM – 2:00 PM'),
        isFalse,
      );
      expect(
        dec26Slots.any((s) => s.rangeLabel == '11:00 AM – 12:00 PM'),
        isTrue,
      );
      expect(
        dec26Slots.any((s) => s.rangeLabel == '2:00 PM – 3:00 PM'),
        isTrue,
      );
    });

    test(
        'skips closedDaysOfWeek and bridges Saturday night reservation to Monday',
        () {
      const settings = StoreSettings(
        isClosed: false,
        operatingHoursEnabled: true,
        dailyOpenTime: '08:00',
        dailyCloseTime: '20:00',
        closedDaysOfWeek: [DateTime.sunday],
      );

      // Saturday Nov 28, 2026 at 9:30 PM (after closing)
      final satNight = DateTime(2026, 11, 28, 21, 30);
      const perishableProduct = Product(
        id: 'p_fresh',
        name: 'Fresh Milk',
        category: 'Fresh',
        price: 85,
        stock: 10,
        shelfDays: 3,
      );
      final policy = BasketPickupPolicy.fromCart(
        cart: const [
          CartItem(
            productId: 'p_fresh',
            name: 'Fresh Milk',
            price: 85,
            qty: 1,
            isPerishable: true,
          ),
        ],
        allProducts: [perishableProduct],
        settings: settings,
      );

      final defaultSlot = StoreHours.getDefaultSlotOption(
        settings: settings,
        policy: policy,
        nowTime: satNight,
      );
      expect(defaultSlot, isNotNull);
      // Skips Sunday Nov 29 -> selects Monday Nov 30, 8:00 AM – 9:00 AM
      expect(defaultSlot!.startTime, equals(DateTime(2026, 11, 30, 8, 0)));
      expect(defaultSlot.value, equals('Mon, Nov 30, 8:00 AM – 9:00 AM'));
    });
  });

  group('Product-Based BasketPickupPolicy', () {
    const settings = StoreSettings(
      isClosed: false,
      operatingHoursEnabled: true,
      dailyOpenTime: '08:00',
      dailyCloseTime: '21:00',
      perishableWindowHours: 2,
      mixedWindowHours: 24,
      standardWindowHours: 72,
    );

    test(
        'non-perishable items allow advance reservation up to standardWindowHours',
        () {
      const canned = Product(
        id: 'c1',
        name: 'Sardines',
        category: 'Canned Goods',
        price: 25,
        stock: 50,
      );
      final policy = BasketPickupPolicy.fromCart(
        cart: const [
          CartItem(
            productId: 'c1',
            name: 'Sardines',
            price: 25,
            qty: 2,
            isPerishable: false,
          ),
        ],
        allProducts: [canned],
        settings: settings,
      );

      expect(policy.tier, equals(BasketProductTier.standard));
      expect(policy.maxAdvanceDays, equals(3));

      // Even after store closes at 10:00 PM, customer can still reserve next 3 days
      final night = DateTime(2026, 11, 26, 22, 0);
      final dates = StoreHours.getAvailableDates(
        settings: settings,
        policy: policy,
        nowTime: night,
      );
      expect(dates.length, equals(3)); // Nov 27, Nov 28, Nov 29
      expect(dates.first, equals(DateTime(2026, 11, 27)));
    });

    test(
        'perishable product with custom pickupWindowHours restricts intraday slots',
        () {
      const pandesal = Product(
        id: 'b1',
        name: 'Hot Pandesal',
        category: 'Fresh',
        price: 30,
        stock: 20,
        shelfDays: 1,
        pickupWindowHours: 3,
      );
      final policy = BasketPickupPolicy.fromCart(
        cart: const [
          CartItem(
            productId: 'b1',
            name: 'Hot Pandesal',
            price: 30,
            qty: 1,
            isPerishable: true,
          ),
        ],
        allProducts: [pandesal],
        settings: settings,
      );

      expect(policy.tier, equals(BasketProductTier.perishableOnly));
      expect(policy.hasStrictIntradayWindow, isTrue);

      // Reserving at 9:30 PM -> tomorrow slots limited to first 3 hours after 8:00 AM open
      final night = DateTime(2026, 11, 26, 21, 30);
      final tomorrowSlots = StoreHours.getSlotsForDate(
        DateTime(2026, 11, 27),
        settings: settings,
        policy: policy,
        nowTime: night,
        isEarliestOpenDay: true,
      );
      expect(
        tomorrowSlots.map((s) => s.rangeLabel).toList(),
        equals([
          '8:00 AM – 9:00 AM',
          '9:00 AM – 10:00 AM',
          '10:00 AM – 11:00 AM',
        ]),
      );
    });

    test('FEFO expiryDate caps maximum reservable date', () {
      final yogurt = Product(
        id: 'y1',
        name: 'Greek Yogurt',
        category: 'Fresh',
        price: 120,
        stock: 5,
        expiryDate: DateTime(2026, 11, 27),
      );
      const chips = Product(
        id: 'ch1',
        name: 'Potato Chips',
        category: 'Snacks',
        price: 40,
        stock: 30,
      );
      final policy = BasketPickupPolicy.fromCart(
        cart: const [
          CartItem(
            productId: 'y1',
            name: 'Greek Yogurt',
            price: 120,
            qty: 1,
            isPerishable: true,
          ),
          CartItem(
            productId: 'ch1',
            name: 'Potato Chips',
            price: 40,
            qty: 1,
            isPerishable: false,
          ),
        ],
        allProducts: [yogurt, chips],
        settings: settings,
      );

      final now = DateTime(2026, 11, 26, 10, 0);
      final dates = StoreHours.getAvailableDates(
        settings: settings,
        policy: policy,
        nowTime: now,
      );
      // Should include Nov 26 & Nov 27 (expiry day), NOT Nov 28
      expect(dates, equals([DateTime(2026, 11, 26), DateTime(2026, 11, 27)]));
    });

    test('emergency maintenance blocks all pickup slots', () {
      const emergency = StoreSettings(
        isClosed: true,
        closureMessage: 'Power outage',
      );
      final now = DateTime(2026, 11, 26, 10, 0);
      expect(
        StoreHours.getDefaultSlotOption(settings: emergency, nowTime: now),
        isNull,
      );
    });
  });

  group('Slot Parsing & Dynamic Extension Cutoff', () {
    test('parses multi-comma future date slot accurately', () {
      final now = DateTime(2026, 11, 26, 10, 0);
      const slot = 'Sat, Nov 28, 2:00 PM – 3:00 PM';

      final start = StoreHours.parseSlotTargetDateTime(slot, nowTime: now);
      final end = StoreHours.parseSlotEndDateTime(slot, nowTime: now);

      expect(start, equals(DateTime(2026, 11, 28, 14, 0)));
      expect(end, equals(DateTime(2026, 11, 28, 15, 0)));
      expect(StoreHours.isSlotExpired(slot, nowTime: now), isFalse);
    });

    test('isSlotExpired checks against slot end time minus prep buffer', () {
      final simulated112PM = DateTime(2025, 10, 24, 13, 12);
      expect(
        StoreHours.isSlotExpired(
          'Today, 1:00 PM – 2:00 PM',
          nowTime: simulated112PM,
        ),
        isFalse,
      );

      final simulated145PM = DateTime(2025, 10, 24, 13, 45);
      expect(
        StoreHours.isSlotExpired(
          'Today, 1:00 PM – 2:00 PM',
          nowTime: simulated145PM,
        ),
        isTrue,
      );
    });

    test('OrderProvider extension cutoff respects Admin dailyCloseTime', () {
      // Simulate 5:55 PM when order expires at 6:00 PM and Admin closes at 9:00 PM
      final simulated555PM = DateTime(2026, 11, 26, 17, 55);

      const settings9PM = StoreSettings(
        isClosed: false,
        operatingHoursEnabled: true,
        dailyOpenTime: '08:00',
        dailyCloseTime: '21:00',
      );

      final expiry6PM = DateTime(2026, 11, 26, 18, 0);
      expect(
        OrderProvider.getAvailableExtensionMinutes(
          expiry6PM,
          settings: settings9PM,
          nowTime: simulated555PM,
        ),
        equals(20),
      );

      // If Admin closes at 6:10 PM instead, extension caps at 10 minutes
      const settings610PM = StoreSettings(
        isClosed: false,
        operatingHoursEnabled: true,
        dailyOpenTime: '08:00',
        dailyCloseTime: '18:10',
      );
      expect(
        OrderProvider.getAvailableExtensionMinutes(
          expiry6PM,
          settings: settings610PM,
          nowTime: simulated555PM,
        ),
        equals(10),
      );
    });
  });
}
