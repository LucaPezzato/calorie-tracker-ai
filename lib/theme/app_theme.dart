import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'nutrient_colors.dart';

class AppTheme {
  /// Default Material You fallback seed color (Emerald / Mint)
  static const Color defaultSeedColor = Color(0xFF34D399);

  static const double radiusHero = 28.0;
  static const double radiusCard = 20.0;
  static const double radiusSmall = 16.0;

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

    // Triple-Font System:
    // 1. Plus Jakarta Sans -> Display, Headline, Title, LabelLarge
    // 2. Inter -> Body
    // 3. JetBrains Mono -> Tabular numeric labels & badges
    final textTheme = GoogleFonts.interTextTheme(baseTextTheme).copyWith(
      displayLarge: GoogleFonts.plusJakartaSans(
        textStyle: baseTextTheme.displayLarge,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      displayMedium: GoogleFonts.plusJakartaSans(
        textStyle: baseTextTheme.displayMedium,
        fontSize: 36,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      headlineSmall: GoogleFonts.plusJakartaSans(
        textStyle: baseTextTheme.headlineSmall,
        fontSize: 22,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
      ),
      titleLarge: GoogleFonts.plusJakartaSans(
        textStyle: baseTextTheme.titleLarge,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: GoogleFonts.plusJakartaSans(
        textStyle: baseTextTheme.titleMedium,
        fontSize: 15,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: GoogleFonts.inter(
        textStyle: baseTextTheme.bodyLarge,
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
      bodyMedium: GoogleFonts.inter(
        textStyle: baseTextTheme.bodyMedium,
        fontSize: 13.5,
        fontWeight: FontWeight.w400,
      ),
      labelLarge: GoogleFonts.plusJakartaSans(
        textStyle: baseTextTheme.labelLarge,
        fontSize: 14,
        fontWeight: FontWeight.w800,
      ),
      labelMedium: GoogleFonts.jetBrainsMono(
        textStyle: baseTextTheme.labelMedium,
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
      labelSmall: GoogleFonts.jetBrainsMono(
        textStyle: baseTextTheme.labelSmall,
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
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
            color: colorScheme.outlineVariant.withValues(alpha: 0.45),
            width: 1,
          ),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusHero)),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 4,
        shape: const StadiumBorder(),
        extendedTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        indicatorColor: colorScheme.primaryContainer,
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final isSelected = states.contains(WidgetState.selected);
          return GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? colorScheme.onSurface
                : colorScheme.onSurfaceVariant,
          );
        }),
      ),
      sliderTheme: SliderThemeData(
        trackHeight: 10,
        activeTrackColor: colorScheme.primary,
        inactiveTrackColor: colorScheme.surfaceDim,
        thumbColor: colorScheme.onSurface,
        overlayColor: colorScheme.primary.withValues(alpha: 0.16),
        trackShape: const RoundedRectSliderTrackShape(),
      ),
    );
  }
}
