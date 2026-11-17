import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'nutrient_colors.dart';

class AppTheme {
  /// Default seed color (refined botanical sage / emerald)
  static const Color defaultSeedColor = Color(0xFF10B981);

  // Material 3 Expressive Corner Radius Scale (tokens.md)
  static const double radiusHero = 32.0; // CornerExtraLargeIncreased
  static const double radiusSheet = 28.0; // CornerExtraLargeTop
  static const double radiusCard = 20.0; // CornerLargeIncreased
  static const double radiusSmall = 12.0; // CornerMedium
  static const double radiusInner = 12.0; // Optical nested radius

  static ThemeData buildTheme({
    ColorScheme? dynamicScheme,
    required Brightness brightness,
  }) {
    final isDark = brightness == Brightness.dark;
    final colorScheme = dynamicScheme ??
        ColorScheme.fromSeed(
          seedColor: defaultSeedColor,
          brightness: brightness,
        );

    final baseTextTheme = isDark
        ? ThemeData.dark().textTheme
        : ThemeData.light().textTheme;

    // M3 Expressive Dual-Font Typography:
    // - Plus Jakarta Sans (w700/w800) for display, headlines, titles, and CTA labels
    // - Inter for dense ingredient lists, body copy, and tabular numeric metadata
    final textTheme = GoogleFonts.interTextTheme(baseTextTheme).copyWith(
      displayLarge: GoogleFonts.plusJakartaSans(
        textStyle: baseTextTheme.displayLarge,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.0,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      displayMedium: GoogleFonts.plusJakartaSans(
        textStyle: baseTextTheme.displayMedium,
        fontSize: 36,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        height: 1.08,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      headlineSmall: GoogleFonts.plusJakartaSans(
        textStyle: baseTextTheme.headlineSmall,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      titleLarge: GoogleFonts.plusJakartaSans(
        textStyle: baseTextTheme.titleLarge,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.25,
      ),
      titleMedium: GoogleFonts.plusJakartaSans(
        textStyle: baseTextTheme.titleMedium,
        fontSize: 15,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.1,
      ),
      bodyLarge: GoogleFonts.inter(
        textStyle: baseTextTheme.bodyLarge,
        fontSize: 14.5,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: GoogleFonts.inter(
        textStyle: baseTextTheme.bodyMedium,
        fontSize: 13.5,
        fontWeight: FontWeight.w400,
      ),
      labelLarge: GoogleFonts.plusJakartaSans(
        textStyle: baseTextTheme.labelLarge,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.1,
      ),
      labelMedium: GoogleFonts.inter(
        textStyle: baseTextTheme.labelMedium,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      labelSmall: GoogleFonts.inter(
        textStyle: baseTextTheme.labelSmall,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: colorScheme.surfaceDim,
      extensions: <ThemeExtension<dynamic>>[
        isDark ? NutrientColors.dark : NutrientColors.light,
      ],
      // Quiet tonal surfaces: rely on surfaceContainerLow vs surfaceDim rather than
      // wrapping every card in an outline border.
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: const StadiumBorder(),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: const StadiumBorder(),
          side: BorderSide(color: colorScheme.outlineVariant),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide.none,
        backgroundColor: colorScheme.surfaceContainer,
        selectedColor: colorScheme.secondaryContainer,
        labelStyle: GoogleFonts.inter(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusSheet)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 3,
        shape: const StadiumBorder(),
        extendedTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        indicatorColor: colorScheme.primaryContainer,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return GoogleFonts.inter(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
            color: isSelected
                ? colorScheme.onSurface
                : colorScheme.onSurfaceVariant,
          );
        }),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 8,
        activeTrackColor: colorScheme.primary,
        inactiveTrackColor: colorScheme.surfaceDim,
        thumbColor: colorScheme.onSurface,
        overlayColor: colorScheme.primary.withValues(alpha: 0.12),
        trackShape: const RoundedRectSliderTrackShape(),
      ),
    );
  }
}
