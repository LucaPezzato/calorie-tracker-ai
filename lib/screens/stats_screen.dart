import 'dart:math';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../data/local_database.dart';
import '../models/nutrition_models.dart';
import '../theme/app_theme.dart';
import '../theme/nutrient_colors.dart';
import 'daily_ai_summary_sheet.dart';

class StatsScreen extends StatefulWidget {
  final UserProfile profile;

  const StatsScreen({super.key, required this.profile});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  int _viewMode = 0; // 0 = Andamento, 1 = Calendario
  int _selectedRange = 7; // 7, 30, 90 days
  bool _isLoading = true;
  bool _hasGlobalData = false;
  List<DailyStatEntry> _entries = [];

  // Calendar state
  late int _calYear;
  late int _calMonth;
  late String _selectedCalendarDate;
  Map<String, DailyStatEntry> _monthStats = {};
  Set<String> _monthAiSummaryDates = {};
  List<MealEntry> _selectedDayMeals = [];
  bool _isLoadingDayDetails = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _calYear = now.year;
    _calMonth = now.month;
    _selectedCalendarDate = now.toIso8601String().split('T').first;
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
    final monthStats = await LocalDatabase.instance.getMonthStats(_calYear, _calMonth);
    final aiDates = await LocalDatabase.instance.getDatesWithAiSummary(_calYear, _calMonth);
    final dayMeals = await LocalDatabase.instance.getMealsForDate(_selectedCalendarDate);

    if (!mounted) return;
    setState(() {
      _hasGlobalData = hasData;
      _entries = entries;
      _monthStats = monthStats;
      _monthAiSummaryDates = aiDates;
      _selectedDayMeals = dayMeals;
      _isLoading = false;
    });
  }

  Future<void> _changeMonth(int delta) async {
    var m = _calMonth + delta;
    var y = _calYear;
    if (m < 1) {
      m = 12;
      y -= 1;
    } else if (m > 12) {
      m = 1;
      y += 1;
    }
    setState(() {
      _calYear = y;
      _calMonth = m;
    });
    final monthStats = await LocalDatabase.instance.getMonthStats(_calYear, _calMonth);
    final aiDates = await LocalDatabase.instance.getDatesWithAiSummary(_calYear, _calMonth);
    if (!mounted) return;
    setState(() {
      _monthStats = monthStats;
      _monthAiSummaryDates = aiDates;
    });
  }

  Future<void> _selectCalendarDay(String dateStr) async {
    setState(() {
      _selectedCalendarDate = dateStr;
      _isLoadingDayDetails = true;
    });
    final meals = await LocalDatabase.instance.getMealsForDate(dateStr);
    if (!mounted) return;
    setState(() {
      _selectedDayMeals = meals;
      _isLoadingDayDetails = false;
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

  String _formatMonthName(int month) {
    const months = [
      'Gennaio',
      'Febbraio',
      'Marzo',
      'Aprile',
      'Maggio',
      'Giugno',
      'Luglio',
      'Agosto',
      'Settembre',
      'Ottobre',
      'Novembre',
      'Dicembre',
    ];
    return months[(month - 1).clamp(0, 11)];
  }

  String _formatFullDate(String dateStr) {
    try {
      final d = DateTime.parse(dateStr);
      const weekdays = [
        'Lunedì',
        'Martedì',
        'Mercoledì',
        'Giovedì',
        'Venerdì',
        'Sabato',
        'Domenica',
      ];
      return '${weekdays[d.weekday - 1]} ${d.day} ${_formatMonthName(d.month)}';
    } catch (_) {
      return dateStr;
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
                'Non ci sono ancora pasti, acqua o peso registrati.\nInizia ad aggiungere i tuoi pasti nella schermata Oggi per visualizzare le statistiche e il calendario.',
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // Top View Switch: Andamento vs Calendario
        SegmentedButton<int>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(
              value: 0,
              icon: Icon(Symbols.bar_chart_rounded, size: 18),
              label: Text('Andamento'),
            ),
            ButtonSegment(
              value: 1,
              icon: Icon(Symbols.calendar_month_rounded, size: 18),
              label: Text('Calendario'),
            ),
          ],
          selected: {_viewMode},
          onSelectionChanged: (s) => setState(() => _viewMode = s.first),
        ),
        const SizedBox(height: 14),

        if (_viewMode == 0)
          ..._buildTrendsView(cs, tt, nutrients)
        else
          ..._buildCalendarView(cs, tt, nutrients),
      ],
    );
  }

  List<Widget> _buildTrendsView(
    ColorScheme cs,
    TextTheme tt,
    NutrientColors nutrients,
  ) {
    final hasDataInRange = _entries.any(
      (e) => e.kcal > 0 || e.waterMl > 0 || (e.weightKg != null && e.weightKg! > 0),
    );

    return [
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
      if (!hasDataInRange)
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
        )
      else ...[
        _buildCaloriesCard(cs, tt, nutrients),
        const SizedBox(height: 12),
        _buildNutrientsCard(cs, tt, nutrients),
        const SizedBox(height: 12),
        _buildWeightCard(cs, tt, nutrients),
      ],
    ];
  }

  List<Widget> _buildCalendarView(
    ColorScheme cs,
    TextTheme tt,
    NutrientColors nutrients,
  ) {
    final now = DateTime.now();
    final todayStr = now.toIso8601String().split('T').first;
    final isCurrentMonth = _calYear == now.year && _calMonth == now.month;

    final firstDayOfMonth = DateTime(_calYear, _calMonth, 1);
    final daysInMonth = DateTime(_calYear, _calMonth + 1, 0).day;
    final leadingEmptyCells = firstDayOfMonth.weekday - 1; // Monday = 1 -> 0 empty

    final targetKcal = widget.profile.targetKcal;
    final loggedDays = _monthStats.values.where((e) => e.kcal > 0).toList();
    final inTargetCount = loggedDays
        .where((e) => (e.kcal - targetKcal).abs() <= targetKcal * 0.12)
        .length;

    final selectedStat = _monthStats[_selectedCalendarDate] ??
        DailyStatEntry(date: _selectedCalendarDate);
    final hasSavedAi = _monthAiSummaryDates.contains(_selectedCalendarDate);

    return [
      // Month Grid Card
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${_formatMonthName(_calMonth)} $_calYear',
                      style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (loggedDays.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: nutrients.fiber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '$inTargetCount/${loggedDays.length} in target',
                        style: tt.labelSmall?.copyWith(
                          color: nutrients.fiber,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  const SizedBox(width: 6),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _changeMonth(-1),
                    icon: const Icon(Symbols.chevron_left_rounded),
                    tooltip: 'Mese precedente',
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: isCurrentMonth ? null : () => _changeMonth(1),
                    icon: const Icon(Symbols.chevron_right_rounded),
                    tooltip: 'Mese successivo',
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Weekday Headers
              Row(
                children: const ['L', 'M', 'M', 'G', 'V', 'S', 'D']
                    .map(
                      (d) => Expanded(
                        child: Center(
                          child: Text(
                            d,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 8),

              // Calendar Days Grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: leadingEmptyCells + daysInMonth,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                ),
                itemBuilder: (context, index) {
                  if (index < leadingEmptyCells) {
                    return const SizedBox.shrink();
                  }
                  final dayNum = index - leadingEmptyCells + 1;
                  final dateStr =
                      '$_calYear-${_calMonth.toString().padLeft(2, '0')}-${dayNum.toString().padLeft(2, '0')}';
                  final stat = _monthStats[dateStr];
                  final isSelected = dateStr == _selectedCalendarDate;
                  final isToday = dateStr == todayStr;
                  final hasAi = _monthAiSummaryDates.contains(dateStr);

                  Color? ringColor;
                  Color? fillColor;
                  if (stat != null && stat.kcal > 0) {
                    if ((stat.kcal - targetKcal).abs() <= targetKcal * 0.12) {
                      ringColor = nutrients.fiber;
                      fillColor = nutrients.fiber.withValues(alpha: 0.16);
                    } else if (stat.kcal > targetKcal * 1.12) {
                      ringColor = nutrients.carbs;
                      fillColor = nutrients.carbs.withValues(alpha: 0.16);
                    } else {
                      ringColor = cs.primary;
                      fillColor = cs.primary.withValues(alpha: 0.16);
                    }
                  } else if (stat != null && (stat.waterMl > 0 || stat.weightKg != null)) {
                    fillColor = cs.surfaceContainerHighest;
                  }

                  return InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => _selectCalendarDay(dateStr),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? cs.primaryContainer
                            : (fillColor ?? Colors.transparent),
                        border: Border.all(
                          color: isSelected
                              ? cs.primary
                              : (ringColor ??
                                  (isToday
                                      ? cs.primary.withValues(alpha: 0.5)
                                      : Colors.transparent)),
                          width: isSelected ? 2 : 1.5,
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Text(
                            '$dayNum',
                            style: tt.labelMedium?.copyWith(
                              color: isSelected
                                  ? cs.onPrimaryContainer
                                  : (stat != null && stat.kcal > 0
                                      ? cs.onSurface
                                      : cs.onSurfaceVariant),
                              fontWeight: isSelected || isToday
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          if (hasAi)
                            Positioned(
                              bottom: 3,
                              child: Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: cs.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 12),
              Divider(color: cs.outlineVariant.withValues(alpha: 0.25)),
              const SizedBox(height: 8),

              // Legend
              Wrap(
                spacing: 14,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: [
                  _LegendDot(color: nutrients.fiber, label: 'In target'),
                  _LegendDot(color: nutrients.carbs, label: 'Oltre target'),
                  _LegendDot(color: cs.primary, label: 'Parziale'),
                  _LegendDot(color: cs.onSurfaceVariant.withValues(alpha: 0.4), label: 'Vuoto'),
                ],
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),

      // Selected Day Inspector Card
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
                      _formatFullDate(_selectedCalendarDate),
                      style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${selectedStat.kcal.round()} kcal',
                      style: tt.labelSmall?.copyWith(
                        color: cs.onPrimaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Target: $targetKcal kcal  •  💧 ${(selectedStat.waterMl / 1000.0).toStringAsFixed(2)} L  •  ☕ ${selectedStat.coffeeCups}'
                '${selectedStat.weightKg != null ? '  •  ⚖️ ${selectedStat.weightKg!.toStringAsFixed(1)} kg' : ''}',
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 12),

              if (selectedStat.kcal > 0) ...[
                _buildDayMacroBar(selectedStat, cs, tt, nutrients),
                const SizedBox(height: 14),
              ],

              if (_isLoadingDayDetails)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else if (_selectedDayMeals.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    'Nessun pasto registrato in questa giornata.',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                )
              else
                ..._selectedDayMeals.map(
                  (m) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: cs.surfaceDim,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                    ),
                    child: Row(
                      children: [
                        Text(
                          m.loggedAt,
                          style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            m.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${m.totalKcal} kcal',
                          style: tt.labelMedium?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  shape: const StadiumBorder(),
                ),
                onPressed: () async {
                  await DailyAiSummarySheet.show(
                    context,
                    date: _selectedCalendarDate,
                    profile: widget.profile,
                    meals: _selectedDayMeals,
                  );
                  _loadStats();
                },
                icon: const Icon(Symbols.auto_awesome_rounded, size: 18),
                label: Text(
                  hasSavedAi
                      ? 'Vedi Resoconto AI salvato'
                      : 'Genera Resoconto AI del giorno',
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _buildDayMacroBar(
    DailyStatEntry stat,
    ColorScheme cs,
    TextTheme tt,
    NutrientColors nutrients,
  ) {
    final pKcal = stat.protein * 4;
    final cKcal = stat.carbs * 4;
    final fKcal = stat.fat * 9;
    final total = pKcal + cKcal + fKcal;
    final pFlex = total > 0 ? max(1, ((pKcal / total) * 100).round()) : 1;
    final cFlex = total > 0 ? max(1, ((cKcal / total) * 100).round()) : 1;
    final fFlex = total > 0 ? max(1, ((fKcal / total) * 100).round()) : 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 8,
            child: Row(
              children: [
                Expanded(flex: pFlex, child: Container(color: nutrients.protein)),
                const SizedBox(width: 2),
                Expanded(flex: cFlex, child: Container(color: nutrients.carbs)),
                const SizedBox(width: 2),
                Expanded(flex: fFlex, child: Container(color: nutrients.fat)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'P: ${stat.protein.round()}g',
              style: tt.labelSmall?.copyWith(color: nutrients.protein),
            ),
            Text(
              'C: ${stat.carbs.round()}g',
              style: tt.labelSmall?.copyWith(color: nutrients.carbs),
            ),
            Text(
              'G: ${stat.fat.round()}g',
              style: tt.labelSmall?.copyWith(color: nutrients.fat),
            ),
          ],
        ),
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

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}
