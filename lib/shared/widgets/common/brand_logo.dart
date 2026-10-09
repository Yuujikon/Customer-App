import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// Reusable GDC Store Brand Logo widget according to specification & design system.
class GdcLogo extends StatelessWidget {
  final double size;
  final bool isExpanded;
  final bool showText;
  final bool showSubtitle;

  const GdcLogo({
    super.key,
    this.size = 40,
    this.isExpanded = false,
    this.showText = false,
    this.showSubtitle = true,
  });

  @override
  Widget build(BuildContext context) {
    final bool expanded = isExpanded || showText;

    // Asymmetrical organic rounded tile (top-left 14, top-right 6, bottom-left 14, bottom-right 14)
    final Widget tile = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.forest,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(14),
          topRight: Radius.circular(6),
          bottomLeft: Radius.circular(14),
          bottomRight: Radius.circular(14),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.forest.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Center(
        child: Text(
          'G',
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.58,
            fontWeight: FontWeight.w900,
            height: 1.0,
            letterSpacing: -0.5,
          ),
        ),
      ),
    );

    if (!expanded) {
      return tile;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        tile,
        const SizedBox(width: 12),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'GDC Store',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: AppColors.primaryText,
                letterSpacing: -0.3,
                height: 1.1,
              ),
            ),
            if (showSubtitle) ...[
              const SizedBox(height: 2),
              const Text(
                'GOOD DAILY CHOICES',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  color: AppColors.mutedText,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Backward compatibility alias for BrandLogo
typedef BrandLogo = GdcLogo;
