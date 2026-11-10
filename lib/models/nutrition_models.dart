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

    final proteinG = (weightKg * 2.0).roundToDouble();
    final fatG = (weightKg * 0.9).roundToDouble();
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
  final double? weightKg;

  const DailyMetrics({
    required this.date,
    this.waterMl = 0,
    this.weightKg,
  });

  DailyMetrics copyWith({int? waterMl, double? weightKg}) => DailyMetrics(
        date: date,
        waterMl: waterMl ?? this.waterMl,
        weightKg: weightKg ?? this.weightKg,
      );
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
