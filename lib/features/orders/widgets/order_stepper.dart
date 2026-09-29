import 'package:flutter/material.dart';
import '../../../shared/models/order.dart';
import '../../../core/theme/app_theme.dart';

class OrderStepper extends StatelessWidget {
  final OrderStatus status;
  const OrderStepper({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    // Determine current index based on status
    int currentIndex = switch (status) {
      OrderStatus.pending => 0,
      OrderStatus.staging => 1,
      OrderStatus.ready   => 2,
      OrderStatus.collected => 3,
      _ => -1, // For special statuses like cancelled or refunded
    };

    if (currentIndex == -1) return const SizedBox.shrink();

    return Column(
      children: [
        _buildStep(
          index: 0,
          current: currentIndex,
          label: 'Order Placed',
          subtitle: 'We have received your order.',
          icon: Icons.assignment_turned_in_outlined,
          isLast: false,
        ),
        _buildStep(
          index: 1,
          current: currentIndex,
          label: 'Packing',
          subtitle: 'Store is preparing your items.',
          icon: Icons.inventory_2_outlined,
          isLast: false,
        ),
        _buildStep(
          index: 2,
          current: currentIndex,
          label: 'Ready for Pickup',
          subtitle: 'Visit the store to collect.',
          icon: Icons.shopping_bag_outlined,
          isLast: false,
        ),
        _buildStep(
          index: 3,
          current: currentIndex,
          label: 'Completed',
          subtitle: 'Items collected successfully.',
          icon: Icons.check_circle_outline_rounded,
          isLast: true,
        ),
      ],
    );
  }

  Widget _buildStep({
    required int index,
    required int current,
    required String label,
    required String subtitle,
    required IconData icon,
    required bool isLast,
  }) {
    final isDone = index < current;
    final isActive = index == current;
    final color = isDone ? GdcColors.success : (isActive ? GdcColors.terracotta : Colors.grey.shade300);

    return IntrinsicHeight(
      child: Row(
        children: [
          Column(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: isActive ? color : color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: Icon(
                  isDone ? Icons.check : icon,
                  size: 16,
                  color: isActive ? Colors.white : color,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
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
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isActive || isDone ? FontWeight.w900 : FontWeight.w700,
                    color: isActive || isDone ? GdcColors.textPrimary : GdcColors.textMuted,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isActive ? GdcColors.textSecondary : GdcColors.textMuted,
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
