import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/format.dart';

/// Reusable Professional Quantity Selector Dialog
class QuantitySelectorDialog extends StatefulWidget {
  final String title;
  final String productName;
  final String? variantName;
  final double unitPrice;
  final int initialQty;
  final int maxStock;
  final void Function(int newQty) onConfirm;

  const QuantitySelectorDialog({
    super.key,
    this.title = 'Modify Quantity',
    required this.productName,
    this.variantName,
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
  late final TextEditingController _qtyController;
  late final FocusNode _qtyFocusNode;
  String? _limitWarning;

  int get _safeMaxStock => widget.maxStock < 1 ? 1 : widget.maxStock;

  @override
  void initState() {
    super.initState();
    _qty = widget.initialQty.clamp(1, _safeMaxStock);
    _qtyController = TextEditingController(text: '$_qty');
    _qtyFocusNode = FocusNode();
    _qtyFocusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _qtyFocusNode.removeListener(_onFocusChanged);
    _qtyFocusNode.dispose();
    _qtyController.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_qtyFocusNode.hasFocus) {
      _qtyController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _qtyController.text.length,
      );
    } else if (_qtyController.text.trim().isEmpty) {
      _syncControllerText('$_qty');
    }
  }

  void _syncControllerText(String text) {
    _qtyController.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _adjustQty(int delta) {
    setState(() {
      final int target = _qty + delta;
      if (target > _safeMaxStock) {
        _qty = _safeMaxStock;
        _limitWarning = 'Maximum available stock is $_safeMaxStock.';
      } else {
        _qty = target.clamp(1, _safeMaxStock);
        _limitWarning = null;
      }
      _syncControllerText('$_qty');
    });
  }

  void _onTextChanged(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _limitWarning = null;
      });
      return;
    }

    final parsed = int.tryParse(trimmed);
    if (parsed == null) return;

    setState(() {
      if (parsed < 1) {
        _limitWarning = 'Quantity must be at least 1.';
      } else if (parsed > _safeMaxStock) {
        _qty = _safeMaxStock;
        _limitWarning = 'Maximum available stock is $_safeMaxStock.';
        _syncControllerText('$_qty');
      } else {
        _qty = parsed;
        _limitWarning = null;
      }
    });
  }

  void _confirm() {
    final trimmed = _qtyController.text.trim();
    final parsed = int.tryParse(trimmed);
    if (parsed == null || parsed < 1) {
      setState(() {
        _limitWarning = 'Please enter a valid quantity (at least 1).';
      });
      return;
    }

    final finalQty = parsed.clamp(1, _safeMaxStock);
    widget.onConfirm(finalQty);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final int displayQty = (int.tryParse(_qtyController.text.trim()) ?? _qty)
        .clamp(0, _safeMaxStock);
    final double itemSubtotal = widget.unitPrice * displayQty;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color primaryTextColor = Theme.of(context).colorScheme.onSurface;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Theme.of(context).cardColor,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: SingleChildScrollView(
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
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: primaryTextColor,
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
                  color: isDark
                      ? Theme.of(context).colorScheme.surfaceContainerLow
                      : AppColors.warmSurface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.productName,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: primaryTextColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.variantName != null &&
                        widget.variantName!.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.variantName!.trim(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.forest,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
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

              // Interactive Stepper + Direct Input Control
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Decrement Button
                  Material(
                    color:
                        _qty > 1 ? AppColors.sageTint : AppColors.warmSurface,
                    shape: CircleBorder(
                      side: BorderSide(
                        color: _qty > 1 ? AppColors.forest : AppColors.border,
                      ),
                    ),
                    child: InkWell(
                      onTap: _qty > 1 ? () => _adjustQty(-1) : null,
                      customBorder: const CircleBorder(),
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Icon(
                          Icons.remove_rounded,
                          color:
                              _qty > 1 ? AppColors.forest : AppColors.mutedText,
                          size: 22,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 20),

                  // Editable Quantity Input Box
                  SizedBox(
                    width: 84,
                    child: TextField(
                      controller: _qtyController,
                      focusNode: _qtyFocusNode,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      textAlign: TextAlign.center,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: _onTextChanged,
                      onSubmitted: (_) => _confirm(),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: primaryTextColor,
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: isDark
                            ? Theme.of(context).colorScheme.surfaceContainerHigh
                            : Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppColors.border, width: 1.5),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppColors.border, width: 1.5),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: AppColors.orangeCTA, width: 1.8),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 20),

                  // Increment Button
                  Material(
                    color: _qty < _safeMaxStock
                        ? AppColors.orangeCTA
                        : AppColors.warmSurface,
                    shape: CircleBorder(
                      side: BorderSide(
                        color: _qty < _safeMaxStock
                            ? AppColors.orangeCTA
                            : AppColors.border,
                      ),
                    ),
                    child: InkWell(
                      onTap: _qty < _safeMaxStock ? () => _adjustQty(1) : null,
                      customBorder: const CircleBorder(),
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Icon(
                          Icons.add_rounded,
                          color: _qty < _safeMaxStock
                              ? Colors.white
                              : AppColors.mutedText,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              if (_limitWarning != null) ...[
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    _limitWarning!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.orangeCTA,
                    ),
                  ),
                ),
              ],

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
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: primaryTextColor,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Primary Update Quantity Action Button
              ElevatedButton(
                onPressed: _confirm,
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
      ),
    );
  }
}
