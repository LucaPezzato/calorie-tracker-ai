import 'dart:math';
import 'package:home_widget/home_widget.dart';
import '../data/local_database.dart';
import '../models/nutrition_models.dart';

@pragma('vm:entry-point')
Future<void> widgetBackgroundCallback(Uri? uri) async {
  if (uri == null) return;
  final waterStr = uri.queryParameters['water'];
  final coffeeStr = uri.queryParameters['coffee'];
  if (waterStr != null) {
    final water = int.tryParse(waterStr);
    final coffee = int.tryParse(coffeeStr ?? '0');
    final today = DateTime.now().toIso8601String().split('T').first;
    if (water != null) {
      final current = await LocalDatabase.instance.getDailyMetrics(today);
      await LocalDatabase.instance.upsertDailyMetrics(
        current.copyWith(waterMl: water, coffeeCups: coffee ?? current.coffeeCups),
      );
    }
  }
}

class WidgetSyncService {
  static const String appGroupId = 'group.com.example.calorie_tracker_ai';
  static const String fullWidgetProvider = 'CalorieWaterWidgetProvider';
  static const String compactWidgetProvider = 'HydrationCompactWidgetProvider';

  static Future<void> initialize() async {
    try {
      await HomeWidget.setAppGroupId(appGroupId);
      await HomeWidget.registerInteractivityCallback(widgetBackgroundCallback);
    } catch (_) {}
  }

  static Future<void> syncTodayData({
    required UserProfile profile,
    required DailyMetrics metrics,
    required List<MealEntry> meals,
  }) async {
    try {
      final totalKcal = meals.fold(0, (sum, m) => sum + m.totalKcal);
      final totalP = meals.fold(0.0, (sum, m) => sum + m.totalProteinG).round();
      final totalC = meals.fold(0.0, (sum, m) => sum + m.totalCarbsG).round();
      final totalF = meals.fold(0.0, (sum, m) => sum + m.totalFatG).round();
      final remainingKcal = max(0, profile.targetKcal - totalKcal);

      await HomeWidget.saveWidgetData<int>('kcal_remaining', remainingKcal);
      await HomeWidget.saveWidgetData<int>('kcal_target', profile.targetKcal);
      await HomeWidget.saveWidgetData<int>('protein_g', totalP);
      await HomeWidget.saveWidgetData<int>('carbs_g', totalC);
      await HomeWidget.saveWidgetData<int>('fat_g', totalF);
      await HomeWidget.saveWidgetData<int>('water_ml', metrics.waterMl);
      await HomeWidget.saveWidgetData<int>('water_target', profile.targetWaterMl);
      await HomeWidget.saveWidgetData<int>('coffee_cups', metrics.coffeeCups);

      await HomeWidget.updateWidget(
        name: fullWidgetProvider,
        androidName: fullWidgetProvider,
      );
      await HomeWidget.updateWidget(
        name: compactWidgetProvider,
        androidName: compactWidgetProvider,
      );
    } catch (_) {}
  }
}
