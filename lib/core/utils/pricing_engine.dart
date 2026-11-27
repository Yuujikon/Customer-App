import '../../shared/models/order.dart';
import '../../shared/models/product.dart';

class PricingBreakdown {
  final double subtotal;
  final double vAtAmount;
  final double total; // Final amount to pay

  const PricingBreakdown({
    required this.subtotal,
    required this.vAtAmount,
    required this.total,
  });
}

class PricingEngine {
  static const double vatRate = 0.12;

  static PricingBreakdown calculate({
    required List<CartItem> items,
    required List<Product> allProducts,
  }) {
    double subtotal = 0;
    double taxableSubtotal = 0;

    for (final item in items) {
      Product? product;
      try {
        product = allProducts.firstWhere((p) => p.id == item.productId);
      } catch (_) {}

      final double price;
      if (item.variantId != null &&
          product != null &&
          product.variants != null) {
        price = product.variants![item.variantId]?.price ?? item.price;
      } else {
        price = product?.price ?? item.price;
      }

      final double itemSubtotal = price * item.qty;
      subtotal += itemSubtotal;

      if (product?.isTaxable ?? true) {
        taxableSubtotal += itemSubtotal;
      }
    }

    final finalVat = taxableSubtotal - (taxableSubtotal / (1 + vatRate));
    final total = subtotal.clamp(0.0, double.infinity);

    return PricingBreakdown(
      subtotal: subtotal,
      vAtAmount: finalVat,
      total: total,
    );
  }
}
