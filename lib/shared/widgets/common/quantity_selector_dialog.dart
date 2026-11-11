import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/format.dart';

/// Reusable Professional Quantity Selector Dialog
class QuantitySelectorDialog extends StatefulWidget {
  final String title;
  final String productName;
  final double unitPrice;
  final int initialQty;
  final int maxStock;
  final Function(int newQty) onConfirm;

  const QuantitySelectorDialog({
    super.key,
    this.title = 'Modify Quantity',
    required this.productName,
    required this.unitPrice,
    required this.initialQty,
    required this.maxStock,
    required this.onConfirm,
  });

  @override
  State<QuantitySelectorDialog> createState() => _QuantitySelectorDialogState();
}

class _QuantitySelectorDialogState extends State<QuantitySelectorDialog> {
  late int _qty;

  @override
  void initState() {
    super.initState();
    _qty = widget.initialQty.clamp(1, widget.maxStock);
  }

  void _adjustQty(int delta) {
    setState(() {
      final newQty = _qty + delta;
      _qty = newQty.clamp(1, widget.maxStock);
    });
  }

  @override
  Widget build(BuildContext context) {
    final double itemSubtotal = widget.unitPrice * _qty;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Theme.of(context).cardColor,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Title & Close Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryText,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      size: 20, color: AppColors.mutedText),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Product Info Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warmSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.productName,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryText,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        formatPeso(widget.unitPrice),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: AppColors.forest,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.sageTint,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          '${widget.maxStock} in stock',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.forest,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Interactive Stepper Control
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Decrement Button
                InkWell(
                  onTap: _qty > 1 ? () => _adjustQty(-1) : null,
                  borderRadius: BorderRadius.circular(100),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color:
                          _qty > 1 ? AppColors.sageTint : AppColors.warmSurface,
                      border: Border.all(
                        color: _qty > 1 ? AppColors.forest : AppColors.border,
                      ),
                    ),
                    child: Icon(
                      Icons.remove_rounded,
                      color: _qty > 1 ? AppColors.forest : AppColors.mutedText,
                      size: 22,
                    ),
                  ),
                ),

                const SizedBox(width: 24),

                // Current Quantity Display Box
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border, width: 1.5),
                  ),
                  child: Text(
                    '$_qty',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primaryText,
                    ),
                  ),
                ),

                const SizedBox(width: 24),

                // Increment Button
                InkWell(
                  onTap: _qty < widget.maxStock ? () => _adjustQty(1) : null,
                  borderRadius: BorderRadius.circular(100),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _qty < widget.maxStock
                          ? AppColors.orangeCTA
                          : AppColors.warmSurface,
                      border: Border.all(
                        color: _qty < widget.maxStock
                            ? AppColors.orangeCTA
                            : AppColors.border,
                      ),
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      color: _qty < widget.maxStock
                          ? Colors.white
                          : AppColors.mutedText,
                      size: 22,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Item Subtotal Line
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Item Subtotal',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.mutedText,
                  ),
                ),
                Text(
                  formatPeso(itemSubtotal),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryText,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Primary Update Quantity Action Button
            ElevatedButton(
              onPressed: () {
                widget.onConfirm(_qty);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.orangeCTA,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100),
                ),
                elevation: 2,
              ),
              child: const Text(
                'Update Quantity',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
