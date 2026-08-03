import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GdcColors {
  static const terracotta      = Color(0xFFB85C38);
  static const terracottaLight = Color(0xFFE28B6B);
  static const terracottaDark  = Color(0xFF8B3D1F);
  
  // More grounded neutrals
  static const cream           = Color(0xFFF9F3EB); // Slightly darker
  static const creamDark       = Color(0xFFF2E4D0);
  static const warmWhite       = Color(0xFFFEFAF5);
  static const warmBrown       = Color(0xFF5D3A26); // Darker for better contrast
  
  static const success         = Color(0xFF2E7D32); // Darker green
  static const warning         = Color(0xFFEF6C00); // Darker orange
  static const error           = Color(0xFFC62828); // Darker red
  static const info            = Color(0xFF0277BD);
  
  static const textPrimary     = Color(0xFF2D241E);
  static const textSecondary   = Color(0xFF5A4D46);
  static const textMuted       = Color(0xFF8D7F78);
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
        surface:        GdcColors.cream, // Use cream as surface to reduce "white bloom"
        onSurface:      GdcColors.textPrimary,
        surfaceContainerLow: GdcColors.warmWhite,
        surfaceContainerHighest: GdcColors.creamDark,
        outline:        GdcColors.terracotta.withOpacity(0.2), // Stronger outline
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme).copyWith(
        bodyMedium: TextStyle(color: GdcColors.textPrimary),
        bodySmall:  TextStyle(color: GdcColors.textSecondary),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16), // Slightly tighter corners
          side: BorderSide(color: GdcColors.terracotta.withOpacity(0.15)), // More visible border
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: GdcColors.terracotta.withOpacity(0.2)),
        backgroundColor: Colors.white,
        selectedColor: GdcColors.terracotta,
        disabledColor: Colors.grey.shade100,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: GdcColors.textPrimary),
        secondaryLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: const TextStyle(color: GdcColors.textSecondary),
        hintStyle: const TextStyle(color: GdcColors.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: GdcColors.terracotta.withOpacity(0.15)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: GdcColors.terracotta.withOpacity(0.15)),
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
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: GdcColors.cream,
        indicatorColor: GdcColors.terracotta.withOpacity(0.1),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 70,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(color: GdcColors.terracotta, fontWeight: FontWeight.bold, fontSize: 12);
          }
          return const TextStyle(color: GdcColors.textMuted, fontSize: 12);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: GdcColors.terracotta);
          }
          return const IconThemeData(color: GdcColors.textMuted);
        }),
      ),
    ).addSemanticExtensions();
  }
}

extension on ThemeData {
  ThemeData addSemanticExtensions() {
    return copyWith(extensions: [
      GdcSemanticColors(
        perishable: const Color(0xFFD35400), // More contrast
        fresh:      const Color(0xFF1E8449),
        urgent:     const Color(0xFFC0392B),
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
