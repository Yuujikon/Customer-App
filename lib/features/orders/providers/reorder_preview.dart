import '../../../shared/models/order.dart';
import '../../../shared/models/product.dart';

class ReorderItemPreview {
  final CartItem originalItem;
  final Product? product;
  final int toAddQty;
  final int availableStock;
  final bool isUnavailable;
  final bool isAdjusted;

  ReorderItemPreview({
    required this.originalItem,
    this.product,
    required this.toAddQty,
    required this.availableStock,
    required this.isUnavailable,
    required this.isAdjusted,
  });
}
