import 'package:flutter/material.dart';
import '../models/nutrition_models.dart';
import '../theme/app_theme.dart';
import '../theme/nutrient_colors.dart';

class StatsScreen extends StatefulWidget {
  final UserProfile profile;

  const StatsScreen({super.key, required this.profile});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  int _selectedRange = 7; // 7, 30, 90 days

  static const List<int> _weeklyKcal = [
    2210,
    2360,
    2090,
    2540,
    2310,
    2340,
    1160,
  ];
  static const List<String> _dayLabels = [
    'M',
    'G',
    'V',
    'S',
    'D',
    'L',
    'OGGI',
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final nutrients = context.nutrients;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // 7G / 30G / 90G Segmented Selector
        SegmentedButton<int>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 7, label: Text('7 Giorni')),
            ButtonSegment(value: 30, label: Text('30 Giorni')),
            ButtonSegment(value: 90, label: Text('90 Giorni')),
          ],
          selected: {_selectedRange},
          onSelectionChanged: (s) => setState(() => _selectedRange = s.first),
        ),
        const SizedBox(height: 14),

        // CARD 1: Calorie vs Target
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Calorie vs Target',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.titleLarge,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Media: 2.280 kcal',
                      style: tt.labelMedium?.copyWith(color: cs.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Target giornaliero: ${widget.profile.targetKcal} kcal',
                  style: tt.bodyMedium?.copyWith(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 140,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(_weeklyKcal.length, (i) {
                      final kcal = _weeklyKcal[i];
                      final isOver = kcal > widget.profile.targetKcal;
                      final ratio = (kcal / 2800.0).clamp(0.15, 1.0);
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            width: 24,
                            height: 110 * ratio,
                            decoration: BoxDecoration(
                              color: isOver ? nutrients.carbs : cs.primary,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _dayLabels[i],
                            style: tt.labelSmall?.copyWith(
                              color: i == 6 ? cs.primary : cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // CARD 2: Equilibrio Nutrienti, Fibre & Acqua
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ripartizione Media Nutrienti', style: tt.titleLarge),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: SizedBox(
                    height: 14,
                    child: Row(
                      children: [
                        Expanded(
                          flex: 30,
                          child: Container(color: nutrients.protein),
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          flex: 45,
                          child: Container(color: nutrients.carbs),
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          flex: 25,
                          child: Container(color: nutrients.fat),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    Text(
                      '● Proteine 30% (142g)',
                      style: tt.labelSmall?.copyWith(color: nutrients.protein),
                    ),
                    Text(
                      '● Carbo 45% (215g)',
                      style: tt.labelSmall?.copyWith(color: nutrients.carbs),
                    ),
                    Text(
                      '● Grassi 25% (58g)',
                      style: tt.labelSmall?.copyWith(color: nutrients.fat),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: cs.surfaceDim,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusSmall,
                          ),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '🌱 Fibre: 27g / gg',
                            style: tt.labelSmall?.copyWith(
                              color: nutrients.fiber,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: cs.surfaceDim,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusSmall,
                          ),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '💧 Acqua: 2,4 L / gg',
                            style: tt.labelSmall?.copyWith(
                              color: nutrients.water,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // CARD 3: Andamento Peso Corporeo
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Andamento Peso (Media)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.titleLarge,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: nutrients.fiber.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '-0,8 kg (30gg)',
                        style: tt.labelSmall?.copyWith(color: nutrients.fiber),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.profile.currentWeightKg.toStringAsFixed(1)} kg',
                  style: tt.headlineSmall,
                ),
                const SizedBox(height: 4),
                Text(
                  'La media mobile a 7 giorni filtra le fluttuazioni d\'acqua giornaliere.',
                  style: tt.bodyMedium?.copyWith(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
