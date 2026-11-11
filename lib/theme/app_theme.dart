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

    // Cohesive Modern Typography System based entirely on Inter (SF Pro / Linear aesthetic):
    // Sleek, neutral, precision-engineered numerals with native tabular figures. Zero monospace code fonts.
    final textTheme = GoogleFonts.interTextTheme(baseTextTheme).copyWith(
      displayLarge: GoogleFonts.inter(
        textStyle: baseTextTheme.displayLarge,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.6,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      displayMedium: GoogleFonts.inter(
        textStyle: baseTextTheme.displayMedium,
        fontSize: 34,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      headlineSmall: GoogleFonts.inter(
        textStyle: baseTextTheme.headlineSmall,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
      titleLarge: GoogleFonts.inter(
        textStyle: baseTextTheme.titleLarge,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      titleMedium: GoogleFonts.inter(
        textStyle: baseTextTheme.titleMedium,
        fontSize: 14.5,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: GoogleFonts.inter(
        textStyle: baseTextTheme.bodyLarge,
        fontSize: 14.5,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: GoogleFonts.inter(
        textStyle: baseTextTheme.bodyMedium,
        fontSize: 13,
        fontWeight: FontWeight.w400,
      ),
      labelLarge: GoogleFonts.inter(
        textStyle: baseTextTheme.labelLarge,
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
      ),
      labelMedium: GoogleFonts.inter(
        textStyle: baseTextTheme.labelMedium,
        fontSize: 12,
        fontWeight: FontWeight.w500,
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
      cardTheme: CardThemeData(
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusCard),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.22),
            width: 1,
          ),
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
        elevation: 2,
        shape: const StadiumBorder(),
        extendedTextStyle: GoogleFonts.inter(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
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
