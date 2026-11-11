import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class CancelOrderDialog extends StatefulWidget {
  final String orderId;

  const CancelOrderDialog({super.key, required this.orderId});

  @override
  State<CancelOrderDialog> createState() => _CancelOrderDialogState();
}

class _CancelOrderDialogState extends State<CancelOrderDialog> {
  int _selectedReasonIndex = -1;

  final List<String> _reasons = [
    'Need to change items / quantity',
    'Selected wrong pickup window',
    'Ordered by mistake',
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      backgroundColor: GdcColors.cream,
      child: Padding(
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
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.warning_rounded,
                    color: Colors.red.shade700,
                    size: 24,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context, false),
                  child: const Icon(Icons.close, color: Colors.black54),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Cancel Order #${widget.orderId}?',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: GdcColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Are you sure you want to cancel this order? This action cannot be undone and reserved items will be returned to stock.',
              style: TextStyle(
                fontSize: 14,
                color: GdcColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'REASON FOR CANCELLATION',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: GdcColors.textSecondary,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            ...List.generate(_reasons.length, (index) {
              final isSelected = _selectedReasonIndex == index;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedReasonIndex = index;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.white
                          : GdcColors.sage.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color:
                            isSelected ? GdcColors.forest : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked,
                          color: isSelected
                              ? GdcColors.forest
                              : GdcColors.textSecondary.withValues(alpha: 0.5),
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _reasons[index],
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: GdcColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    child: const Text(
                      'Keep Order',
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
                    onPressed: _selectedReasonIndex != -1
                        ? () => Navigator.pop(context, true)
                        : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: const Color(0xFFCE1B3D),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      disabledBackgroundColor:
                          const Color(0xFFCE1B3D).withValues(alpha: 0.5),
                    ),
                    child: const Text(
                      'Yes, Cancel',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
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
}
