import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../data/local_database.dart';
import '../models/nutrition_models.dart';
import '../services/ai_nutrition_service.dart';
import '../services/secure_keys_service.dart';
import '../theme/app_theme.dart';
import '../theme/nutrient_colors.dart';

class DailyAiSummarySheet extends StatefulWidget {
  final String date;
  final UserProfile profile;
  final List<MealEntry>? preloadedMeals;
  final DailyMetrics? preloadedMetrics;

  const DailyAiSummarySheet({
    super.key,
    required this.date,
    required this.profile,
    this.preloadedMeals,
    this.preloadedMetrics,
  });

  static Future<void> show(
    BuildContext context, {
    required String date,
    required UserProfile profile,
    List<MealEntry>? meals,
    DailyMetrics? metrics,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.radiusSheet),
        ),
      ),
      builder: (_) => DailyAiSummarySheet(
        date: date,
        profile: profile,
        preloadedMeals: meals,
        preloadedMetrics: metrics,
      ),
    );
  }

  @override
  State<DailyAiSummarySheet> createState() => _DailyAiSummarySheetState();
}

class _DailyAiSummarySheetState extends State<DailyAiSummarySheet> {
  final AiNutritionService _aiService = AiNutritionService();
  final SecureKeysService _keysService = SecureKeysService();

  bool _isLoadingInitial = true;
  bool _isGenerating = false;
  String? _error;

  DailyAiSummary? _summary;
  List<MealEntry> _meals = [];
  late DailyMetrics _metrics;

  @override
  void initState() {
    super.initState();
    _metrics = widget.preloadedMetrics ?? DailyMetrics(date: widget.date);
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    final meals = widget.preloadedMeals ??
        await LocalDatabase.instance.getMealsForDate(widget.date);
    final metrics = widget.preloadedMetrics ??
        await LocalDatabase.instance.getDailyMetrics(widget.date);
    final savedSummary =
        await LocalDatabase.instance.getDailyAiSummary(widget.date);

    if (!mounted) return;
    setState(() {
      _meals = meals;
      _metrics = metrics;
      _summary = savedSummary;
      _isLoadingInitial = false;
    });
  }

  Future<void> _generateAndSave() async {
    final apiKey =
        await _keysService.getApiKey(widget.profile.preferredAiProvider);
    if (apiKey == null || apiKey.isEmpty) {
      if (!mounted) return;
      setState(() {
        _error =
            'Configura prima la tua API Key Gemini o OpenAI nella scheda Profilo.';
      });
      return;
    }

    setState(() {
      _isGenerating = true;
      _error = null;
    });

    try {
      final result = await _aiService.generateDailySummary(
        provider: widget.profile.preferredAiProvider,
        modelName: widget.profile.preferredAiModel,
        apiKey: apiKey,
        date: widget.date,
        profile: widget.profile,
        meals: _meals,
        metrics: _metrics,
      );

      await LocalDatabase.instance.saveDailyAiSummary(result);
      if (!mounted) return;
      setState(() {
        _summary = result;
        _isGenerating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Errore durante l\'analisi AI: $e';
        _isGenerating = false;
      });
    }
  }

  String _formatDateLabel(String dateStr) {
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
      return '${weekdays[d.weekday - 1]} ${d.day} ${months[d.month - 1]} ${d.year}';
    } catch (_) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final nutrients = context.nutrients;

    final totalKcal = _meals.fold(0, (s, m) => s + m.totalKcal);
    final totalP = _meals.fold(0.0, (s, m) => s + m.totalProteinG).round();
    final waterL = (_metrics.waterMl / 1000.0).toStringAsFixed(2);
    final kcalDiff = totalKcal - widget.profile.targetKcal;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.55,
      maxChildSize: 0.95,
      builder: (context, scrollCtrl) {
        return ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Icon(Symbols.auto_awesome_rounded, color: cs.primary, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Resoconto AI • Fine Giornata',
                    style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _formatDateLabel(widget.date),
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),

            if (_isLoadingInitial)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 48),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              // Snapshot Metrics Strip
              Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      value: '$totalKcal',
                      label: 'kcal assunte',
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MetricTile(
                      value: '${totalP}g',
                      label: 'Proteine',
                      color: nutrients.protein,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _MetricTile(
                      value: '${waterL}L',
                      label: 'Acqua (${_metrics.coffeeCups} ☕)',
                      color: nutrients.water,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cs.errorContainer,
                    borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                  ),
                  child: Text(
                    _error!,
                    style: tt.bodySmall?.copyWith(color: cs.onErrorContainer),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              if (_isGenerating) ...[
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 20),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppTheme.radiusHero),
                  ),
                  child: Column(
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        'Analisi della giornata in corso...',
                        style: tt.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Valutazione di calorie, macro, fibre e idratazione.',
                        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ] else if (_summary == null) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppTheme.radiusHero),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Symbols.psychology_rounded,
                        size: 48,
                        color: cs.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Nessun resoconto salvato per questa giornata',
                        style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Genera un\'analisi nutrizionale completa della tua giornata. Una volta creata verrà salvata in locale e potrai consultarla in qualsiasi momento.',
                        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 18),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          shape: const StadiumBorder(),
                        ),
                        onPressed: _generateAndSave,
                        icon: const Icon(Symbols.auto_awesome_rounded),
                        label: const Text('Genera Resoconto AI'),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // Saved Summary Hero Card
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(AppTheme.radiusHero),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: nutrients.fiber.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Voto: ${_summary!.score.toStringAsFixed(1)} / 10',
                              style: tt.labelSmall?.copyWith(
                                color: nutrients.fiber,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${kcalDiff >= 0 ? '+' : ''}$kcalDiff kcal vs target',
                            style: tt.labelSmall?.copyWith(
                              color: cs.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _summary!.headline,
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: cs.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _summary!.verdict,
                        style: tt.bodySmall?.copyWith(
                          color: cs.onPrimaryContainer.withValues(alpha: 0.9),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                if (_summary!.strengths.isNotEmpty) ...[
                  _InsightSectionCard(
                    icon: Symbols.check_circle_rounded,
                    accentColor: nutrients.fiber,
                    title: 'Punti di forza',
                    bullets: _summary!.strengths,
                  ),
                  const SizedBox(height: 10),
                ],

                if (_summary!.warnings.isNotEmpty) ...[
                  _InsightSectionCard(
                    icon: Symbols.warning_rounded,
                    accentColor: nutrients.carbs,
                    title: 'Aree di attenzione',
                    bullets: _summary!.warnings,
                  ),
                  const SizedBox(height: 10),
                ],

                if (_summary!.adviceTomorrow.isNotEmpty) ...[
                  _InsightSectionCard(
                    icon: Symbols.tips_and_updates_rounded,
                    accentColor: cs.primary,
                    title: 'Consiglio per domani',
                    bullets: [_summary!.adviceTomorrow],
                  ),
                  const SizedBox(height: 16),
                ],

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          shape: const StadiumBorder(),
                        ),
                        onPressed: _generateAndSave,
                        icon: const Icon(Symbols.refresh_rounded, size: 18),
                        label: const Text('Rigenera AI'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          shape: const StadiumBorder(),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Symbols.check_rounded, size: 18),
                        label: const Text('Chiudi'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ],
        );
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _MetricTile({
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: tt.titleMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _InsightSectionCard extends StatelessWidget {
  final IconData icon;
  final Color accentColor;
  final String title;
  final List<String> bullets;

  const _InsightSectionCard({
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.bullets,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: accentColor),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: tt.titleSmall?.copyWith(
                    color: accentColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ...bullets.map(
              (b) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• $b',
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurface,
                    height: 1.35,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
