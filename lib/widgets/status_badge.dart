import 'package:flutter/material.dart';
import '../models/order.dart';
import '../config/theme.dart';

class StatusBadge extends StatelessWidget {
  final OrderStatus status;
  const StatusBadge(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      OrderStatus.pending   => ('Pending',   const Color(0xFFFFF3CD), const Color(0xFF856404)),
      OrderStatus.staging   => ('Packing',   const Color(0xFFCCE5FF), const Color(0xFF004085)),
      OrderStatus.ready     => ('Ready',     const Color(0xFFE8F5E9), GdcColors.success),
      OrderStatus.collected => ('Collected', const Color(0xFFE8F5E9), GdcColors.success),
      OrderStatus.cancelled => ('Cancelled', const Color(0xFFFDECEA), GdcColors.error),
      OrderStatus.refunded  => ('Refunded',  const Color(0xFFF5F5F5), GdcColors.textMuted),
      OrderStatus.refundRequested => ('Refund Requested', const Color(0xFFFFF3E0), GdcColors.warning),
      OrderStatus.refundRejected  => ('Refund Rejected',  const Color(0xFFFDECEA), GdcColors.error),
    };
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg, 
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: fg.withOpacity(0.2)),
      ),
      child: Text(
        label.toUpperCase(), 
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: fg, letterSpacing: 0.5),
      ),
    );
  }
}
