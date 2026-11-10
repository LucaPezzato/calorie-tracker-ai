import 'package:flutter/material.dart';

/// Fixed semantic colors for nutrients across the entire application.
/// These stay consistent even when Material You Dynamic Color changes the
/// primary/surface palette from the user's Android wallpaper.
@immutable
class NutrientColors extends ThemeExtension<NutrientColors> {
  final Color protein;
  final Color carbs;
  final Color fat;
  final Color fiber;
  final Color water;

  const NutrientColors({
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    required this.water,
  });

  /// Standard Dark Mode semantic palette (approved in Design System Board)
  static const dark = NutrientColors(
    protein: Color(0xFFFF6B6B), // Coral Red
    carbs: Color(0xFFFBBF24), // Warm Amber
    fat: Color(0xFFC084FC), // Soft Purple
    fiber: Color(0xFF4ADE80), // Leaf Green
    water: Color(0xFF38BDF8), // Sky Cyan
  );

  /// Harmonized Light Mode semantic palette for high contrast on light surfaces
  static const light = NutrientColors(
    protein: Color(0xFFE11D48),
    carbs: Color(0xFFD97706),
    fat: Color(0xFF9333EA),
    fiber: Color(0xFF16A34A),
    water: Color(0xFF0284C7),
  );

  @override
  NutrientColors copyWith({
    Color? protein,
    Color? carbs,
    Color? fat,
    Color? fiber,
    Color? water,
  }) {
    return NutrientColors(
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      fiber: fiber ?? this.fiber,
      water: water ?? this.water,
    );
  }

  @override
  NutrientColors lerp(ThemeExtension<NutrientColors>? other, double t) {
    if (other is! NutrientColors) return this;
    return NutrientColors(
      protein: Color.lerp(protein, other.protein, t)!,
      carbs: Color.lerp(carbs, other.carbs, t)!,
      fat: Color.lerp(fat, other.fat, t)!,
      fiber: Color.lerp(fiber, other.fiber, t)!,
      water: Color.lerp(water, other.water, t)!,
    );
  }
}

extension NutrientColorsBuildContext on BuildContext {
  NutrientColors get nutrients =>
      Theme.of(this).extension<NutrientColors>() ?? NutrientColors.dark;
}
