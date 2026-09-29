import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

enum ProductStatus { draft, published }

class ProductVariant {
  final String id;
  final String name;
  final double price;
  final int stock;
  final int? initialStock;
  final String? barcode;

  const ProductVariant({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
    this.initialStock,
    this.barcode,
  });

  int get effectiveInitialStock => (initialStock != null && initialStock! > 0) ? initialStock! : stock;

  bool get isOutOfStockForCustomer => stock <= 0;

  int get maxPurchasableStock => stock > 0 ? stock : 0;

  factory ProductVariant.fromMap(String id, Map<String, dynamic> m) {
    return ProductVariant(
      id: id,
      name: m['name']?.toString() ?? 'Unnamed Variant',
      price: (m['price'] as num? ?? 0).toDouble(),
      stock: (m['stock'] as num? ?? 0).toInt(),
      initialStock: (m['initialStock'] as num?)?.toInt(),
      barcode: m['barcode']?.toString(),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'price': price,
    'stock': stock,
    'initialStock': initialStock ?? stock,
    if (barcode != null) 'barcode': barcode,
  };
}

class Product {
  final String id;
  final String name;
  final String category;
  final double price;
  final int    stock;
  final int?   initialStock;
  final String unit; 
  final String? barcode;     
  final int?   shelfDays;   
  final int?   pickupWindowHours; 
  final String? photoBase64; 
  final double? wholesalePrice;
  final int?    wholesaleThreshold;
  final String? supplierId;
  final DateTime? expiryDate;
  final Map<String, ProductVariant>? variants;

  final ProductStatus status;
  final int lowStockThreshold;

  const Product({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.stock,
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
  });

  bool get isPerishable => shelfDays != null;
  bool get hasVariants => variants != null && variants!.isNotEmpty;

  int get totalStock {
    if (!hasVariants) return stock;
    return variants!.values.fold(0, (acc, v) => acc + v.stock);
  }

  int get effectiveInitialStock => (initialStock != null && initialStock! > 0) ? initialStock! : stock;

  bool get isOutOfStockForCustomer {
    if (hasVariants) {
      if (variants == null || variants!.isEmpty) return totalStock <= 0;
      return variants!.values.every((v) => v.isOutOfStockForCustomer);
    } else {
      return stock <= 0;
    }
  }

  int get maxPurchasableStock {
    if (hasVariants) {
      if (variants == null) return 0;
      return variants!.values.fold(0, (acc, v) => acc + v.maxPurchasableStock);
    } else {
      return stock > 0 ? stock : 0;
    }
  }

  List<double> get priceRange {
    if (!hasVariants) return [price];
    final prices = variants!.values.map((v) => v.price).toList();
    if (prices.isEmpty) return [price];
    prices.sort();
    return [prices.first, prices.last];
  }

  factory Product.fromFirestore(DocumentSnapshot doc) {
    try {
      final d = doc.data() as Map<String, dynamic>? ?? {};
      
      Map<String, ProductVariant>? variantsMap;
      if (d['variants'] != null && d['variants'] is Map) {
        variantsMap = (d['variants'] as Map<String, dynamic>).map(
          (k, v) => MapEntry(k, ProductVariant.fromMap(k, v as Map<String, dynamic>))
        );
      }

      return Product(
        id:        doc.id,
        name:      d['name']?.toString() ?? 'Unnamed Product',
        category:  d['category']?.toString() ?? 'Others',
        price:     (d['price'] as num? ?? 0).toDouble(),
        stock:     (d['stock'] as num? ?? 0).toInt(),
        initialStock: (d['initialStock'] as num?)?.toInt(),
        unit:      d['unit']?.toString() ?? 'pcs',
        barcode:   d['barcode']?.toString(),
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
      );
    } catch (e) {
      debugPrint('Error parsing product ${doc.id}: $e');
      return Product(id: doc.id, name: 'Error Loading', category: 'Error', price: 0, stock: 0);
    }
  }

  Map<String, dynamic> toFirestore() => {
    'name':      name,
    'category':  category,
    'price':     price,
    'stock':     stock,
    'initialStock': initialStock ?? stock,
    'unit':      unit,
    'barcode':   barcode,
    'shelfDays': shelfDays,
    'pickupWindowHours': pickupWindowHours,
    'photoBase64': photoBase64,
    'wholesalePrice': wholesalePrice,
    'wholesaleThreshold': wholesaleThreshold,
    'supplierId': supplierId,
    'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate!) : null,
    'variants': variants?.map((k, v) => MapEntry(k, v.toMap())),
    'status':    status.name,
    'lowStockThreshold': lowStockThreshold,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  Product copyWith({
    int? stock, 
    int? initialStock,
    String? barcode, 
    String? photoBase64, 
    int? pickupWindowHours,
    ProductStatus? status,
    int? lowStockThreshold,
    Map<String, ProductVariant>? variants,
  }) => Product(
    id: id, name: name, category: category,
    price: price, stock: stock ?? this.stock,
    initialStock: initialStock ?? this.initialStock,
    unit: unit, shelfDays: shelfDays,
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
  );
}
