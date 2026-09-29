import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class BrandLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final Color? color;

  const BrandLogo({
    super.key, 
    this.size = 64, 
    this.showText = false,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = color ?? Theme.of(context).colorScheme.primary;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.15),
                blurRadius: size * 0.3,
                offset: Offset(0, size * 0.1),
              )
            ],
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/icon.jpg',
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Center(
                child: Icon(
                  Icons.storefront_rounded, 
                  size: size * 0.6, 
                  color: primaryColor,
                ),
              ),
            ),
          ),
        ),
        if (showText) ...[
          SizedBox(height: size * 0.2),
          Text(
            'GDC Store',
            style: TextStyle(
              fontSize: size * 0.3,
              fontWeight: FontWeight.w900,
              color: GdcColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ],
    );
  }
}
