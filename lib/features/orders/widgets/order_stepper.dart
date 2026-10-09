import 'package:flutter/material.dart';
import '../../../shared/models/order.dart';
import '../../../core/theme/app_theme.dart';

class OrderStepper extends StatelessWidget {
  final OrderStatus status;
  const OrderStepper({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    int currentIndex = switch (status) {
      OrderStatus.pending => 0,
      OrderStatus.staging => 1,
      OrderStatus.ready => 2,
      OrderStatus.collected => 3,
      _ => -1,
    };

    if (currentIndex == -1) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9F3),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5EBDD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ORDER TRACKING',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: GdcColors.terracotta,
                  letterSpacing: 1)),
          const SizedBox(height: 16),
          _buildStep(
            index: 0,
            current: currentIndex,
            label: 'Order Placed',
            subtitle: 'Order received by store.',
            isLast: false,
          ),
          _buildStep(
            index: 1,
            current: currentIndex,
            label: 'Order Confirmed & Packing',
            subtitle: 'Store attendant is gathering fresh items.',
            isLast: false,
          ),
          _buildStep(
            index: 2,
            current: currentIndex,
            label: 'Ready for Pickup',
            subtitle: 'Items packed and ready for pickup.',
            isLast: false,
          ),
          _buildStep(
            index: 3,
            current: currentIndex,
            label: 'Order Picked Up',
            subtitle: 'Order completed in-store.',
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildStep({
    required int index,
    required int current,
    required String label,
    required String subtitle,
    required bool isLast,
  }) {
    final isDone = index < current;
    final isActive = index == current;
    final activeColor = isDone
        ? GdcColors.success
        : (isActive ? GdcColors.orangeCTA : Colors.grey.shade300);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isDone || isActive ? activeColor : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: activeColor, width: 2),
                  boxShadow: isActive
                      ? [
                          BoxShadow(
                            color: activeColor.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          )
                        ]
                      : null,
                ),
                child: Center(
                  child: isDone
                      ? const Icon(Icons.check_rounded,
                          size: 14, color: Colors.white)
                      : (isActive
                          ? Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                  color: Colors.white, shape: BoxShape.circle))
                          : null),
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: isDone ? GdcColors.success : Colors.grey.shade200,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        isActive || isDone ? FontWeight.w900 : FontWeight.w700,
                    color: isActive || isDone
                        ? GdcColors.textPrimary
                        : Colors.grey.shade400,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: isActive
                        ? GdcColors.textSecondary
                        : Colors.grey.shade500,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                if (!isLast) const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
