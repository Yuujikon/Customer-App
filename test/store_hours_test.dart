import 'package:flutter_test/flutter_test.dart';
import 'package:gdc_customer_app/core/utils/store_hours.dart';

void main() {
  group('StoreHours Dynamic Pickup Slot Tests', () {
    test('defaultPickupSlot returns next valid slot at 1:12 PM', () {
      final simulated112PM = DateTime(2025, 10, 24, 13, 12); // 1:12 PM
      final slot = StoreHours.defaultPickupSlot(nowTime: simulated112PM);
      // 1:12 PM + 20m prep = 1:32 PM, which is before 2:00 PM slot end
      expect(slot, equals('Today, 1:00 PM – 2:00 PM'));
    });

    test('defaultPickupSlot auto-selects 2:00 PM – 3:00 PM when time is 1:45 PM', () {
      final simulated145PM = DateTime(2025, 10, 24, 13, 45); // 1:45 PM
      final slot = StoreHours.defaultPickupSlot(nowTime: simulated145PM);
      // 1:45 PM + 20m prep = 2:05 PM, past 2:00 PM end, so moves to 2:00 PM – 3:00 PM
      expect(slot, equals('Today, 2:00 PM – 3:00 PM'));
    });

    test('defaultPickupSlot defaults to Tomorrow when store is closed after 3:00 PM', () {
      final simulated330PM = DateTime(2025, 10, 24, 15, 30); // 3:30 PM
      final slot = StoreHours.defaultPickupSlot(nowTime: simulated330PM);
      expect(slot, equals('Tomorrow, 11:00 AM – 12:00 PM'));
    });

    test('isSlotExpired checks against slot end time minus prep buffer', () {
      final simulated112PM = DateTime(2025, 10, 24, 13, 12);
      // At 1:12 PM, 1:00 PM – 2:00 PM ends at 2:00 PM. 1:12 + 20m = 1:32 PM < 2:00 PM -> Not expired!
      expect(StoreHours.isSlotExpired('Today, 1:00 PM – 2:00 PM', nowTime: simulated112PM), isFalse);

      final simulated145PM = DateTime(2025, 10, 24, 13, 45);
      // At 1:45 PM, 1:45 + 20m = 2:05 PM >= 2:00 PM -> Expired!
      expect(StoreHours.isSlotExpired('Today, 1:00 PM – 2:00 PM', nowTime: simulated145PM), isTrue);
    });

    test('parseSlotTargetDateTime extracts correct DateTime target', () {
      final simulatedNow = DateTime(2025, 10, 24, 13, 12);
      final target = StoreHours.parseSlotTargetDateTime('Today, 1:00 PM – 2:00 PM', nowTime: simulatedNow);
      expect(target.year, equals(2025));
      expect(target.month, equals(10));
      expect(target.day, equals(24));
      expect(target.hour, equals(13));
      expect(target.minute, equals(0));
    });
  });
}
