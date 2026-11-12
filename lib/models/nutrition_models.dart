import 'dart:convert';

enum GoalType { deficit, maintain, surplus }

enum AiProviderType { gemini, openai }

enum MealItemSource { aiText, aiPhoto, barcode, favorite, manual }

class UserProfile {
  final String sex; // 'M' or 'F'
  final int birthYear;
  final double heightCm;
  final double currentWeightKg;
  final double activityMultiplier; // 1.2 to 1.9
  final GoalType goalType;
  final bool isManualOverride;

  final int targetKcal;
  final double targetProteinG;
  final double targetCarbsG;
  final double targetFatG;
  final double targetFiberG;
  final int targetWaterMl;

  final AiProviderType preferredAiProvider;
  final String preferredAiModel;
  final bool autoBackupEnabled;
  final DateTime? lastDriveBackupAt;

  const UserProfile({
    this.sex = 'M',
    this.birthYear = 1995,
    this.heightCm = 178,
    this.currentWeightKg = 74.2,
    this.activityMultiplier = 1.55,
    this.goalType = GoalType.deficit,
    this.isManualOverride = false,
    this.targetKcal = 2400,
    this.targetProteinG = 150,
    this.targetCarbsG = 240,
    this.targetFatG = 65,
    this.targetFiberG = 30,
    this.targetWaterMl = 2500,
    this.preferredAiProvider = AiProviderType.gemini,
    this.preferredAiModel = 'gemini-2.5-flash',
    this.autoBackupEnabled = true,
    this.lastDriveBackupAt,
  });

  /// Guided TDEE & Macro Calculation using Mifflin-St Jeor equation
  factory UserProfile.calculateGuided({
    required String sex,
    required int birthYear,
    required double heightCm,
    required double weightKg,
    required double activityMultiplier,
    required GoalType goalType,
    double proteinPerKg = 1.6,
    AiProviderType preferredAiProvider = AiProviderType.gemini,
    String preferredAiModel = 'gemini-2.5-flash',
    bool autoBackupEnabled = true,
    DateTime? lastDriveBackupAt,
  }) {
    final age = (DateTime.now().year - birthYear).clamp(14, 100);
    final bmr = (10 * weightKg) +
        (6.25 * heightCm) -
        (5 * age) +
        (sex == 'M' ? 5 : -161);
    final tdee = bmr * activityMultiplier;

    final adjustedKcal = switch (goalType) {
      GoalType.deficit => (tdee * 0.85).round(),
      GoalType.maintain => tdee.round(),
      GoalType.surplus => (tdee * 1.10).round(),
    };

    // Scientific fitness guideline (SINU / ISSN / Morton et al.): 1.6 g/kg is optimal
    final proteinG = (weightKg * proteinPerKg).roundToDouble();
    final fatG = (weightKg * 0.8).roundToDouble();
    final remainingKcal = (adjustedKcal - (proteinG * 4) - (fatG * 9)).clamp(
      200.0,
      5000.0,
    );
    final carbsG = (remainingKcal / 4.0).roundToDouble();

    return UserProfile(
      sex: sex,
      birthYear: birthYear,
      heightCm: heightCm,
      currentWeightKg: weightKg,
      activityMultiplier: activityMultiplier,
      goalType: goalType,
      isManualOverride: false,
      targetKcal: adjustedKcal,
      targetProteinG: proteinG,
      targetCarbsG: carbsG,
      targetFatG: fatG,
      targetFiberG: 30,
      targetWaterMl: (weightKg * 35).round(),
      preferredAiProvider: preferredAiProvider,
      preferredAiModel: preferredAiModel,
      autoBackupEnabled: autoBackupEnabled,
      lastDriveBackupAt: lastDriveBackupAt,
    );
  }

  UserProfile copyWith({
    String? sex,
    int? birthYear,
    double? heightCm,
    double? currentWeightKg,
    double? activityMultiplier,
    GoalType? goalType,
    bool? isManualOverride,
    int? targetKcal,
    double? targetProteinG,
    double? targetCarbsG,
    double? targetFatG,
    double? targetFiberG,
    int? targetWaterMl,
    AiProviderType? preferredAiProvider,
    String? preferredAiModel,
    bool? autoBackupEnabled,
    DateTime? lastDriveBackupAt,
  }) {
    return UserProfile(
      sex: sex ?? this.sex,
      birthYear: birthYear ?? this.birthYear,
      heightCm: heightCm ?? this.heightCm,
      currentWeightKg: currentWeightKg ?? this.currentWeightKg,
      activityMultiplier: activityMultiplier ?? this.activityMultiplier,
      goalType: goalType ?? this.goalType,
      isManualOverride: isManualOverride ?? this.isManualOverride,
      targetKcal: targetKcal ?? this.targetKcal,
      targetProteinG: targetProteinG ?? this.targetProteinG,
      targetCarbsG: targetCarbsG ?? this.targetCarbsG,
      targetFatG: targetFatG ?? this.targetFatG,
      targetFiberG: targetFiberG ?? this.targetFiberG,
      targetWaterMl: targetWaterMl ?? this.targetWaterMl,
      preferredAiProvider: preferredAiProvider ?? this.preferredAiProvider,
      preferredAiModel: preferredAiModel ?? this.preferredAiModel,
      autoBackupEnabled: autoBackupEnabled ?? this.autoBackupEnabled,
      lastDriveBackupAt: lastDriveBackupAt ?? this.lastDriveBackupAt,
    );
  }
}

class MealItem {
  final String id;
  final String mealId;
  final String name;
  final double grams;
  final double kcalPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;
  final double fiberPer100g;
  final MealItemSource source;
  final String? barcode;

  const MealItem({
    required this.id,
    required this.mealId,
    required this.name,
    required this.grams,
    required this.kcalPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
    this.fiberPer100g = 0.0,
    this.source = MealItemSource.aiText,
    this.barcode,
  });

  // Real-time 120fps computed values when dragging the gram slider
  int get kcal => ((grams / 100.0) * kcalPer100g).round();
  double get proteinG => (grams / 100.0) * proteinPer100g;
  double get carbsG => (grams / 100.0) * carbsPer100g;
  double get fatG => (grams / 100.0) * fatPer100g;
  double get fiberG => (grams / 100.0) * fiberPer100g;

  MealItem copyWith({double? grams, String? name}) {
    return MealItem(
      id: id,
      mealId: mealId,
      name: name ?? this.name,
      grams: grams ?? this.grams,
      kcalPer100g: kcalPer100g,
      proteinPer100g: proteinPer100g,
      carbsPer100g: carbsPer100g,
      fatPer100g: fatPer100g,
      fiberPer100g: fiberPer100g,
      source: source,
      barcode: barcode,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'meal_id': mealId,
        'name': name,
        'grams': grams,
        'kcal_per_100g': kcalPer100g,
        'protein_per_100g': proteinPer100g,
        'carbs_per_100g': carbsPer100g,
        'fat_per_100g': fatPer100g,
        'fiber_per_100g': fiberPer100g,
        'source': source.name,
        'barcode': barcode,
      };

  factory MealItem.fromMap(Map<String, dynamic> map) => MealItem(
        id: map['id'] as String,
        mealId: map['meal_id'] as String,
        name: map['name'] as String,
        grams: (map['grams'] as num).toDouble(),
        kcalPer100g: (map['kcal_per_100g'] as num).toDouble(),
        proteinPer100g: (map['protein_per_100g'] as num).toDouble(),
        carbsPer100g: (map['carbs_per_100g'] as num).toDouble(),
        fatPer100g: (map['fat_per_100g'] as num).toDouble(),
        fiberPer100g: (map['fiber_per_100g'] as num?)?.toDouble() ?? 0.0,
        source: MealItemSource.values.firstWhere(
          (e) => e.name == map['source'],
          orElse: () => MealItemSource.manual,
        ),
        barcode: map['barcode'] as String?,
      );
}

class MealEntry {
  final String id;
  final String date; // YYYY-MM-DD
  final String loggedAt; // HH:mm (Chronological timeline order)
  final String title;
  final String? notes;
  final String? localPhotoPath; // Stored locally only, excluded from Drive DB
  final List<MealItem> items;

  const MealEntry({
    required this.id,
    required this.date,
    required this.loggedAt,
    required this.title,
    this.notes,
    this.localPhotoPath,
    required this.items,
  });

  int get totalKcal => items.fold(0, (sum, item) => sum + item.kcal);
  double get totalProteinG =>
      items.fold(0.0, (sum, item) => sum + item.proteinG);
  double get totalCarbsG => items.fold(0.0, (sum, item) => sum + item.carbsG);
  double get totalFatG => items.fold(0.0, (sum, item) => sum + item.fatG);
  double get totalFiberG => items.fold(0.0, (sum, item) => sum + item.fiberG);
}

class DailyMetrics {
  final String date; // YYYY-MM-DD
  final int waterMl;
  final int coffeeCups;
  final double? weightKg;

  const DailyMetrics({
    required this.date,
    this.waterMl = 0,
    this.coffeeCups = 0,
    this.weightKg,
  });

  /// Standard espresso has ~70 mg of caffeine. EFSA safe daily limit is ~400 mg.
  int get caffeineMg => coffeeCups * 70;

  DailyMetrics copyWith({
    int? waterMl,
    int? coffeeCups,
    double? weightKg,
  }) =>
      DailyMetrics(
        date: date,
        waterMl: waterMl ?? this.waterMl,
        coffeeCups: coffeeCups ?? this.coffeeCups,
        weightKg: weightKg ?? this.weightKg,
      );
}

class MenuDishRecommendation {
  final String dishName;
  final String reasoning;
  final int estimatedGrams;
  final int estimatedKcal;
  final double estimatedProteinG;
  final double estimatedCarbsG;
  final double estimatedFatG;
  final double estimatedFiberG;
  final bool isTopPick;
  final String? cautionNotes;

  const MenuDishRecommendation({
    required this.dishName,
    required this.reasoning,
    required this.estimatedGrams,
    required this.estimatedKcal,
    required this.estimatedProteinG,
    required this.estimatedCarbsG,
    required this.estimatedFatG,
    this.estimatedFiberG = 0.0,
    this.isTopPick = false,
    this.cautionNotes,
  });
}

class MenuAnalysisResult {
  final String restaurantName;
  final String summaryAdvice;
  final List<MenuDishRecommendation> recommendations;
  final List<String> dishesToAvoid;

  const MenuAnalysisResult({
    required this.restaurantName,
    required this.summaryAdvice,
    required this.recommendations,
    this.dishesToAvoid = const [],
  });
}

class FavoriteFood {
  final String id;
  final String name;
  final double defaultGrams;
  final double kcalPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;
  final double fiberPer100g;
  final String? barcode;
  final int useCount;

  const FavoriteFood({
    required this.id,
    required this.name,
    required this.defaultGrams,
    required this.kcalPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
    this.fiberPer100g = 0.0,
    this.barcode,
    this.useCount = 1,
  });

  int get defaultKcal => ((defaultGrams / 100.0) * kcalPer100g).round();
}

class DailyStatEntry {
  final String date;
  final double kcal;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final int waterMl;
  final int coffeeCups;
  final double? weightKg;

  const DailyStatEntry({
    required this.date,
    this.kcal = 0,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
    this.fiber = 0,
    this.waterMl = 0,
    this.coffeeCups = 0,
    this.weightKg,
  });
}

class DailyAiSummary {
  final String date;
  final double score;
  final String headline;
  final String verdict;
  final List<String> strengths;
  final List<String> warnings;
  final String adviceTomorrow;
  final String createdAt;

  const DailyAiSummary({
    required this.date,
    required this.score,
    required this.headline,
    required this.verdict,
    required this.strengths,
    required this.warnings,
    required this.adviceTomorrow,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'date': date,
        'score': score,
        'headline': headline,
        'verdict': verdict,
        'strengths_json': jsonEncode(strengths),
        'warnings_json': jsonEncode(warnings),
        'advice_tomorrow': adviceTomorrow,
        'created_at': createdAt,
      };

  factory DailyAiSummary.fromMap(Map<String, dynamic> map) {
    List<String> decodeList(dynamic raw) {
      if (raw is String && raw.isNotEmpty) {
        try {
          final parsed = jsonDecode(raw);
          if (parsed is List) {
            return parsed.map((e) => e.toString()).toList();
          }
        } catch (_) {}
      }
      return const [];
    }

    return DailyAiSummary(
      date: map['date'] as String,
      score: ((map['score'] as num?) ?? 7.0).toDouble(),
      headline: (map['headline'] as String?) ?? '',
      verdict: (map['verdict'] as String?) ?? '',
      strengths: decodeList(map['strengths_json']),
      warnings: decodeList(map['warnings_json']),
      adviceTomorrow: (map['advice_tomorrow'] as String?) ?? '',
      createdAt: (map['created_at'] as String?) ?? '',
    );
  }
}
