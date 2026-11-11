import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../models/nutrition_models.dart';
import '../theme/app_theme.dart';
import '../theme/nutrient_colors.dart';

class TodayScreen extends StatelessWidget {
  final UserProfile profile;
  final DailyMetrics metrics;
  final List<MealEntry> meals;
  final ValueChanged<int> onAddWater;
  final ValueChanged<int> onUpdateCoffee;
  final VoidCallback onTapWeight;
  final VoidCallback onOpenMenuAdvisor;
  final ValueChanged<MealEntry> onDeleteMeal;
  final ValueChanged<MealEntry> onEditMeal;

  const TodayScreen({
    super.key,
    required this.profile,
    required this.metrics,
    required this.meals,
    required this.onAddWater,
    required this.onUpdateCoffee,
    required this.onTapWeight,
    required this.onOpenMenuAdvisor,
    required this.onDeleteMeal,
    required this.onEditMeal,
  });

  int get _consumedKcal => meals.fold(0, (s, m) => s + m.totalKcal);
  double get _consumedP => meals.fold(0.0, (s, m) => s + m.totalProteinG);
  double get _consumedC => meals.fold(0.0, (s, m) => s + m.totalCarbsG);
  double get _consumedG => meals.fold(0.0, (s, m) => s + m.totalFatG);
  double get _consumedF => meals.fold(0.0, (s, m) => s + m.totalFiberG);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final nutrients = context.nutrients;
    final remainingKcal = (profile.targetKcal - _consumedKcal).clamp(
      0,
      profile.targetKcal,
    );

    return ListView(
      // 96dp bottom padding ensures the Extended FAB never covers the last meal card
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        // 1. HERO CARD (Calorie Ring + 4 Nutrient Progress Bars)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppTheme.radiusHero),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            children: [
              // Expressive Kcal Gauge
              SizedBox(
                width: 108,
                height: 108,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: CircularProgressIndicator(
                        value: (_consumedKcal / profile.targetKcal).clamp(
                          0.0,
                          1.0,
                        ),
                        strokeWidth: 9,
                        strokeCap: StrokeCap.round,
                        backgroundColor: cs.surfaceDim,
                        color: cs.primary,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$remainingKcal',
                              style: tt.headlineSmall?.copyWith(
                                fontSize: 24,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                            Text(
                              'Rimanenti',
                              style: tt.labelSmall?.copyWith(
                                fontSize: 9.5,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$_consumedKcal / ${profile.targetKcal}',
                              style: tt.labelSmall?.copyWith(
                                color: cs.primary,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // 4 Semantic Bars: Proteine, Carboidrati, Grassi, Fibre
              Expanded(
                child: Column(
                  children: [
                    _NutrientBarRow(
                      label: 'Proteine',
                      current: _consumedP,
                      target: profile.targetProteinG,
                      color: nutrients.protein,
                    ),
                    const SizedBox(height: 9),
                    _NutrientBarRow(
                      label: 'Carbo',
                      current: _consumedC,
                      target: profile.targetCarbsG,
                      color: nutrients.carbs,
                    ),
                    const SizedBox(height: 9),
                    _NutrientBarRow(
                      label: 'Grassi',
                      current: _consumedG,
                      target: profile.targetFatG,
                      color: nutrients.fat,
                    ),
                    const SizedBox(height: 9),
                    _NutrientBarRow(
                      label: 'Fibre',
                      current: _consumedF,
                      target: profile.targetFiberG,
                      color: nutrients.fiber,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // 2. TWO HYDRATION & STIMULANT MINI-CARDS: WATER & COFFEE
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Water Mini-Card
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Symbols.water_drop_rounded,
                            size: 16,
                            color: nutrients.water,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              '${metrics.waterMl} ml',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tt.titleMedium?.copyWith(
                                fontSize: 13.5,
                                color: nutrients.water,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                          Text(
                            '/${profile.targetWaterMl}',
                            style: tt.labelSmall?.copyWith(
                              fontSize: 10,
                              color: cs.onSurfaceVariant,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          minHeight: 6,
                          value: (metrics.waterMl / profile.targetWaterMl)
                              .clamp(0.0, 1.0),
                          backgroundColor: cs.surfaceDim,
                          color: nutrients.water,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          if (metrics.waterMl > 0) ...[
                            Expanded(
                              child: _WaterQuickButton(
                                label: '-250',
                                color: cs.error,
                                onTap: () => onAddWater(-250),
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: _WaterQuickButton(
                              label: '+250',
                              color: nutrients.water,
                              onTap: () => onAddWater(250),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: _WaterQuickButton(
                              label: '+500',
                              color: nutrients.water,
                              onTap: () => onAddWater(500),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Coffee & Caffeine Tracker Mini-Card
            Expanded(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Symbols.coffee_rounded,
                            size: 16,
                            color: Color(0xFFD97706),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              '${metrics.coffeeCups} caffè',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tt.titleMedium?.copyWith(
                                fontSize: 13.5,
                                color: const Color(0xFFD97706),
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                          Text(
                            '~${metrics.caffeineMg}/400mg',
                            style: tt.labelSmall?.copyWith(
                              fontSize: 10,
                              color: cs.onSurfaceVariant,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          minHeight: 6,
                          value: (metrics.caffeineMg / 400.0).clamp(0.0, 1.0),
                          backgroundColor: cs.surfaceDim,
                          color: metrics.caffeineMg > 350
                              ? cs.error
                              : const Color(0xFFD97706),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          if (metrics.coffeeCups > 0) ...[
                            Expanded(
                              flex: 3,
                              child: _WaterQuickButton(
                                label: '-1',
                                color: cs.error,
                                onTap: () => onUpdateCoffee(
                                  (metrics.coffeeCups - 1).clamp(0, 20),
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            flex: 5,
                            child: _WaterQuickButton(
                              label: '+1 Espresso',
                              color: const Color(0xFFD97706),
                              onTap: () => onUpdateCoffee(
                                (metrics.coffeeCups + 1).clamp(0, 20),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // 3. WEIGHT & RESTAURANT MENU ADVISOR ROW
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Weight Mini-Card
            Expanded(
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onTapWeight,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Symbols.monitor_weight_rounded,
                              size: 16,
                              color: cs.onSurfaceVariant,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                'Peso',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: tt.titleMedium?.copyWith(fontSize: 13.5),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: cs.surfaceDim,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: cs.outlineVariant.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Text(
                                '-0,3 kg',
                                style: tt.labelSmall?.copyWith(
                                  fontSize: 9.5,
                                  color: nutrients.fiber,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${(metrics.weightKg ?? profile.currentWeightKg).toStringAsFixed(1)} kg',
                            style: tt.headlineSmall?.copyWith(
                              fontSize: 18,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Tocca per aggiornare',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.bodyMedium?.copyWith(
                            fontSize: 11,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Menu Advisor Action Card
            Expanded(
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: onOpenMenuAdvisor,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Symbols.restaurant_menu_rounded,
                              size: 16,
                              color: cs.primary,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                'Menu',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: tt.titleMedium?.copyWith(fontSize: 13.5),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: cs.primaryContainer,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'Consiglia',
                                style: tt.labelSmall?.copyWith(
                                  fontSize: 9.5,
                                  color: cs.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Trova piatti adatti',
                            style: tt.headlineSmall?.copyWith(
                              fontSize: 18,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Da link, foto o testo',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.bodyMedium?.copyWith(
                            fontSize: 11,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // 3. CHRONOLOGICAL TIMELINE SECTION
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'Pasti di oggi',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.titleLarge,
              ),
            ),
            Text(
              'Scorri per eliminare',
              style: tt.bodyMedium?.copyWith(
                fontSize: 11,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (meals.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Icon(
                    Symbols.restaurant_rounded,
                    size: 32,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Nessun pasto registrato oggi',
                    style: tt.titleMedium?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Premi "+ Aggiungi pasto" in basso per iniziare',
                    style: tt.bodyMedium?.copyWith(
                      fontSize: 12,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),

        ...meals.map(
          (meal) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Dismissible(
              key: ValueKey('meal_${meal.id}'),
              direction: DismissDirection.horizontal,
              confirmDismiss: (_) async {
                return await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Elimina pasto'),
                        content: Text(
                          'Vuoi davvero eliminare "${meal.title}" (${meal.loggedAt})?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Annulla'),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: cs.error,
                              foregroundColor: cs.onError,
                            ),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Elimina'),
                          ),
                        ],
                      ),
                    ) ??
                    false;
              },
              onDismissed: (_) => onDeleteMeal(meal),
              background: Container(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: cs.errorContainer,
                  borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                ),
                child: Row(
                  children: [
                    Icon(Symbols.delete_rounded, color: cs.onErrorContainer),
                    const SizedBox(width: 8),
                    Text(
                      'Elimina',
                      style: tt.labelLarge?.copyWith(
                        color: cs.onErrorContainer,
                      ),
                    ),
                  ],
                ),
              ),
              secondaryBackground: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: cs.errorContainer,
                  borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Elimina',
                      style: tt.labelLarge?.copyWith(
                        color: cs.onErrorContainer,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Symbols.delete_rounded, color: cs.onErrorContainer),
                  ],
                ),
              ),
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => onEditMeal(meal),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2.5,
                              ),
                              decoration: BoxDecoration(
                                color: cs.surfaceDim,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: cs.outlineVariant.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Text(
                                meal.loggedAt,
                                style: tt.labelSmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ),
                            Text(
                              '${meal.totalKcal} kcal',
                              style: tt.labelMedium?.copyWith(
                                fontSize: 13,
                                color: cs.primary,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(meal.title, style: tt.titleMedium),
                        const SizedBox(height: 3),
                        Text(
                          meal.items
                              .map((i) => '${i.name} (${i.grams.round()}g)')
                              .join(' • '),
                          style: tt.bodyMedium?.copyWith(
                            fontSize: 12,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            Text(
                              'P: ${meal.totalProteinG.round()}g',
                              style: tt.labelSmall?.copyWith(
                                color: nutrients.protein,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                            Text(
                              'C: ${meal.totalCarbsG.round()}g',
                              style: tt.labelSmall?.copyWith(
                                color: nutrients.carbs,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                            Text(
                              'G: ${meal.totalFatG.round()}g',
                              style: tt.labelSmall?.copyWith(
                                color: nutrients.fat,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                            Text(
                              'F: ${meal.totalFiberG.round()}g',
                              style: tt.labelSmall?.copyWith(
                                color: nutrients.fiber,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WaterQuickButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _WaterQuickButton({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Material(
      color: color.withValues(alpha: 0.12),
      shape: StadiumBorder(
        side: BorderSide(color: color.withValues(alpha: 0.28)),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                style: tt.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [
                    FontFeature.tabularFigures(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NutrientBarRow extends StatelessWidget {
  final String label;
  final double current;
  final double target;
  final Color color;

  const _NutrientBarRow({
    required this.label,
    required this.current,
    required this.target,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.labelMedium?.copyWith(fontSize: 11, color: color),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${current.round()}/${target.round()}g',
              style: tt.labelSmall?.copyWith(
                fontSize: 10.5,
                fontFeatures: const [
                  FontFeature.tabularFigures(),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 6,
            value: (current / target).clamp(0.0, 1.0),
            backgroundColor: cs.surfaceDim,
            color: color,
          ),
        ),
      ],
    );
  }
}
