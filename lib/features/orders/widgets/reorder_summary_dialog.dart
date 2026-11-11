import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../providers/reorder_preview.dart';
import '../../../core/utils/format.dart';
import '../../shop/screens/shop_screen.dart'; // to browse similar? Wait, maybe just pop and callback

class ReorderSummaryDialog extends StatelessWidget {
  final List<ReorderItemPreview> previews;
  final VoidCallback onConfirm;
  final Function(String category) onBrowseSimilar;

  const ReorderSummaryDialog({
    super.key,
    required this.previews,
    required this.onConfirm,
    required this.onBrowseSimilar,
  });

  @override
  Widget build(BuildContext context) {
    final available = previews.where((p) => !p.isUnavailable).toList();
    final unavailable = previews.where((p) => p.isUnavailable).toList();

    int addedItemsCount = 0;
    for (var p in available) {
      addedItemsCount += p.toAddQty;
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: GdcColors.cream,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.orangeCTA.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.warning_rounded,
                    color: AppColors.orangeCTA,
                    size: 24,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Colors.black54),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Reorder Summary',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: GdcColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Some items from your previous order are unavailable or have limited stock. We\'ve adjusted your cart.',
              style: TextStyle(
                fontSize: 14,
                color: GdcColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (available.isNotEmpty) ...[
                      const Text(
                        'ADDED TO CART (ADJUSTED)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: GdcColors.textSecondary,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...available.map((p) => _buildAddedItem(context, p)),
                      const SizedBox(height: 16),
                    ],
                    if (unavailable.isNotEmpty) ...[
                      const Text(
                        'UNAVAILABLE ITEMS (SKIPPED)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: GdcColors.textSecondary,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...unavailable
                          .map((p) => _buildUnavailableItem(context, p)),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: GdcColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: available.isNotEmpty
                        ? () {
                            onConfirm();
                            Navigator.pop(context);
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppColors.orangeCTA,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      disabledBackgroundColor:
                          AppColors.orangeCTA.withValues(alpha: 0.5),
                    ),
                    child: Text(
                      'Proceed to Cart (${available.length} items)',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddedItem(BuildContext context, ReorderItemPreview p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${p.toAddQty}x ',
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              Expanded(
                child: Text(
                  p.product?.name ?? p.originalItem.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                formatPeso(
                    (p.product?.price ?? p.originalItem.price) * p.toAddQty),
                style:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
            ],
          ),
          if (p.isAdjusted) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.orangeCTA.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Adjusted to max available stock (${p.availableStock} left)',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.warmBrown,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUnavailableItem(BuildContext context, ReorderItemPreview p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GdcColors.sage.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${p.originalItem.qty}x ',
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: Colors.black54),
              ),
              Expanded(
                child: Text(
                  p.product?.name ?? p.originalItem.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.black54),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                'Out of Stock',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: Colors.red.shade700),
              ),
            ],
          ),
          if (p.product?.category != null) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                Navigator.pop(context);
                onBrowseSimilar(p.product!.category);
              },
              child: Row(
                children: [
                  const Text(
                    'Browse Similar Items',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.forest,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.forest,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_outward_rounded,
                      size: 14, color: AppColors.forest),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
