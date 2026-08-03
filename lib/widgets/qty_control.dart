import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/theme.dart';

class QtyControl extends StatefulWidget {
  final int qty;
  final int? max;
  final ValueChanged<int> onChanged;
  const QtyControl({super.key, required this.qty, this.max, required this.onChanged});
  @override State<QtyControl> createState() => _QtyControlState();
}

class _QtyControlState extends State<QtyControl> {
  late TextEditingController _ctrl;
  @override void initState() { super.initState(); _ctrl = TextEditingController(text: '${widget.qty}'); }
  @override void didUpdateWidget(QtyControl old) {
    super.didUpdateWidget(old);
    if (old.qty != widget.qty) _ctrl.text = '${widget.qty}';
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }

  void _adjust(int delta) {
    final next = (widget.qty + delta).clamp(1, widget.max ?? 9999);
    widget.onChanged(next);
  }

  void _commit() {
    final next = (int.tryParse(_ctrl.text) ?? widget.qty).clamp(1, widget.max ?? 9999);
    widget.onChanged(next);
  }

  Widget _btn(String label, int delta, VoidCallback onTap) {
    final bool disabled = (delta > 0 && widget.max != null && widget.qty >= widget.max!) ||
                          (delta < 0 && widget.qty <= 1);

    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Opacity(
        opacity: disabled ? 0.3 : 1.0,
        child: Container(width: 28, height: 28,
            decoration: BoxDecoration(color: const Color(0xFFF0F0F0), shape: BoxShape.circle, border: Border.all(color: Colors.black.withOpacity(0.05))),
            alignment: Alignment.center,
            child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: GdcColors.textPrimary))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    _btn('-5', -5, () => _adjust(-5)), const SizedBox(width: 4),
    _btn('−', -1, () => _adjust(-1)), const SizedBox(width: 6),
    SizedBox(width: 38, height: 34,
        child: TextField(controller: _ctrl, textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onSubmitted: (_) => _commit(), onEditingComplete: _commit,
            decoration: InputDecoration(contentPadding: EdgeInsets.zero,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: GdcColors.terracotta.withOpacity(0.1))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: GdcColors.terracotta.withOpacity(0.1))),
                filled: true, fillColor: Colors.white),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: GdcColors.terracotta))),
    const SizedBox(width: 6), 
    _btn('+', 1, () => _adjust(1)),
    const SizedBox(width: 4), 
    _btn('+5', 5, () => _adjust(5)),
  ]);
}
