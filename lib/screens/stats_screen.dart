import 'dart:math';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../data/local_database.dart';
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
  bool _isLoading = true;
  bool _hasGlobalData = false;
  List<DailyStatEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  @override
  void didUpdateWidget(covariant StatsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _loadStats();
  }

  Future<void> _loadStats() async {
    final hasData = await LocalDatabase.instance.hasAnyLoggedData();
    final entries = await LocalDatabase.instance.getHistoricalStats(_selectedRange);
    if (!mounted) return;
    setState(() {
      _hasGlobalData = hasData;
      _entries = entries;
      _isLoading = false;
    });
  }

  String _formatWeekdayInitial(String dateStr) {
    try {
      final d = DateTime.parse(dateStr);
      final today = DateTime.now();
      if (d.year == today.year && d.month == today.month && d.day == today.day) {
        return 'Oggi';
      }
      const days = ['L', 'M', 'M', 'G', 'V', 'S', 'D'];
      return days[d.weekday - 1];
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final nutrients = context.nutrients;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Se non c'è alcuno storico nel database, mostra l'empty state pulito
    if (!_hasGlobalData) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Symbols.monitoring_rounded,
                  size: 40,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Nessun dato nello storico',
                style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Non ci sono ancora pasti, acqua o peso registrati.\nInizia ad aggiungere i tuoi pasti nella schermata Oggi per visualizzare le statistiche e l\'andamento nutrizionale.',
                textAlign: TextAlign.center,
                style: tt.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final hasDataInRange = _entries.any(
      (e) => e.kcal > 0 || e.waterMl > 0 || (e.weightKg != null && e.weightKg! > 0),
    );

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
          onSelectionChanged: (s) {
            setState(() {
              _selectedRange = s.first;
              _isLoading = true;
            });
            _loadStats();
          },
        ),
        const SizedBox(height: 14),

        if (!hasDataInRange) ...[
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              child: Column(
                children: [
                  Icon(Symbols.event_busy_rounded, size: 44, color: cs.onSurfaceVariant),
                  const SizedBox(height: 12),
                  Text(
                    'Nessun dato negli ultimi $_selectedRange giorni',
                    style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Registra nuovi pasti o seleziona un periodo più ampio.',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          _buildCaloriesCard(cs, tt, nutrients),
          const SizedBox(height: 12),
          _buildNutrientsCard(cs, tt, nutrients),
          const SizedBox(height: 12),
          _buildWeightCard(cs, tt, nutrients),
        ],
      ],
    );
  }

  Widget _buildCaloriesCard(ColorScheme cs, TextTheme tt, NutrientColors nutrients) {
    final activeDays = _entries.where((e) => e.kcal > 0).toList();
    final totalKcal = activeDays.fold(0.0, (sum, e) => sum + e.kcal);
    final avgKcal = activeDays.isNotEmpty ? (totalKcal / activeDays.length).round() : 0;
    final maxKcal = _entries.fold(
      widget.profile.targetKcal.toDouble(),
      (m, e) => max(m, e.kcal),
    );

    return Card(
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
                  avgKcal > 0 ? 'Media: $avgKcal kcal' : 'Media: -',
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
                children: List.generate(_entries.length, (i) {
                  final entry = _entries[i];
                  final kcal = entry.kcal.round();
                  final isOver = kcal > widget.profile.targetKcal;
                  final ratio = maxKcal > 0 ? (entry.kcal / maxKcal).clamp(0.0, 1.0) : 0.0;
                  final isToday = i == _entries.length - 1;

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (kcal > 0)
                            Text(
                              _selectedRange <= 7 ? '$kcal' : '',
                              style: tt.labelSmall?.copyWith(
                                fontSize: 9,
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          const SizedBox(height: 4),
                          Container(
                            width: _selectedRange <= 7 ? 24 : (_selectedRange <= 30 ? 7 : 2.5),
                            height: kcal > 0 ? max(8.0, 95 * ratio) : 4.0,
                            decoration: BoxDecoration(
                              color: kcal > 0
                                  ? (isOver ? nutrients.carbs : cs.primary)
                                  : cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 6),
                          if (_selectedRange <= 7)
                            Text(
                              _formatWeekdayInitial(entry.date),
                              style: tt.labelSmall?.copyWith(
                                color: isToday ? cs.primary : cs.onSurfaceVariant,
                                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutrientsCard(ColorScheme cs, TextTheme tt, NutrientColors nutrients) {
    final activeDays = _entries.where((e) => e.kcal > 0).toList();
    final totalP = activeDays.fold(0.0, (sum, e) => sum + e.protein);
    final totalC = activeDays.fold(0.0, (sum, e) => sum + e.carbs);
    final totalF = activeDays.fold(0.0, (sum, e) => sum + e.fat);
    final totalFiber = activeDays.fold(0.0, (sum, e) => sum + e.fiber);

    final avgP = activeDays.isNotEmpty ? (totalP / activeDays.length).round() : 0;
    final avgC = activeDays.isNotEmpty ? (totalC / activeDays.length).round() : 0;
    final avgF = activeDays.isNotEmpty ? (totalF / activeDays.length).round() : 0;
    final avgFiber = activeDays.isNotEmpty ? (totalFiber / activeDays.length).round() : 0;

    final pKcal = avgP * 4;
    final cKcal = avgC * 4;
    final fKcal = avgF * 9;
    final totalMacroKcal = pKcal + cKcal + fKcal;

    final pPct = totalMacroKcal > 0 ? ((pKcal / totalMacroKcal) * 100).round() : 0;
    final cPct = totalMacroKcal > 0 ? ((cKcal / totalMacroKcal) * 100).round() : 0;
    final fPct = totalMacroKcal > 0 ? max(0, 100 - pPct - cPct) : 0;

    final waterDays = _entries.where((e) => e.waterMl > 0).toList();
    final avgWaterL = waterDays.isNotEmpty
        ? (waterDays.fold(0, (sum, e) => sum + e.waterMl) / waterDays.length / 1000.0)
            .toStringAsFixed(1)
        : '0,0';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Ripartizione Media Nutrienti', style: tt.titleLarge),
            const SizedBox(height: 12),
            if (totalMacroKcal > 0) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: SizedBox(
                  height: 14,
                  child: Row(
                    children: [
                      if (pPct > 0)
                        Expanded(flex: pPct, child: Container(color: nutrients.protein)),
                      if (pPct > 0 && (cPct > 0 || fPct > 0)) const SizedBox(width: 3),
                      if (cPct > 0)
                        Expanded(flex: cPct, child: Container(color: nutrients.carbs)),
                      if (cPct > 0 && fPct > 0) const SizedBox(width: 3),
                      if (fPct > 0)
                        Expanded(flex: fPct, child: Container(color: nutrients.fat)),
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
                    '● Proteine $pPct% (${avgP}g)',
                    style: tt.labelSmall?.copyWith(color: nutrients.protein),
                  ),
                  Text(
                    '● Carbo $cPct% (${avgC}g)',
                    style: tt.labelSmall?.copyWith(color: nutrients.carbs),
                  ),
                  Text(
                    '● Grassi $fPct% (${avgF}g)',
                    style: tt.labelSmall?.copyWith(color: nutrients.fat),
                  ),
                ],
              ),
            ] else ...[
              Text(
                'Nessun pasto registrato negli ultimi $_selectedRange giorni.',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: cs.surfaceDim,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        Icon(Symbols.eco_rounded, size: 15, color: nutrients.fiber),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Fibre: ${avgFiber}g / giorno',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tt.labelSmall?.copyWith(
                              color: nutrients.fiber,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: cs.surfaceDim,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        Icon(Symbols.water_drop_rounded, size: 15, color: nutrients.water),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Acqua: $avgWaterL L / giorno',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tt.labelSmall?.copyWith(
                              color: nutrients.water,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeightCard(ColorScheme cs, TextTheme tt, NutrientColors nutrients) {
    final loggedWeights = _entries
        .where((e) => e.weightKg != null && e.weightKg! > 0)
        .map((e) => e.weightKg!)
        .toList();

    final String badgeText;
    final Color badgeColor;
    final String currentWeightText;
    final String explanationText;

    if (loggedWeights.length >= 2) {
      final delta = loggedWeights.last - loggedWeights.first;
      badgeText = '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)} kg (${_selectedRange}gg)';
      badgeColor = delta <= 0 ? nutrients.fiber : nutrients.carbs;
      currentWeightText = '${loggedWeights.last.toStringAsFixed(1)} kg';
      explanationText = 'Variazione peso registrata negli ultimi $_selectedRange giorni.';
    } else if (loggedWeights.length == 1) {
      badgeText = '1 pesata';
      badgeColor = cs.primary;
      currentWeightText = '${loggedWeights.first.toStringAsFixed(1)} kg';
      explanationText = 'Registra altre pesate per visualizzare la variazione nel tempo.';
    } else {
      badgeText = 'Nessuna pesata';
      badgeColor = cs.onSurfaceVariant;
      currentWeightText = '${widget.profile.currentWeightKg.toStringAsFixed(1)} kg';
      explanationText = 'Nessuna pesata registrata negli ultimi $_selectedRange giorni.';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Andamento Peso',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.titleLarge,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badgeText,
                    style: tt.labelSmall?.copyWith(color: badgeColor, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(currentWeightText, style: tt.headlineSmall),
            const SizedBox(height: 4),
            Text(
              explanationText,
              style: tt.bodyMedium?.copyWith(
                fontSize: 12,
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
