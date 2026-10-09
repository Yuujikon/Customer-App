import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

enum ProductStatus { draft, published }

enum ExpiryStatus { optimal, warning, critical, expired }

enum InventoryAbcCategory { categoryA, categoryB, categoryC }

class ProductVariant {
  final String id;
  final String name;
  final double price;
  final int stock;
  final int reservedStock;
  final int? initialStock;
  final String? barcode;

  const ProductVariant({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
    this.reservedStock = 0,
    this.initialStock,
    this.barcode,
  });

  int get availableStock => (stock - reservedStock).clamp(0, stock);

  int get effectiveInitialStock =>
      (initialStock != null && initialStock! > 0) ? initialStock! : stock;

  bool get isOutOfStockForCustomer => availableStock <= 0;

  int get maxPurchasableStock => availableStock > 0 ? availableStock : 0;

  factory ProductVariant.fromMap(String id, Map<String, dynamic> m) {
    return ProductVariant(
      id: id,
      name: m['name']?.toString() ?? 'Unnamed Variant',
      price: (m['price'] as num? ?? 0).toDouble(),
      stock: (m['stock'] as num? ?? 0).toInt(),
      reservedStock: (m['reservedStock'] as num? ?? 0).toInt(),
      initialStock: (m['initialStock'] as num?)?.toInt(),
      barcode: m['barcode']?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'price': price,
        'stock': stock,
        'reservedStock': reservedStock,
        'initialStock': initialStock ?? stock,
        if (barcode != null) 'barcode': barcode,
      };
}

class Product {
  final String id;
  final String name;
  final String category;
  final double price;
  final int stock;
  final int reservedStock;
  final int? initialStock;
  final String unit;
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
  final int lowStockThreshold;

  // Enterprise Industrial Automation Fields
  final double? costPrice;
  final int? reorderPoint;
  final int? reorderQuantity;
  final int? leadTimeDays;
  final bool isQuarantined;

  // Restock Notification Tracking
  final List<String> notifyUserIds;

  const Product({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.stock,
    this.reservedStock = 0,
    this.initialStock,
    this.unit = 'pcs',
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
    this.lowStockThreshold = 5,
    this.costPrice,
    this.reorderPoint,
    this.reorderQuantity,
    this.leadTimeDays,
    this.isQuarantined = false,
    this.notifyUserIds = const [],
  });

  bool get isPerishable => shelfDays != null || expiryDate != null;
  bool get hasVariants => variants != null && variants!.isNotEmpty;

  int get availableStock {
    final raw = stock - reservedStock;
    return raw < 0 ? 0 : raw;
  }

  int get totalStock {
    if (!hasVariants) return stock;
    return variants!.values.fold(0, (acc, v) => acc + v.stock);
  }

  int get totalAvailableStock {
    if (!hasVariants) return availableStock;
    return variants!.values.fold(0, (acc, v) => acc + v.availableStock);
  }

  int get effectiveInitialStock =>
      (initialStock != null && initialStock! > 0) ? initialStock! : stock;

  bool get isOutOfStockForCustomer {
    if (isQuarantined) return true;
    if (hasVariants) {
      if (variants == null || variants!.isEmpty)
        return totalAvailableStock <= 0;
      return variants!.values.every((v) => v.isOutOfStockForCustomer);
    } else {
      return availableStock <= 0;
    }
  }

  int get maxPurchasableStock {
    if (isQuarantined) return 0;
    if (hasVariants) {
      if (variants == null) return 0;
      return variants!.values.fold(0, (acc, v) => acc + v.maxPurchasableStock);
    } else {
      return availableStock > 0 ? availableStock : 0;
    }
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
    return expiryDate!.difference(DateTime.now()).inDays;
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
      if (d['variants'] != null && d['variants'] is Map) {
        variantsMap = (d['variants'] as Map<String, dynamic>).map((k, v) =>
            MapEntry(k, ProductVariant.fromMap(k, v as Map<String, dynamic>)));
      }

      return Product(
        id: doc.id,
        name: d['name']?.toString() ?? 'Unnamed Product',
        category: d['category']?.toString() ?? 'Others',
        price: (d['price'] as num? ?? 0).toDouble(),
        stock: (d['stock'] as num? ?? 0).toInt(),
        reservedStock: (d['reservedStock'] as num? ?? 0).toInt(),
        initialStock: (d['initialStock'] as num?)?.toInt(),
        unit: d['unit']?.toString() ?? 'pcs',
        barcode: d['barcode']?.toString(),
        shelfDays: (d['shelfDays'] as num?)?.toInt(),
        pickupWindowHours: (d['pickupWindowHours'] as num?)?.toInt(),
        photoBase64: d['photoBase64']?.toString(),
        wholesalePrice: (d['wholesalePrice'] as num?)?.toDouble(),
        wholesaleThreshold: (d['wholesaleThreshold'] as num?)?.toInt(),
        supplierId: d['supplierId']?.toString(),
        expiryDate: (d['expiryDate'] as Timestamp?)?.toDate(),
        variants: variantsMap,
        status: ProductStatus.values.firstWhere(
          (e) => e.name == (d['status'] ?? 'published'),
          orElse: () => ProductStatus.published,
        ),
        lowStockThreshold: (d['lowStockThreshold'] as num? ?? 5).toInt(),
        costPrice: (d['costPrice'] as num?)?.toDouble(),
        reorderPoint: (d['reorderPoint'] as num?)?.toInt(),
        reorderQuantity: (d['reorderQuantity'] as num?)?.toInt(),
        leadTimeDays: (d['leadTimeDays'] as num?)?.toInt(),
        isQuarantined: d['isQuarantined'] as bool? ?? false,
        notifyUserIds: (d['notifyUserIds'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
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
        'category': category,
        'price': price,
        'stock': stock,
        'reservedStock': reservedStock,
        'initialStock': initialStock ?? stock,
        'unit': unit,
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
        'lowStockThreshold': lowStockThreshold,
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
    String? barcode,
    String? photoBase64,
    int? pickupWindowHours,
    ProductStatus? status,
    int? lowStockThreshold,
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
        category: category,
        price: price,
        stock: stock ?? this.stock,
        reservedStock: reservedStock ?? this.reservedStock,
        initialStock: initialStock ?? this.initialStock,
        unit: unit,
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
        lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
        costPrice: costPrice ?? this.costPrice,
        reorderPoint: reorderPoint ?? this.reorderPoint,
        reorderQuantity: reorderQuantity ?? this.reorderQuantity,
        leadTimeDays: leadTimeDays ?? this.leadTimeDays,
        isQuarantined: isQuarantined ?? this.isQuarantined,
        notifyUserIds: notifyUserIds ?? this.notifyUserIds,
      );
}
