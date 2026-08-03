import 'package:flutter/material.dart';
import '../models/order.dart';

class StatusBadge extends StatelessWidget {
  final OrderStatus status;
  const StatusBadge(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      OrderStatus.pending   => ('Pending',   const Color(0xFFFFF3CD), const Color(0xFF856404)),
      OrderStatus.staging   => ('Packing',   const Color(0xFFCCE5FF), const Color(0xFF004085)),
      OrderStatus.ready     => ('Ready',     const Color(0xFFD4EDDA), const Color(0xFF155724)),
      OrderStatus.collected => ('Collected', const Color(0xFFD4EDDA), const Color(0xFF155724)),
      OrderStatus.cancelled => ('Cancelled', const Color(0xFFF8D7DA), const Color(0xFF721C24)),
      OrderStatus.refunded  => ('Refunded',  const Color(0xFFE2E3E5), const Color(0xFF383D41)),
      OrderStatus.refund_requested => ('Refund Requested', const Color(0xFFFFF3E0), const Color(0xFFE65100)),
      OrderStatus.refund_rejected  => ('Refund Rejected',  const Color(0xFFF8D7DA), const Color(0xFF721C24)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(50)),
      child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}