import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GdcColors {
  // New Color Hunt Theme Palette: #EDF1D6 #9DC08B #609966 #40513B
  static const cream           = Color(0xFFEDF1D6); // Background tint
  static const terracottaLight = Color(0xFF9DC08B); // Light sage green
  static const terracotta      = Color(0xFF609966); // Main branding green
  static const warmBrown       = Color(0xFF40513B); // Dark forest green
  
  static const terracottaDark  = Color(0xFF2E3B2B);
  static const peachLight      = Color(0xFFE2EBC2);
  
  // More grounded neutrals
  static const creamDark       = Color(0xFFDFE4C1);
  static const warmWhite       = Color(0xFFF7F9EE);
  
  static const success         = Color(0xFF2E7D32);
  static const warning         = Color(0xFFEF6C00);
  static const error           = Color(0xFFC62828);
  static const info            = Color(0xFF0277BD);
  
  static const textPrimary     = Color(0xFF1E261B);
  static const textSecondary   = Color(0xFF384734);
  static const textMuted       = Color(0xFF6E7E69);
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
        outline:        GdcColors.terracotta.withValues(alpha: 0.2), // Stronger outline
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme).copyWith(
        headlineLarge: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: GdcColors.textPrimary),
        headlineMedium: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: GdcColors.textPrimary),
        titleLarge:     GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: -0.2, color: GdcColors.textPrimary),
        titleMedium:    GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, color: GdcColors.terracotta),
        bodyLarge:      TextStyle(fontSize: 13, color: GdcColors.textPrimary),
        bodyMedium:     TextStyle(fontSize: 12, color: GdcColors.textPrimary),
        bodySmall:      TextStyle(fontSize: 11, color: GdcColors.textSecondary),
        labelSmall:     TextStyle(fontSize: 10, color: GdcColors.textMuted),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16), // Slightly tighter corners
          side: BorderSide(color: GdcColors.terracotta.withValues(alpha: 0.15)), // More visible border
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
        side: BorderSide(color: GdcColors.terracotta.withValues(alpha: 0.1)),
        backgroundColor: Colors.white,
        selectedColor: GdcColors.terracotta,
        disabledColor: Colors.grey.shade100,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: GdcColors.textPrimary),
        secondaryLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        labelStyle: const TextStyle(color: GdcColors.textSecondary),
        hintStyle: const TextStyle(color: GdcColors.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: GdcColors.terracotta.withValues(alpha: 0.15)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: GdcColors.terracotta.withValues(alpha: 0.15)),
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
        backgroundColor: Colors.white,
        elevation: 0,
        indicatorColor: GdcColors.peachLight,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        height: 80,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(color: GdcColors.terracotta, fontWeight: FontWeight.bold, fontSize: 12);
          }
          return const TextStyle(color: GdcColors.textMuted, fontSize: 12, fontWeight: FontWeight.w500);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: GdcColors.terracotta, size: 26);
          }
          return const IconThemeData(color: GdcColors.textMuted, size: 24);
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
