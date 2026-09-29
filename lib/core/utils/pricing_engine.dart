import '../../shared/models/order.dart';
import '../../shared/models/product.dart';

class PricingBreakdown {
  final double total; // Final amount to pay

  const PricingBreakdown({
    required this.total,
  });
}

class PricingEngine {
  static PricingBreakdown calculate({
    required List<CartItem> items,
    required List<Product> allProducts,
  }) {
    double total = 0;

    for (final item in items) {
      Product? product;
      try {
        product = allProducts.firstWhere((p) => p.id == item.productId);
      } catch (_) {}

      final double price;
      if (item.variantId != null && product != null && product.variants != null) {
        price = product.variants![item.variantId]?.price ?? item.price;
      } else {
        price = product?.price ?? item.price;
      }
      
      final double itemTotal = price * item.qty;
      total += itemTotal;
    }

    return PricingBreakdown(
      total: total.clamp(0.0, double.infinity),
    );
  }
}
