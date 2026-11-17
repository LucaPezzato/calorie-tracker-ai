import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../models/nutrition_models.dart';
import '../theme/app_theme.dart';
import '../theme/expressive_motion.dart';
import '../theme/nutrient_colors.dart';

class TodayScreen extends StatelessWidget {
  final UserProfile profile;
  final DailyMetrics metrics;
  final List<MealEntry> meals;
  final double? previousWeightKg;
  final int? daysSinceLastMeal;
  final List<MealEntry> quickRepeatMeals;
  final ValueChanged<int> onAddWater;
  final ValueChanged<int> onUpdateCoffee;
  final VoidCallback onTapWeight;
  final VoidCallback onOpenMenuAdvisor;
  final VoidCallback onOpenDailySummary;
  final ValueChanged<MealEntry> onDeleteMeal;
  final ValueChanged<MealEntry> onEditMeal;
  final ValueChanged<MealEntry>? onQuickRepeatMeal;
  final VoidCallback? onDismissRecovery;
  final VoidCallback? onOpenQuickAdd;

  const TodayScreen({
    super.key,
    required this.profile,
    required this.metrics,
    required this.meals,
    this.previousWeightKg,
    this.daysSinceLastMeal,
    this.quickRepeatMeals = const [],
    required this.onAddWater,
    required this.onUpdateCoffee,
    required this.onTapWeight,
    required this.onOpenMenuAdvisor,
    required this.onOpenDailySummary,
    required this.onDeleteMeal,
    required this.onEditMeal,
    this.onQuickRepeatMeal,
    this.onDismissRecovery,
    this.onOpenQuickAdd,
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
    final rawDiff = profile.targetKcal - _consumedKcal;
    final isOverBudget = rawDiff < 0;
    final displayKcal = isOverBudget ? rawDiff.abs() : rawDiff;
    final kcalProgress = profile.targetKcal > 0
        ? (_consumedKcal / profile.targetKcal).clamp(0.0, 1.0)
        : 0.0;

    return ListView(
      // 144dp bottom padding ensures the dual FAB never covers the last card
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 144),
      children: [
        // 1. HERO CARD (Expressive Calorie Ring + 4 Nutrient Progress Bars)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppTheme.radiusHero),
          ),
          child: Row(
            children: [
              // Expressive Animated Kcal Gauge
              SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 112,
                      height: 112,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0, end: kcalProgress),
                        duration: ExpressiveMotion.spatialDefaultDuration,
                        curve: ExpressiveMotion.spatialDefault,
                        builder: (context, animatedValue, _) {
                          return CircularProgressIndicator(
                            value: animatedValue,
                            strokeWidth: 10,
                            strokeCap: StrokeCap.round,
                            backgroundColor: cs.surfaceDim,
                            color: isOverBudget ? cs.error : cs.primary,
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isOverBudget ? '+$displayKcal' : '$displayKcal',
                              style: tt.displayMedium?.copyWith(
                                fontSize: 30,
                                color: isOverBudget ? cs.error : cs.onSurface,
                              ),
                            ),
                            Text(
                              isOverBudget ? 'Oltre target' : 'Rimanenti',
                              style: tt.labelSmall?.copyWith(
                                fontSize: 10,
                                color: isOverBudget
                                    ? cs.error
                                    : cs.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$_consumedKcal / ${profile.targetKcal}',
                              style: tt.labelSmall?.copyWith(
                                color: isOverBudget ? cs.error : cs.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),

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
                    const SizedBox(height: 10),
                    _NutrientBarRow(
                      label: 'Carbo',
                      current: _consumedC,
                      target: profile.targetCarbsG,
                      color: nutrients.carbs,
                    ),
                    const SizedBox(height: 10),
                    _NutrientBarRow(
                      label: 'Grassi',
                      current: _consumedG,
                      target: profile.targetFatG,
                      color: nutrients.fat,
                    ),
                    const SizedBox(height: 10),
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

        // 2. RECOVERY MODE BANNER (after >= 2 pause days, shown right below Hero)
        if (daysSinceLastMeal != null &&
            daysSinceLastMeal! >= 2 &&
            meals.isEmpty) ...[
          Card(
            color: cs.secondaryContainer.withValues(alpha: 0.7),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Symbols.waving_hand_rounded,
                        color: cs.onSecondaryContainer,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Bentornato! Nessun problema per i giorni di pausa',
                          style: tt.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: cs.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'La costanza non significa perfezione. Riparti da oggi con un pasto o una stima rapida.',
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSecondaryContainer.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      FilledButton.tonal(
                        onPressed: onDismissRecovery,
                        child: const Text('Riparti da oggi'),
                      ),
                      const SizedBox(width: 8),
                      if (onOpenQuickAdd != null)
                        OutlinedButton.icon(
                          onPressed: onOpenQuickAdd,
                          icon: const Icon(Symbols.bolt_rounded, size: 16),
                          label: const Text('Stima rapida'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // 3. HYDRATION & STIMULANT MINI-CARDS: WATER & COFFEE
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
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(
                            begin: 0,
                            end: (metrics.waterMl / profile.targetWaterMl)
                                .clamp(0.0, 1.0),
                          ),
                          duration: ExpressiveMotion.spatialDefaultDuration,
                          curve: ExpressiveMotion.spatialDefault,
                          builder: (context, val, _) => LinearProgressIndicator(
                            minHeight: 6,
                            value: val,
                            backgroundColor: cs.surfaceDim,
                            color: nutrients.water,
                          ),
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
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(
                            begin: 0,
                            end: (metrics.caffeineMg / 400.0).clamp(0.0, 1.0),
                          ),
                          duration: ExpressiveMotion.spatialDefaultDuration,
                          curve: ExpressiveMotion.spatialDefault,
                          builder: (context, val, _) => LinearProgressIndicator(
                            minHeight: 6,
                            value: val,
                            backgroundColor: cs.surfaceDim,
                            color: metrics.caffeineMg > 350
                                ? cs.error
                                : const Color(0xFFD97706),
                          ),
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
        const SizedBox(height: 14),

        // 4. 1-TAP QUICK REPEAT CHIPS ("Copia da ieri / Frequenti")
        if (quickRepeatMeals.isNotEmpty && onQuickRepeatMeal != null) ...[
          Text(
            'Ripeti in 1 tap',
            style: tt.labelMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: quickRepeatMeals.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                final m = quickRepeatMeals[idx];
                return ActionChip(
                  avatar: Icon(
                    Symbols.history_rounded,
                    size: 16,
                    color: cs.primary,
                  ),
                  label: Text('${m.title} (${m.totalKcal} kcal)'),
                  onPressed: () => onQuickRepeatMeal!(m),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
        ],

        // 5. CHRONOLOGICAL TIMELINE SECTION (Primary task above secondary tools)
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
            if (meals.isNotEmpty)
              Text(
                'Scorri per eliminare',
                style: tt.bodyMedium?.copyWith(
                  fontSize: 11.5,
                  color: cs.onSurfaceVariant,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),

        if (meals.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
              child: Column(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Symbols.restaurant_rounded,
                      size: 24,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Nessun pasto registrato oggi',
                    style: tt.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Usa "+ Aggiungi pasto" o la fotocamera qui sotto per iniziare.',
                    textAlign: TextAlign.center,
                    style: tt.bodyMedium?.copyWith(
                      fontSize: 12.5,
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
                                horizontal: 9,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(999),
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
                              style: tt.titleMedium?.copyWith(
                                fontSize: 14,
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
                            fontSize: 12.5,
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
        const SizedBox(height: 10),

        // 6. SECONDARY TOOLS & INSIGHTS (Weight, Menu Advisor, End-of-day AI Summary)
        Text(
          'Strumenti & Riepilogo',
          style: tt.labelMedium?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
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
                    padding: const EdgeInsets.all(14),
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
                            Builder(
                              builder: (context) {
                                final current =
                                    metrics.weightKg ?? profile.currentWeightKg;
                                final base =
                                    previousWeightKg ?? profile.currentWeightKg;
                                final delta = current - base;
                                final isLoss = delta < -0.01;
                                final isGain = delta > 0.01;
                                final deltaColor = isLoss
                                    ? nutrients.fiber
                                    : (isGain
                                        ? Colors.orangeAccent
                                        : cs.onSurfaceVariant);
                                final deltaText = delta.abs() < 0.01
                                    ? '0,0 kg'
                                    : '${delta > 0 ? '+' : ''}${delta.toStringAsFixed(1).replaceAll('.', ',')} kg';

                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: cs.surfaceContainerHigh,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    deltaText,
                                    style: tt.labelSmall?.copyWith(
                                      fontSize: 9.5,
                                      color: deltaColor,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                );
                              },
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
                              fontSize: 20,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tocca per aggiornare',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.bodyMedium?.copyWith(
                            fontSize: 11.5,
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
                    padding: const EdgeInsets.all(14),
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
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: cs.primaryContainer,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'AI',
                                style: tt.labelSmall?.copyWith(
                                  fontSize: 9.5,
                                  color: cs.onPrimaryContainer,
                                  fontWeight: FontWeight.w700,
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
                            'Trova piatti',
                            style: tt.headlineSmall?.copyWith(
                              fontSize: 20,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Da link, foto o testo',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.bodyMedium?.copyWith(
                            fontSize: 11.5,
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
        const SizedBox(height: 10),

        // END-OF-DAY AI SUMMARY BANNER
        Card(
          clipBehavior: Clip.antiAlias,
          color: cs.primaryContainer.withValues(alpha: 0.45),
          child: InkWell(
            onTap: onOpenDailySummary,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Symbols.auto_awesome_rounded,
                      size: 20,
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Resoconto AI di fine giornata',
                          style: tt.titleMedium?.copyWith(
                            fontSize: 14.5,
                            color: cs.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Valutazione macro, idratazione e consiglio per domani',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.labelSmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Symbols.chevron_right_rounded,
                    color: cs.primary,
                  ),
                ],
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
    return ExpressiveTapScale(
      onTap: onTap,
      child: Material(
        color: color.withValues(alpha: 0.14),
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 38),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: tt.labelSmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
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
    final progress = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tt.labelMedium?.copyWith(fontSize: 11.5, color: color),
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
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: progress),
            duration: ExpressiveMotion.spatialDefaultDuration,
            curve: ExpressiveMotion.spatialDefault,
            builder: (context, val, _) => LinearProgressIndicator(
              minHeight: 6,
              value: val,
              backgroundColor: cs.surfaceDim,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
