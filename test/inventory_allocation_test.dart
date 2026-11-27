import 'package:flutter_test/flutter_test.dart';
import 'package:gdc_customer_app/core/utils/inventory_allocation.dart';
import 'package:gdc_customer_app/shared/models/product.dart';

void main() {
  group('Customer InventoryAllocation — Fixed 75% Online / 25% Reserve', () {
    test('calculates 25% physical reserve rounding up on odd quantities', () {
      expect(InventoryAllocation.calculatePhysicalReserve(0), 0);
      expect(InventoryAllocation.calculatePhysicalReserve(-2), 0);
      expect(InventoryAllocation.calculatePhysicalReserve(1), 1);
      expect(InventoryAllocation.calculatePhysicalReserve(5), 2);
      expect(InventoryAllocation.calculatePhysicalReserve(10), 3);
      expect(InventoryAllocation.calculatePhysicalReserve(100), 25);
    });

    test('Scenario 1: Restocking 100 units exposes only 75 on Customer App',
        () {
      final int reserve = InventoryAllocation.calculatePhysicalReserve(100);
      expect(reserve, 25);

      final product = Product(
        id: 'p_rice',
        name: 'Sinandomeng Rice 1kg',
        category: 'Grains',
        price: 58.0,
        stock: 100,
        physicalReserve: reserve,
      );

      expect(product.onlineAvailableStock, 75);
      expect(product.maxPurchasableStock, 75);
      expect(product.isOnlineOutOfStock, isFalse);
      expect(product.isOutOfStockForCustomer, isFalse);
    });

    test('Scenario 2: Buying 75 online marks Customer App Out of Stock', () {
      // While order is reserved pending pickup
      const pendingPickup = Product(
        id: 'p_rice',
        name: 'Sinandomeng Rice 1kg',
        category: 'Grains',
        price: 58.0,
        stock: 100,
        reservedStock: 75,
        physicalReserve: 25,
      );
      expect(pendingPickup.onlineAvailableStock, 0);
      expect(pendingPickup.maxPurchasableStock, 0);
      expect(pendingPickup.isOnlineOutOfStock, isTrue);
      expect(pendingPickup.isOutOfStockForCustomer, isTrue);

      // After order is collected (physical stock at 25, reserve preserved at 25)
      const afterPickup = Product(
        id: 'p_rice',
        name: 'Sinandomeng Rice 1kg',
        category: 'Grains',
        price: 58.0,
        stock: 25,
        reservedStock: 0,
        physicalReserve: 25,
      );
      expect(afterPickup.onlineAvailableStock, 0);
      expect(afterPickup.maxPurchasableStock, 0);
      expect(afterPickup.isOnlineOutOfStock, isTrue);
      expect(afterPickup.isOutOfStockForCustomer, isTrue);
    });

    test('Scenario 3: As POS sells remaining 25 to 0, Customer App stays OOS',
        () {
      for (final remaining in [25, 15, 5, 1, 0]) {
        final product = Product(
          id: 'p_rice',
          name: 'Sinandomeng Rice 1kg',
          category: 'Grains',
          price: 58.0,
          stock: remaining,
          physicalReserve: 25,
        );
        expect(product.onlineAvailableStock, 0);
        expect(product.isOutOfStockForCustomer, isTrue);
      }
    });

    test('Order cancellation restores onlineAvailable automatically', () {
      const afterCancel = Product(
        id: 'p_rice',
        name: 'Sinandomeng Rice 1kg',
        category: 'Grains',
        price: 58.0,
        stock: 100,
        reservedStock: 65,
        physicalReserve: 25,
      );
      expect(afterCancel.onlineAvailableStock, 10);
      expect(afterCancel.maxPurchasableStock, 10);
      expect(afterCancel.isOutOfStockForCustomer, isFalse);
    });

    test(
        'Legacy product document without physicalReserve falls back to 25% ceil',
        () {
      const legacyProduct = Product(
        id: 'legacy_1',
        name: 'Legacy Milk',
        category: 'Dairy',
        price: 45.0,
        stock: 10,
      );
      expect(legacyProduct.physicalReserve, isNull);
      expect(legacyProduct.effectivePhysicalReserve, 3);
      expect(legacyProduct.onlineAvailableStock, 7);
      expect(legacyProduct.maxPurchasableStock, 7);
    });

    test('Multi-variant product computes per-variant and aggregate online cap',
        () {
      const product = Product(
        id: 'p_juice',
        name: 'Fruit Juice',
        category: 'Beverages',
        price: 20.0,
        stock: 50,
        variants: {
          'mango': ProductVariant(
            id: 'mango',
            name: 'Mango',
            price: 20.0,
            stock: 40,
            physicalReserve: 10, // 30 online
          ),
          'apple': ProductVariant(
            id: 'apple',
            name: 'Apple',
            price: 20.0,
            stock: 10,
            physicalReserve: 10, // 0 online (OOS)
          ),
        },
      );

      expect(product.variants!['mango']!.onlineAvailableStock, 30);
      expect(product.variants!['mango']!.isOutOfStockForCustomer, isFalse);
      expect(product.variants!['apple']!.onlineAvailableStock, 0);
      expect(product.variants!['apple']!.isOutOfStockForCustomer, isTrue);
      expect(product.onlineAvailableStock, 30);
      expect(product.maxPurchasableStock, 30);
      expect(product.isOutOfStockForCustomer, isFalse);
    });

    test(
        '30% automatic low-stock trigger does not affect 75% online allocation',
        () {
      expect(InventoryAllocation.calculateLowStockTrigger(100), 30);
      expect(InventoryAllocation.calculateLowStockTrigger(29), 9);

      const product = Product(
        id: 'p_sardines',
        name: '555 Sardines',
        category: 'Canned Goods',
        price: 25.0,
        stock: 30,
        initialStock: 100,
        physicalReserve: 25,
      );

      expect(product.lowStockAlertThreshold, 30);
      expect(product.onlineAvailableStock, 5); // 30 - 25 reserve
      expect(product.isOutOfStockForCustomer, isFalse);
    });
  });
}
