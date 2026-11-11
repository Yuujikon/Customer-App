import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';

class QtyControl extends StatefulWidget {
  final int qty;
  final int? max;
  final ValueChanged<int> onChanged;

  const QtyControl({
    super.key,
    required this.qty,
    this.max,
    required this.onChanged,
  });

  @override
  State<QtyControl> createState() => _QtyControlState();
}

class _QtyControlState extends State<QtyControl> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: '${widget.qty}');
  }

  @override
  void didUpdateWidget(QtyControl old) {
    super.didUpdateWidget(old);
    if (old.qty != widget.qty && int.tryParse(_ctrl.text) != widget.qty) {
      _ctrl.text = '${widget.qty}';
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _showMaxReachedSnackBar(int maxAvailable) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Only $maxAvailable item${maxAvailable == 1 ? '' : 's'} available.'),
        backgroundColor: GdcColors.warning,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _adjust(int delta) {
    final maxVal = widget.max ?? 9999;
    final minVal = maxVal <= 0 ? 0 : 1;
    if (delta > 0 && widget.qty >= maxVal) {
      _showMaxReachedSnackBar(maxVal);
      return;
    }
    final upperLimit = maxVal > minVal ? maxVal : minVal;
    final next = (widget.qty + delta).clamp(minVal, upperLimit);
    _ctrl.text = '$next';
    _ctrl.selection = TextSelection.fromPosition(
      TextPosition(offset: _ctrl.text.length),
    );
    widget.onChanged(next);
  }

  void _onTextTyped(String text) {
    if (text.isEmpty) return;
    final val = int.tryParse(text);
    if (val != null) {
      final maxAvailable = widget.max ?? 9999;
      if (widget.max != null && val > widget.max!) {
        _showMaxReachedSnackBar(maxAvailable);
        final resetVal = maxAvailable < 1 ? 0 : maxAvailable;
        _ctrl.text = '$resetVal';
        _ctrl.selection = TextSelection.fromPosition(
          TextPosition(offset: _ctrl.text.length),
        );
        widget.onChanged(resetVal);
      } else {
        final minVal = maxAvailable <= 0 ? 0 : 1;
        final upperLimit = maxAvailable > minVal ? maxAvailable : minVal;
        final clamped = val.clamp(minVal, upperLimit);
        widget.onChanged(clamped);
      }
    }
  }

  void _commit() {
    final val = int.tryParse(_ctrl.text) ?? widget.qty;
    final maxAvailable = widget.max ?? 9999;
    if (widget.max != null && val > widget.max!) {
      _showMaxReachedSnackBar(maxAvailable);
      final resetVal = maxAvailable < 1 ? 0 : maxAvailable;
      _ctrl.text = '$resetVal';
      _ctrl.selection = TextSelection.fromPosition(
        TextPosition(offset: _ctrl.text.length),
      );
      widget.onChanged(resetVal);
    } else {
      final minVal = maxAvailable <= 0 ? 0 : 1;
      final upperLimit = maxAvailable > minVal ? maxAvailable : minVal;
      final clamped = val.clamp(minVal, upperLimit);
      _ctrl.text = '$clamped';
      _ctrl.selection = TextSelection.fromPosition(
        TextPosition(offset: _ctrl.text.length),
      );
      widget.onChanged(clamped);
    }
  }

  Widget _btn(IconData icon, int delta, VoidCallback onTap) {
    final bool disabled =
        (delta > 0 && widget.max != null && widget.qty >= widget.max!) ||
            (delta < 0 && widget.qty <= 1);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: disabled
              ? (isDark ? Theme.of(context).cardColor : Colors.grey.shade100)
              : primaryColor.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 16,
          color: disabled
              ? (isDark
                  ? Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.color
                      ?.withValues(alpha: 0.4)
                  : Colors.grey.shade400)
              : primaryColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? Theme.of(context).colorScheme.surfaceContainerLow
        : Colors.grey.shade50;
    final borderColor = Theme.of(context).dividerColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _btn(Icons.remove_rounded, -1, () => _adjust(-1)),
          SizedBox(
            width: 38,
            height: 32,
            child: Center(
              child: TextField(
                controller: _ctrl,
                textAlign: TextAlign.center,
                textAlignVertical: TextAlignVertical.center,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: _onTextTyped,
                onSubmitted: (_) => _commit(),
                onEditingComplete: _commit,
                decoration: const InputDecoration(
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                ),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
          _btn(Icons.add_rounded, 1, () => _adjust(1)),
        ],
      ),
    );
  }
}
