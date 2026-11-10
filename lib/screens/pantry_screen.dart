import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:uuid/uuid.dart';
import '../models/nutrition_models.dart';
import '../theme/nutrient_colors.dart';
import 'barcode_scanner_dialog.dart';

class PantryScreen extends StatefulWidget {
  final ValueChanged<MealEntry> onQuickAddMeal;

  const PantryScreen({super.key, required this.onQuickAddMeal});

  @override
  State<PantryScreen> createState() => _PantryScreenState();
}

class _PantryScreenState extends State<PantryScreen> {
  static const _uuid = Uuid();
  String _searchQuery = '';

  final List<FavoriteFood> _favorites = [
    const FavoriteFood(
      id: 'f1',
      name: 'Yogurt Greco Fage Total 0%',
      defaultGrams: 170,
      kcalPer100g: 54,
      proteinPer100g: 10.3,
      carbsPer100g: 3.0,
      fatPer100g: 0,
      barcode: '5201054017415',
      useCount: 38,
    ),
    const FavoriteFood(
      id: 'f2',
      name: 'Pasta Integrale Rummo',
      defaultGrams: 100,
      kcalPer100g: 351,
      proteinPer100g: 14.5,
      carbsPer100g: 66.0,
      fatPer100g: 2.0,
      fiberPer100g: 6.0,
      barcode: '8008343200553',
      useCount: 24,
    ),
    const FavoriteFood(
      id: 'f3',
      name: 'Petto di Pollo (Crudo)',
      defaultGrams: 200,
      kcalPer100g: 110,
      proteinPer100g: 23.0,
      carbsPer100g: 0,
      fatPer100g: 1.6,
      useCount: 21,
    ),
    const FavoriteFood(
      id: 'f4',
      name: 'Olio Extravergine d\'Oliva (1 cucchiaio)',
      defaultGrams: 10,
      kcalPer100g: 884,
      proteinPer100g: 0,
      carbsPer100g: 0,
      fatPer100g: 100.0,
      useCount: 45,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final nutrients = context.nutrients;

    final filtered = _favorites
        .where(
          (f) => f.name.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // Search Bar + Barcode Button Row
        Row(
          children: [
            Expanded(
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: cs.surfaceContainerLow,
                  hintText: 'Cerca cibo o ricetta...',
                  prefixIcon: const Icon(Symbols.search_rounded),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 48),
                shape: const StadiumBorder(),
              ),
              onPressed: () async {
                final scanned = await showDialog<MealItem>(
                  context: context,
                  builder: (_) => BarcodeScannerDialog(mealId: _uuid.v4()),
                );
                if (scanned != null && mounted) {
                  setState(() {
                    _favorites.insert(
                      0,
                      FavoriteFood(
                        id: _uuid.v4(),
                        name: scanned.name,
                        defaultGrams: scanned.grams,
                        kcalPer100g: scanned.kcalPer100g,
                        proteinPer100g: scanned.proteinPer100g,
                        carbsPer100g: scanned.carbsPer100g,
                        fatPer100g: scanned.fatPer100g,
                        fiberPer100g: scanned.fiberPer100g,
                        barcode: scanned.barcode,
                      ),
                    );
                  });
                }
              },
              icon: const Icon(Symbols.qr_code_scanner_rounded),
              label: const Text('Barcode'),
            ),
          ],
        ),
        const SizedBox(height: 16),

        ...filtered.map((fav) {
          final p = ((fav.defaultGrams / 100.0) * fav.proteinPer100g).round();
          final c = ((fav.defaultGrams / 100.0) * fav.carbsPer100g).round();
          final g = ((fav.defaultGrams / 100.0) * fav.fatPer100g).round();

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(fav.name, style: tt.titleMedium),
                          const SizedBox(height: 4),
                          Text(
                            'Porzione: ${fav.defaultGrams.round()} g  •  ${fav.defaultKcal} kcal',
                            style: tt.labelMedium?.copyWith(color: cs.primary),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                'P: ${p}g',
                                style: tt.labelSmall?.copyWith(
                                  color: nutrients.protein,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'C: ${c}g',
                                style: tt.labelSmall?.copyWith(
                                  color: nutrients.carbs,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'G: ${g}g',
                                style: tt.labelSmall?.copyWith(
                                  color: nutrients.fat,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton.filledTonal(
                      icon: const Icon(Symbols.add_rounded),
                      tooltip: 'Aggiungi in 1 tap alla Timeline',
                      onPressed: () {
                        final now = TimeOfDay.now();
                        final timeStr =
                            '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
                        final mealId = _uuid.v4();
                        final entry = MealEntry(
                          id: mealId,
                          date: DateTime.now()
                              .toIso8601String()
                              .split('T')
                              .first,
                          loggedAt: timeStr,
                          title: fav.name,
                          items: [
                            MealItem(
                              id: _uuid.v4(),
                              mealId: mealId,
                              name: fav.name,
                              grams: fav.defaultGrams,
                              kcalPer100g: fav.kcalPer100g,
                              proteinPer100g: fav.proteinPer100g,
                              carbsPer100g: fav.carbsPer100g,
                              fatPer100g: fav.fatPer100g,
                              fiberPer100g: fav.fiberPer100g,
                              source: MealItemSource.favorite,
                              barcode: fav.barcode,
                            ),
                          ],
                        );
                        widget.onQuickAddMeal(entry);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Aggiunto "${fav.name}" alle $timeStr!',
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
