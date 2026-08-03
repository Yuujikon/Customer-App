import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GdcColors {
  static const terracotta      = Color(0xFFB85C38);
  static const terracottaLight = Color(0xFFE28B6B);
  static const terracottaDark  = Color(0xFF8B3D1F);
  
  static const cream           = Color(0xFFFDF6EE);
  static const creamDark       = Color(0xFFF5EAD9);
  static const warmWhite       = Color(0xFFFFFBF5);
  static const warmBrown       = Color(0xFF7C4A2D);
  
  static const success         = Color(0xFF4CAF50);
  static const warning         = Color(0xFFFF9800);
  static const error           = Color(0xFFE53935);
  static const info            = Color(0xFF03A9F4);
}

class GdcTheme {
  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      colorScheme: ColorScheme.fromSeed(
        seedColor:      GdcColors.terracotta,
        primary:        GdcColors.terracotta,
        onPrimary:      Colors.white,
        secondary:      GdcColors.warmBrown,
        onSecondary:    Colors.white,
        surface:        GdcColors.warmWhite,
        onSurface:      const Color(0xFF2D241E),
        surfaceContainerLow: GdcColors.cream,
        surfaceContainerHighest: GdcColors.creamDark,
        outline:        GdcColors.terracotta.withOpacity(0.12),
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: GdcColors.terracotta.withOpacity(0.08)),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide.none,
        backgroundColor: GdcColors.cream,
        selectedColor: GdcColors.terracotta,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: GdcColors.terracotta.withOpacity(0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: GdcColors.terracotta.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: GdcColors.terracotta, width: 2),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: GdcColors.terracotta,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(54),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: GdcColors.terracotta.withOpacity(0.1),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 70,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: GdcColors.terracotta);
          }
          return const IconThemeData(color: Colors.grey);
        }),
      ),
    ).addSemanticExtensions();
  }
}

extension on ThemeData {
  ThemeData addSemanticExtensions() {
    return copyWith(extensions: [
      GdcSemanticColors(
        perishable: const Color(0xFFF57C00),
        fresh:      const Color(0xFF4CAF50),
        urgent:     const Color(0xFFE53935),
      ),
    ]);
  }
}

class GdcSemanticColors extends ThemeExtension<GdcSemanticColors> {
  final Color perishable;
  final Color fresh;
  final Color urgent;

  GdcSemanticColors({required this.perishable, required this.fresh, required this.urgent});

  @override
  ThemeExtension<GdcSemanticColors> copyWith({Color? perishable, Color? fresh, Color? urgent}) {
    return GdcSemanticColors(
      perishable: perishable ?? this.perishable,
      fresh:      fresh ?? this.fresh,
      urgent:     urgent ?? this.urgent,
    );
  }

  @override
  ThemeExtension<GdcSemanticColors> lerp(ThemeExtension<GdcSemanticColors>? other, double t) {
    if (other is! GdcSemanticColors) return this;
    return GdcSemanticColors(
      perishable: Color.lerp(perishable, other.perishable, t)!,
      fresh:      Color.lerp(fresh, other.fresh, t)!,
      urgent:     Color.lerp(urgent, other.urgent, t)!,
    );
  }
}
