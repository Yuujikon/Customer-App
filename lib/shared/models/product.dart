import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../core/utils/inventory_allocation.dart';
import '../services/time_service.dart';

enum ProductStatus { draft, published }

enum ExpiryStatus { optimal, warning, critical, expired }

enum InventoryAbcCategory { categoryA, categoryB, categoryC }

int _parseInt(dynamic value, [int fallback = 0]) {
  if (value == null) return fallback;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString().trim()) ??
      double.tryParse(value.toString().trim())?.toInt() ??
      fallback;
}

int? _parseNullableInt(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString().trim()) ??
      double.tryParse(value.toString().trim())?.toInt();
}

double _parseDouble(dynamic value, [double fallback = 0.0]) {
  if (value == null) return fallback;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString().trim()) ?? fallback;
}

double? _parseNullableDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString().trim());
}

class ProductVariant {
  final String id;
  final String name;
  final double price;
  final int stock;
  final int reservedStock;
  final int? initialStock;
  final String? barcode;

  /// Fixed 25% physical-only walk-in reserve calculated on restock/stock-in.
  final int? physicalReserve;

  const ProductVariant({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
    this.reservedStock = 0,
    this.initialStock,
    this.barcode,
    this.physicalReserve,
  });

  int get effectiveReservedStock => reservedStock > 0 ? reservedStock : 0;

  int get availableStock => InventoryAllocation.calculatePosAvailable(
        totalStock: stock,
        reservedStock: effectiveReservedStock,
      );

  int get effectivePhysicalReserve =>
      InventoryAllocation.resolvePhysicalReserve(
        totalStock: stock > 0 ? stock : 0,
        storedPhysicalReserve: physicalReserve,
      );

  int get effectiveInitialStock =>
      (initialStock != null && initialStock! > 0) ? initialStock! : stock;

  int get effectiveOriginalStock {
    final safeStock = stock > 0 ? stock : 0;
    final init = effectiveInitialStock;
    return init >= safeStock ? init : safeStock;
  }

  int get lowStockAlertThreshold =>
      InventoryAllocation.calculateLowStockTrigger(effectiveOriginalStock);

  int get lowStockThreshold => lowStockAlertThreshold;

  int get onlineAvailableStock => InventoryAllocation.calculateOnlineAvailable(
        totalStock: stock,
        physicalReserve: effectivePhysicalReserve,
        reservedStock: effectiveReservedStock,
      );

  bool get isOnlineOutOfStock => onlineAvailableStock <= 0;

  bool get isOutOfStockForCustomer => onlineAvailableStock <= 0;

  int get maxPurchasableStock => onlineAvailableStock;

  factory ProductVariant.fromMap(String id, Map<String, dynamic> m) {
    final int? parsedReserve = _parseNullableInt(m['physicalReserve']);

    return ProductVariant(
      id: id,
      name: m['name']?.toString() ?? 'Unnamed Variant',
      price: _parseDouble(m['price']),
      stock: _parseInt(m['stock']),
      reservedStock: _parseInt(m['reservedStock']),
      initialStock: _parseNullableInt(m['initialStock']),
      barcode: m['barcode']?.toString(),
      physicalReserve:
          parsedReserve != null && parsedReserve >= 0 ? parsedReserve : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'price': price,
        'stock': stock,
        'reservedStock': reservedStock,
        'initialStock': initialStock ?? stock,
        'physicalReserve': effectivePhysicalReserve,
        if (barcode != null) 'barcode': barcode,
      };
}

class Product {
  final String id;
  final String name;
  final String? brand;
  final String? parentId;
  final String category;
  final double price;
  final int stock;
  final int reservedStock;
  final int? initialStock;
  final String unit;
  final String bulkUnit;
  final double? packCost;
  final int? itemsPerCase;
  final String? barcode;
  final int? shelfDays;
  final int? pickupWindowHours;
  final String? photoBase64;
  final double? wholesalePrice;
  final int? wholesaleThreshold;
  final String? supplierId;
  final DateTime? expiryDate;
  final Map<String, ProductVariant>? variants;

  final ProductStatus status;
  final bool isTaxable;

  // Enterprise Industrial Automation Fields
  final double? costPrice;
  final int? reorderPoint;
  final int? reorderQuantity;
  final int? leadTimeDays;
  final bool isQuarantined;

  // Restock Notification Tracking
  final List<String> notifyUserIds;

  /// Fixed 25% physical-only walk-in reserve calculated on restock/stock-in.
  final int? physicalReserve;

  const Product({
    required this.id,
    required this.name,
    this.brand,
    this.parentId,
    required this.category,
    required this.price,
    required this.stock,
    this.reservedStock = 0,
    this.initialStock,
    this.unit = 'pcs',
    this.bulkUnit = 'box',
    this.packCost,
    this.itemsPerCase,
    this.barcode,
    this.shelfDays,
    this.pickupWindowHours,
    this.photoBase64,
    this.wholesalePrice,
    this.wholesaleThreshold,
    this.supplierId,
    this.expiryDate,
    this.variants,
    this.status = ProductStatus.published,
    this.isTaxable = true,
    this.costPrice,
    this.reorderPoint,
    this.reorderQuantity,
    this.leadTimeDays,
    this.isQuarantined = false,
    this.notifyUserIds = const [],
    this.physicalReserve,
  });

  bool get isPerishable => shelfDays != null || expiryDate != null;
  bool get hasVariants => variants != null && variants!.isNotEmpty;

  int get effectiveReservedStock => reservedStock > 0 ? reservedStock : 0;

  int get availableStock => InventoryAllocation.calculatePosAvailable(
        totalStock: stock,
        reservedStock: effectiveReservedStock,
      );

  int get totalStock {
    if (!hasVariants) return stock > 0 ? stock : 0;
    return variants!.values
        .fold(0, (acc, v) => acc + (v.stock > 0 ? v.stock : 0));
  }

  int get totalAvailableStock {
    if (!hasVariants) return availableStock;
    return variants!.values.fold(0, (acc, v) => acc + v.availableStock);
  }

  int get effectiveInitialStock =>
      (initialStock != null && initialStock! > 0) ? initialStock! : stock;

  int get effectiveOriginalStock {
    if (hasVariants) {
      return variants!.values
          .fold(0, (acc, v) => acc + v.effectiveOriginalStock);
    }
    final safeStock = stock > 0 ? stock : 0;
    final init = effectiveInitialStock;
    return init >= safeStock ? init : safeStock;
  }

  int get lowStockAlertThreshold {
    if (hasVariants) {
      return variants!.values
          .fold(0, (acc, v) => acc + v.lowStockAlertThreshold);
    }
    return InventoryAllocation.calculateLowStockTrigger(effectiveOriginalStock);
  }

  int get lowStockThreshold => lowStockAlertThreshold;

  bool get isLowStock =>
      totalStock > 0 && totalAvailableStock <= lowStockAlertThreshold;

  int get effectivePhysicalReserve {
    if (hasVariants) {
      return variants!.values
          .fold(0, (acc, v) => acc + v.effectivePhysicalReserve);
    }
    return InventoryAllocation.resolvePhysicalReserve(
      totalStock: stock > 0 ? stock : 0,
      storedPhysicalReserve: physicalReserve,
    );
  }

  int get onlineAvailableStock {
    if (hasVariants) {
      return variants!.values.fold(0, (acc, v) => acc + v.onlineAvailableStock);
    }
    return InventoryAllocation.calculateOnlineAvailable(
      totalStock: stock,
      physicalReserve: effectivePhysicalReserve,
      reservedStock: effectiveReservedStock,
    );
  }

  bool get isOnlineOutOfStock {
    if (hasVariants) {
      return variants!.values.every((v) => v.isOnlineOutOfStock);
    }
    return onlineAvailableStock <= 0;
  }

  bool get isOutOfStockForCustomer {
    if (isQuarantined) return true;
    if (hasVariants) {
      if (variants == null || variants!.isEmpty) {
        return onlineAvailableStock <= 0;
      }
      return variants!.values.every((v) => v.isOutOfStockForCustomer);
    }
    return onlineAvailableStock <= 0;
  }

  int get maxPurchasableStock {
    if (isQuarantined) return 0;
    if (hasVariants) {
      if (variants == null) return 0;
      return variants!.values.fold(0, (acc, v) => acc + v.maxPurchasableStock);
    }
    return onlineAvailableStock;
  }

  List<double> get priceRange {
    if (!hasVariants) return [price];
    final prices = variants!.values.map((v) => v.price).toList();
    if (prices.isEmpty) return [price];
    prices.sort();
    return [prices.first, prices.last];
  }

  // ── Inventory Automation & Telemetry Analytics ─────────────────────────────

  double get effectiveCostPrice =>
      costPrice ?? (price > 0 ? price * 0.70 : 0.0);

  int get effectiveReorderPoint => reorderPoint ?? (lowStockThreshold * 2);

  int get effectiveReorderQuantity =>
      reorderQuantity ??
      ((effectiveInitialStock - totalStock) > 0
          ? (effectiveInitialStock - totalStock)
          : 20);

  int get effectiveLeadTimeDays => leadTimeDays ?? 2;

  bool get isAutoReorderRequired =>
      totalStock <= effectiveReorderPoint && !isQuarantined;

  double get unitGrossMargin {
    if (price <= 0) return 0;
    return ((price - effectiveCostPrice) / price) * 100;
  }

  double get totalInventoryAssetValue => price * totalStock;

  double get totalInventoryCostValue => effectiveCostPrice * totalStock;

  int get daysUntilExpiry {
    if (expiryDate == null) return 999;
    return expiryDate!.difference(TimeService.now).inDays;
  }

  ExpiryStatus get expiryStatus {
    if (expiryDate == null) return ExpiryStatus.optimal;
    final days = daysUntilExpiry;
    if (days < 0) return ExpiryStatus.expired;
    if (days <= 2) return ExpiryStatus.critical;
    if (days <= 7) return ExpiryStatus.warning;
    return ExpiryStatus.optimal;
  }

  factory Product.fromFirestore(DocumentSnapshot doc) {
    try {
      final d = doc.data() as Map<String, dynamic>? ?? {};

      Map<String, ProductVariant>? variantsMap;
      if (d['variants'] != null) {
        if (d['variants'] is Map) {
          variantsMap = {};
          (d['variants'] as Map).forEach((k, v) {
            final key = k.toString();
            final vMap = v is Map
                ? v.map((vk, vv) => MapEntry(vk.toString(), vv))
                : <String, dynamic>{};
            variantsMap![key] = ProductVariant.fromMap(key, vMap);
          });
        } else if (d['variants'] is List) {
          variantsMap = {};
          for (final item in d['variants'] as List) {
            if (item is Map) {
              final vMap = item.map((vk, vv) => MapEntry(vk.toString(), vv));
              final String vId = vMap['id']?.toString() ?? '';
              if (vId.isNotEmpty) {
                variantsMap[vId] = ProductVariant.fromMap(vId, vMap);
              }
            }
          }
        }
      }

      final int? parsedPhysicalReserve =
          _parseNullableInt(d['physicalReserve']);

      return Product(
        id: doc.id,
        name: d['name']?.toString() ?? 'Unnamed Product',
        brand: d['brand']?.toString(),
        parentId: d['parentId']?.toString(),
        category: d['category']?.toString() ?? 'Others',
        price: _parseDouble(d['price']),
        stock: _parseInt(d['stock']),
        reservedStock: _parseInt(d['reservedStock']),
        initialStock: _parseNullableInt(d['initialStock']),
        unit: d['unit']?.toString() ?? 'pcs',
        bulkUnit: d['bulkUnit']?.toString() ?? 'box',
        packCost: _parseNullableDouble(d['packCost']),
        itemsPerCase: _parseNullableInt(d['itemsPerCase']),
        barcode: d['barcode']?.toString(),
        shelfDays: _parseNullableInt(d['shelfDays']),
        pickupWindowHours: _parseNullableInt(d['pickupWindowHours']),
        photoBase64: d['photoBase64']?.toString(),
        wholesalePrice: _parseNullableDouble(d['wholesalePrice']),
        wholesaleThreshold: _parseNullableInt(d['wholesaleThreshold']),
        supplierId: d['supplierId']?.toString(),
        expiryDate: (d['expiryDate'] as Timestamp?)?.toDate(),
        variants: variantsMap,
        status: ProductStatus.values.firstWhere(
          (e) => e.name == (d['status'] ?? 'published'),
          orElse: () => ProductStatus.published,
        ),
        isTaxable: d['isTaxable'] as bool? ?? true,
        costPrice: _parseNullableDouble(d['costPrice']),
        reorderPoint: _parseNullableInt(d['reorderPoint']),
        reorderQuantity: _parseNullableInt(d['reorderQuantity']),
        leadTimeDays: _parseNullableInt(d['leadTimeDays']),
        isQuarantined: d['isQuarantined'] as bool? ?? false,
        notifyUserIds: (d['notifyUserIds'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        physicalReserve:
            parsedPhysicalReserve != null && parsedPhysicalReserve >= 0
                ? parsedPhysicalReserve
                : null,
      );
    } catch (e) {
      debugPrint('Error parsing product ${doc.id}: $e');
      return Product(
          id: doc.id,
          name: 'Error Loading',
          category: 'Error',
          price: 0,
          stock: 0);
    }
  }

  bool isNotifyingUser(String userId) => notifyUserIds.contains(userId);

  Map<String, dynamic> toFirestore() => {
        'name': name,
        if (brand != null) 'brand': brand,
        if (parentId != null) 'parentId': parentId,
        'category': category,
        'price': price,
        'stock': stock,
        'reservedStock': reservedStock,
        'initialStock': initialStock ?? stock,
        'physicalReserve': effectivePhysicalReserve,
        'unit': unit,
        'bulkUnit': bulkUnit,
        if (packCost != null) 'packCost': packCost,
        if (itemsPerCase != null) 'itemsPerCase': itemsPerCase,
        'barcode': barcode,
        'shelfDays': shelfDays,
        'pickupWindowHours': pickupWindowHours,
        'photoBase64': photoBase64,
        'wholesalePrice': wholesalePrice,
        'wholesaleThreshold': wholesaleThreshold,
        'supplierId': supplierId,
        'expiryDate':
            expiryDate != null ? Timestamp.fromDate(expiryDate!) : null,
        'variants': variants?.map((k, v) => MapEntry(k, v.toMap())),
        'status': status.name,
        'isTaxable': isTaxable,
        'costPrice': costPrice,
        'reorderPoint': reorderPoint,
        'reorderQuantity': reorderQuantity,
        'leadTimeDays': leadTimeDays,
        'isQuarantined': isQuarantined,
        'notifyUserIds': notifyUserIds,
        'updatedAt': FieldValue.serverTimestamp(),
      };

  Product copyWith({
    int? stock,
    int? reservedStock,
    int? initialStock,
    int? physicalReserve,
    String? barcode,
    String? photoBase64,
    int? pickupWindowHours,
    ProductStatus? status,
    double? costPrice,
    int? reorderPoint,
    int? reorderQuantity,
    int? leadTimeDays,
    bool? isQuarantined,
    List<String>? notifyUserIds,
    Map<String, ProductVariant>? variants,
  }) =>
      Product(
        id: id,
        name: name,
        brand: brand,
        parentId: parentId,
        category: category,
        price: price,
        stock: stock ?? this.stock,
        reservedStock: reservedStock ?? this.reservedStock,
        initialStock: initialStock ?? this.initialStock,
        physicalReserve: physicalReserve ?? this.physicalReserve,
        unit: unit,
        bulkUnit: bulkUnit,
        packCost: packCost,
        itemsPerCase: itemsPerCase,
        shelfDays: shelfDays,
        barcode: barcode ?? this.barcode,
        pickupWindowHours: pickupWindowHours ?? this.pickupWindowHours,
        photoBase64: photoBase64 ?? this.photoBase64,
        wholesalePrice: wholesalePrice,
        wholesaleThreshold: wholesaleThreshold,
        supplierId: supplierId,
        expiryDate: expiryDate,
        variants: variants ?? this.variants,
        status: status ?? this.status,
        isTaxable: isTaxable,
        costPrice: costPrice ?? this.costPrice,
        reorderPoint: reorderPoint ?? this.reorderPoint,
        reorderQuantity: reorderQuantity ?? this.reorderQuantity,
        leadTimeDays: leadTimeDays ?? this.leadTimeDays,
        isQuarantined: isQuarantined ?? this.isQuarantined,
        notifyUserIds: notifyUserIds ?? this.notifyUserIds,
      );
}
