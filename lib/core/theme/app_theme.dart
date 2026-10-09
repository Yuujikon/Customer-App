import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GdcColors {
  // Primary design tokens for GDC Store
  static const forest = Color(0xFF3E6B34); // Primary forest green
  static const deepForest = Color(0xFF284C25); // Deep forest green gradient
  static const sage = Color(0xFF8BAE3A); // Fresh sage accent
  static const sageTint = Color(0xFFE2ECD8); // Light sage tint / indicator pill
  static const cream = Color(0xFFF7F9F2); // Warm cream background
  static const surface = Color(0xFFFFFFFF); // White card surface
  static const warmSurface = Color(0xFFFAFCF7); // Warm white surface
  static const border = Color(0xFFE5EBDD); // Border line color
  static const primaryText = Color(0xFF1C2717); // Primary dark text
  static const mutedText = Color(0xFF6B7C65); // Muted secondary text
  static const orangeCTA =
      Color(0xFFE8702A); // Orange CTA ("Shop the catalog", "Confirm")
  static const darkOrange = Color(0xFFD35D1B); // Dark orange pressed state

  // Backward-compatible aliases for existing references
  static const terracottaLight = sage;
  static const terracotta = forest;
  static const warmBrown = Color(0xFF24331E);
  static const terracottaDark = Color(0xFF1B2B16);
  static const peachLight = sageTint;
  static const orangeCTALight = Color(0xFFFFF0E6);
  static const creamDark = border;
  static const warmWhite = warmSurface;

  static const success = Color(0xFF2E7D32);
  static const warning = Color(0xFFEF6C00);
  static const error = Color(0xFFC62828);
  static const info = Color(0xFF0277BD);

  static const textPrimary = primaryText;
  static const textSecondary = Color(0xFF384A32);
  static const textMuted = mutedText;
}

// Alias AppColors to GdcColors for clean design token usage
typedef AppColors = GdcColors;

class GdcTheme {
  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);
    return base
        .copyWith(
          colorScheme: ColorScheme.fromSeed(
            seedColor: GdcColors.terracotta,
            primary: GdcColors.terracotta,
            onPrimary: Colors.white,
            secondary: GdcColors.orangeCTA,
            onSecondary: Colors.white,
            surface: GdcColors.cream,
            onSurface: GdcColors.textPrimary,
            surfaceContainerLow: GdcColors.warmWhite,
            surfaceContainerHighest: GdcColors.peachLight,
            outline: GdcColors.terracotta.withValues(alpha: 0.15),
          ),
          scaffoldBackgroundColor: GdcColors.cream,
          textTheme:
              GoogleFonts.plusJakartaSansTextTheme(base.textTheme).copyWith(
            headlineLarge: GoogleFonts.plusJakartaSans(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                color: GdcColors.textPrimary),
            headlineMedium: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: GdcColors.textPrimary),
            titleLarge: GoogleFonts.plusJakartaSans(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: GdcColors.textPrimary),
            titleMedium: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: GdcColors.terracotta),
            bodyLarge: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: GdcColors.textPrimary),
            bodyMedium: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: GdcColors.textPrimary),
            bodySmall: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: GdcColors.textSecondary),
            labelSmall: GoogleFonts.plusJakartaSans(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: GdcColors.textMuted),
          ),
          cardTheme: CardThemeData(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Color(0xFFE5EBDD), width: 1),
            ),
          ),
          chipTheme: ChipThemeData(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(100)),
            side: const BorderSide(color: Color(0xFFE5EBDD), width: 1),
            backgroundColor: Colors.white,
            selectedColor: GdcColors.terracotta,
            disabledColor: Colors.grey.shade100,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            labelStyle: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: GdcColors.textPrimary),
            secondaryLabelStyle: GoogleFonts.plusJakartaSans(
                fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            labelStyle: const TextStyle(
                color: GdcColors.textSecondary, fontWeight: FontWeight.w600),
            hintStyle: const TextStyle(
                color: GdcColors.textMuted, fontWeight: FontWeight.w500),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(100),
              borderSide: const BorderSide(color: Color(0xFFE5EBDD)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(100),
              borderSide: const BorderSide(color: Color(0xFFE5EBDD)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(100),
              borderSide:
                  const BorderSide(color: GdcColors.terracotta, width: 2),
            ),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: GdcColors.orangeCTA,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(56),
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(100)),
              textStyle: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5),
            ),
          ),
          navigationBarTheme: NavigationBarThemeData(
            backgroundColor: Colors.white,
            elevation: 8,
            shadowColor: Colors.black.withValues(alpha: 0.08),
            indicatorColor: GdcColors.peachLight,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            height: 76,
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return GoogleFonts.plusJakartaSans(
                    color: GdcColors.terracotta,
                    fontWeight: FontWeight.w800,
                    fontSize: 11);
              }
              return GoogleFonts.plusJakartaSans(
                  color: GdcColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600);
            }),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return const IconThemeData(
                    color: GdcColors.terracotta, size: 26);
              }
              return const IconThemeData(color: GdcColors.textMuted, size: 24);
            }),
          ),
        )
        .addSemanticExtensions();
  }
}

extension on ThemeData {
  ThemeData addSemanticExtensions() {
    return copyWith(extensions: [
      GdcSemanticColors(
        perishable: const Color(0xFFD35400),
        fresh: const Color(0xFF1E8449),
        urgent: const Color(0xFFC0392B),
      ),
    ]);
  }
}

class GdcSemanticColors extends ThemeExtension<GdcSemanticColors> {
  final Color perishable;
  final Color fresh;
  final Color urgent;

  GdcSemanticColors(
      {required this.perishable, required this.fresh, required this.urgent});

  @override
  ThemeExtension<GdcSemanticColors> copyWith(
      {Color? perishable, Color? fresh, Color? urgent}) {
    return GdcSemanticColors(
      perishable: perishable ?? this.perishable,
      fresh: fresh ?? this.fresh,
      urgent: urgent ?? this.urgent,
    );
  }

  @override
  ThemeExtension<GdcSemanticColors> lerp(
      ThemeExtension<GdcSemanticColors>? other, double t) {
    if (other is! GdcSemanticColors) return this;
    return GdcSemanticColors(
      perishable: Color.lerp(perishable, other.perishable, t)!,
      fresh: Color.lerp(fresh, other.fresh, t)!,
      urgent: Color.lerp(urgent, other.urgent, t)!,
    );
  }
}
