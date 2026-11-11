import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../models/nutrition_models.dart';
import '../services/ai_nutrition_service.dart';
import '../services/secure_keys_service.dart';
import '../theme/app_theme.dart';
import '../theme/nutrient_colors.dart';

class MenuAdvisorDialog extends StatefulWidget {
  final UserProfile profile;
  final int remainingKcal;
  final double remainingProteinG;
  final double remainingCarbsG;
  final double remainingFatG;
  final ValueChanged<MenuDishRecommendation> onSelectDish;

  const MenuAdvisorDialog({
    super.key,
    required this.profile,
    required this.remainingKcal,
    required this.remainingProteinG,
    required this.remainingCarbsG,
    required this.remainingFatG,
    required this.onSelectDish,
  });

  @override
  State<MenuAdvisorDialog> createState() => _MenuAdvisorDialogState();
}

class _MenuAdvisorDialogState extends State<MenuAdvisorDialog> {
  final AiNutritionService _aiService = AiNutritionService();
  final SecureKeysService _keysService = SecureKeysService();
  final ImagePicker _picker = ImagePicker();

  int _inputMode = 0; // 0 = Link, 1 = Testo, 2 = Foto
  final TextEditingController _urlCtrl = TextEditingController();
  final TextEditingController _textCtrl = TextEditingController();
  Uint8List? _imageBytes;
  String? _imageFileName;

  bool _isAnalyzing = false;
  String? _errorMessage;
  MenuAnalysisResult? _result;

  @override
  void dispose() {
    _urlCtrl.dispose();
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final xfile = await _picker.pickImage(source: source, imageQuality: 85);
      if (xfile == null) return;
      final bytes = await xfile.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _imageFileName = xfile.name;
        _errorMessage = null;
      });
    } catch (e) {
      setState(() => _errorMessage = 'Errore acquisizione immagine: $e');
    }
  }

  Future<void> _runAnalysis() async {
    final key = await _keysService.getApiKey(widget.profile.preferredAiProvider);
    if (key == null || key.isEmpty) {
      setState(() {
        _errorMessage =
            'Nessuna API Key configurata. Vai in Profilo e inserisci la tua chiave ${widget.profile.preferredAiProvider == AiProviderType.gemini ? "Gemini" : "OpenAI"}.';
      });
      return;
    }

    final url = _urlCtrl.text.trim();
    final text = _textCtrl.text.trim();
    if (_inputMode == 0 && url.isEmpty) {
      setState(() => _errorMessage = 'Inserisci l\'URL del menu o del ristorante.');
      return;
    }
    if (_inputMode == 1 && text.isEmpty) {
      setState(() => _errorMessage = 'Incolla o scrivi il testo del menu.');
      return;
    }
    if (_inputMode == 2 && _imageBytes == null) {
      setState(() => _errorMessage = 'Scatta o seleziona una foto del menu.');
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
      _result = null;
    });

    try {
      final res = await _aiService.analyzeMenuAndRecommend(
        provider: widget.profile.preferredAiProvider,
        modelName: widget.profile.preferredAiModel,
        apiKey: key,
        menuUrl: _inputMode == 0 ? url : null,
        menuText: _inputMode == 1 ? text : null,
        menuImageBytes: _inputMode == 2 ? _imageBytes : null,
        remainingKcal: widget.remainingKcal,
        remainingProteinG: widget.remainingProteinG,
        remainingCarbsG: widget.remainingCarbsG,
        remainingFatG: widget.remainingFatG,
      );
      if (!mounted) return;
      setState(() => _result = res);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final nutrients = context.nutrients;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusHero),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Bar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Symbols.restaurant_menu_rounded,
                        color: cs.primary,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text('Consiglia da menu', style: tt.titleLarge),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Symbols.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 6),

              // Macro Gap Summary Strip
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: cs.surfaceDim,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Oggi mancano:',
                      style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                    Text(
                      '${widget.remainingKcal} kcal',
                      style: tt.labelSmall?.copyWith(
                        color: cs.primary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      'P: ${widget.remainingProteinG.round()}g',
                      style: tt.labelSmall?.copyWith(
                        color: nutrients.protein,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      'C: ${widget.remainingCarbsG.round()}g',
                      style: tt.labelSmall?.copyWith(
                        color: nutrients.carbs,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    Text(
                      'G: ${widget.remainingFatG.round()}g',
                      style: tt.labelSmall?.copyWith(
                        color: nutrients.fat,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Content Area: Inputs OR Results
              Expanded(
                child: _result != null
                    ? _buildResultsView(context)
                    : _buildInputView(context),
              ),

              // Bottom CTA
              if (_result == null) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: _isAnalyzing ? null : _runAnalysis,
                  icon: _isAnalyzing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Symbols.restaurant_menu_rounded, size: 18),
                  label: Text(
                    _isAnalyzing ? 'Analisi menu in corso...' : 'Trova i piatti migliori',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputView(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 3-way input mode selector
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              segments: const [
                ButtonSegment(value: 0, label: Text('Link web')),
                ButtonSegment(value: 1, label: Text('Testo menu')),
                ButtonSegment(value: 2, label: Text('Foto / Doc')),
              ],
              selected: {_inputMode},
              onSelectionChanged: (s) {
                setState(() {
                  _inputMode = s.first;
                  _errorMessage = null;
                });
              },
            ),
          ),
          const SizedBox(height: 14),

          // Input controls based on mode
          if (_inputMode == 0) ...[
            TextField(
              controller: _urlCtrl,
              autocorrect: false,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                filled: true,
                fillColor: cs.surfaceDim,
                hintText: 'https://ristorante.it/menu...',
                prefixIcon: const Icon(Symbols.link_rounded),
                helperText: 'Inserisci il link del menu del ristorante o piattaforma online',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
              ),
            ),
          ] else if (_inputMode == 1) ...[
            TextField(
              controller: _textCtrl,
              maxLines: 7,
              decoration: InputDecoration(
                filled: true,
                fillColor: cs.surfaceDim,
                hintText: 'Incolla qui la lista dei piatti del menu (es. Primi, Secondi, Pizze, Contorni)...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cs.surfaceDim,
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.25),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    _imageBytes != null
                        ? Symbols.image_rounded
                        : Symbols.photo_camera_rounded,
                    size: 36,
                    color: cs.primary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _imageFileName ?? 'Scatta o carica una foto del menu cartaceo',
                    style: tt.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: () => _pickImage(ImageSource.camera),
                        icon: const Icon(Symbols.photo_camera_rounded, size: 16),
                        label: const Text('Fotocamera'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _pickImage(ImageSource.gallery),
                        icon: const Icon(Symbols.photo_library_rounded, size: 16),
                        label: const Text('Galleria'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cs.errorContainer,
                borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
              ),
              child: Row(
                children: [
                  Icon(Symbols.error_rounded, color: cs.onErrorContainer, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: tt.bodySmall?.copyWith(color: cs.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultsView(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final nutrients = context.nutrients;
    final res = _result!;

    return ListView(
      children: [
        // Strategy Advice Callout
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
            border: Border.all(
              color: cs.outlineVariant.withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Symbols.lightbulb_rounded, size: 16, color: cs.primary),
                  const SizedBox(width: 6),
                  Text(
                    res.restaurantName,
                    style: tt.titleMedium?.copyWith(fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                res.summaryAdvice,
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        Text(
          'I migliori piatti per i tuoi macro:',
          style: tt.titleMedium?.copyWith(fontSize: 14.5),
        ),
        const SizedBox(height: 8),

        // 3 Recommendations
        ...res.recommendations.map((rec) {
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppTheme.radiusCard),
              border: Border.all(
                color: rec.isTopPick
                    ? cs.primary.withValues(alpha: 0.5)
                    : cs.outlineVariant.withValues(alpha: 0.22),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (rec.isTopPick)
                            Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: cs.primaryContainer,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'Miglior scelta',
                                style: tt.labelSmall?.copyWith(
                                  color: cs.primary,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          Text(rec.dishName, style: tt.titleMedium),
                        ],
                      ),
                    ),
                    Text(
                      '${rec.estimatedKcal} kcal',
                      style: tt.labelMedium?.copyWith(
                        fontSize: 13,
                        color: cs.primary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  rec.reasoning,
                  style: tt.bodyMedium?.copyWith(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                if (rec.cautionNotes != null && rec.cautionNotes!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Symbols.info_rounded, size: 13, color: nutrients.carbs),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          rec.cautionNotes!,
                          style: tt.bodySmall?.copyWith(
                            fontSize: 11,
                            color: nutrients.carbs,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),

                // Macro pill row + Add button
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        children: [
                          Text(
                            'P: ${rec.estimatedProteinG.round()}g',
                            style: tt.labelSmall?.copyWith(
                              color: nutrients.protein,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                          Text(
                            'C: ${rec.estimatedCarbsG.round()}g',
                            style: tt.labelSmall?.copyWith(
                              color: nutrients.carbs,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                          Text(
                            'G: ${rec.estimatedFatG.round()}g',
                            style: tt.labelSmall?.copyWith(
                              color: nutrients.fat,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),
                    FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      onPressed: () {
                        widget.onSelectDish(rec);
                        Navigator.of(context).pop();
                      },
                      child: const Text('Scegli'),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),

        if (res.dishesToAvoid.isNotEmpty) ...[
          const SizedBox(height: 4),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            dense: true,
            title: Text(
              'Piatti da limitare oggi (${res.dishesToAvoid.length})',
              style: tt.labelMedium?.copyWith(color: cs.error),
            ),
            children: res.dishesToAvoid.map((d) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Symbols.close_rounded, size: 14, color: cs.error),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        d,
                        style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],

        const SizedBox(height: 10),
        Center(
          child: TextButton.icon(
            icon: const Icon(Symbols.refresh_rounded, size: 16),
            label: const Text('Analizza un altro menu'),
            onPressed: () => setState(() => _result = null),
          ),
        ),
      ],
    );
  }
}
