import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/nutrition_models.dart';
import '../services/ai_nutrition_service.dart';
import '../services/secure_keys_service.dart';
import '../theme/app_theme.dart';
import '../theme/nutrient_colors.dart';
import 'barcode_scanner_dialog.dart';

class AddMealBottomSheet extends StatefulWidget {
  final String selectedDate;
  final UserProfile profile;
  final MealEntry? existingMeal;
  final int initialMode;
  final void Function(MealEntry entry) onSaveMeal;
  final ValueChanged<List<MealEntry>>? onSaveMultipleMeals;
  final VoidCallback? onDeleteMeal;
  final VoidCallback? onOpenMenuAdvisor;

  const AddMealBottomSheet({
    super.key,
    required this.selectedDate,
    required this.profile,
    this.existingMeal,
    this.initialMode = 0,
    required this.onSaveMeal,
    this.onSaveMultipleMeals,
    this.onDeleteMeal,
    this.onOpenMenuAdvisor,
  });

  @override
  State<AddMealBottomSheet> createState() => _AddMealBottomSheetState();
}

class _AddMealBottomSheetState extends State<AddMealBottomSheet> {
  static const _uuid = Uuid();
  final AiNutritionService _aiService = AiNutritionService();
  final SecureKeysService _keysService = SecureKeysService();
  final ImagePicker _picker = ImagePicker();

  int _selectedMode = 0; // 0: AI Testo, 1: Foto, 2: Barcode, 3: Dispensa
  late String _loggedAtTime;
  late final TextEditingController _promptCtrl;
  final TextEditingController _refineCtrl = TextEditingController();

  late String _mealId;
  late String _mealTitle;
  String? _localPhotoPath;
  Uint8List? _selectedImageBytes;
  bool _isAnalyzing = false;
  bool _isFullDayMode = false;
  String? _errorMessage;
  late List<MealItem> _items;
  List<MealEntry> _fullDayMeals = [];

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.initialMode;
    final existing = widget.existingMeal;
    if (existing != null) {
      _mealId = existing.id;
      _mealTitle = existing.title;
      _loggedAtTime = existing.loggedAt;
      _localPhotoPath = existing.localPhotoPath;
      _items = List<MealItem>.from(existing.items);
      _promptCtrl = TextEditingController(text: existing.title);
    } else {
      final now = TimeOfDay.now();
      _loggedAtTime =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      _mealId = _uuid.v4();
      _mealTitle = '';
      _promptCtrl = TextEditingController();
      _items = [];
      if (widget.initialMode == 1) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _pickPhoto(ImageSource.camera);
        });
      }
    }
  }

  @override
  void dispose() {
    _promptCtrl.dispose();
    _refineCtrl.dispose();
    super.dispose();
  }

  int get _totalKcal => _items.fold(0, (s, i) => s + i.kcal);
  double get _totalP => _items.fold(0.0, (s, i) => s + i.proteinG);
  double get _totalC => _items.fold(0.0, (s, i) => s + i.carbsG);
  double get _totalG => _items.fold(0.0, (s, i) => s + i.fatG);

  Future<void> _pickPhoto(ImageSource source) async {
    final xfile = await _picker.pickImage(
      source: source,
      imageQuality: 80,
    );
    if (xfile != null) {
      final bytes = await xfile.readAsBytes();
      final supportDir = await getApplicationSupportDirectory();
      final photosDir = Directory(p.join(supportDir.path, 'meal_photos'));
      if (!photosDir.existsSync()) {
        photosDir.createSync(recursive: true);
      }
      final savedPath = p.join(photosDir.path, '$_mealId.jpg');
      await File(savedPath).writeAsBytes(bytes);
      if (!mounted) return;
      setState(() {
        _selectedImageBytes = bytes;
        _localPhotoPath = savedPath;
        _errorMessage = null;
      });
    }
  }

  Future<void> _onModeChanged(int mode) async {
    setState(() => _selectedMode = mode);
    if (mode == 1) {
      await _pickPhoto(ImageSource.gallery);
    } else if (mode == 2) {
      // Barcode mode: open live camera / EAN dialog
      final scannedItem = await showDialog<MealItem>(
        context: context,
        builder: (_) => BarcodeScannerDialog(mealId: _mealId),
      );
      if (scannedItem != null && mounted) {
        setState(() {
          _items = [..._items, scannedItem];
          _mealTitle = scannedItem.name;
        });
      }
    }
  }

  Future<void> _runAiAnalysis() async {
    FocusScope.of(context).unfocus();
    if (_promptCtrl.text.trim().isEmpty && _selectedImageBytes == null) {
      setState(() {
        _errorMessage =
            'Scrivi cosa hai mangiato o scatta una foto prima di analizzare.';
      });
      return;
    }

    final creds = await _keysService.resolveActiveCredentials(widget.profile);
    if (creds == null) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Nessuna API Key configurata (né Gemini né OpenAI). Inseriscila nella tab Profilo!';
      });
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
    });
    try {
      if (_isFullDayMode && _selectedImageBytes == null) {
        final meals = await _aiService.analyzeFullDayMeals(
          provider: creds.provider,
          modelName: creds.modelName,
          apiKey: creds.apiKey,
          date: widget.selectedDate,
          userPrompt: _promptCtrl.text,
        );
        if (!mounted) return;
        if (meals.isEmpty) {
          setState(() {
            _errorMessage =
                'Non sono riuscito a individuare i pasti. Prova es. "Colazione brioche, pranzo pasta al pesto, cena pizza".';
          });
          return;
        }
        setState(() {
          _fullDayMeals = meals;
          _items = [];
          _errorMessage = null;
        });
      } else {
        final result = await _aiService.analyzeMeal(
          provider: creds.provider,
          modelName: creds.modelName,
          apiKey: creds.apiKey,
          mealId: _mealId,
          userPrompt: _promptCtrl.text,
          imageBytes: _selectedImageBytes,
        );
        if (!mounted) return;
        if (result.items.isEmpty) {
          setState(() {
            _errorMessage =
                'Nessun alimento riconosciuto. Prova a descrivere meglio (es. "80g pasta, 100g tonno").';
          });
          return;
        }
        setState(() {
          _mealTitle = result.mealTitle;
          _items = result.items;
          _fullDayMeals = [];
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Errore analisi AI: $e';
      });
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _runAiRefinement() async {
    FocusScope.of(context).unfocus();
    final text = _refineCtrl.text.trim();
    if (text.isEmpty) return;

    final creds = await _keysService.resolveActiveCredentials(widget.profile);
    if (creds == null) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'Configura la API Key nella tab Profilo per usare "Correggi con AI".';
      });
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
    });
    try {
      final result = await _aiService.refineMealWithAi(
        provider: creds.provider,
        modelName: creds.modelName,
        apiKey: creds.apiKey,
        mealId: _mealId,
        currentResult: AiMealAnalysisResult(
          mealTitle: _mealTitle,
          items: _items,
        ),
        correctionInstruction: text,
      );
      if (!mounted) return;
      setState(() {
        _mealTitle = result.mealTitle;
        _items = result.items;
        _refineCtrl.clear();
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Errore correzione AI: $e';
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

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      minChildSize: 0.60,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: [
            // Header + Time Picker Pill
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    widget.existingMeal != null
                        ? 'Modifica pasto'
                        : 'Aggiungi pasto',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.headlineSmall,
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.onOpenMenuAdvisor != null && widget.existingMeal == null) ...[
                      ActionChip(
                        avatar: Icon(
                          Symbols.restaurant_menu_rounded,
                          size: 15,
                          color: cs.primary,
                        ),
                        label: const Text('Menu'),
                        shape: const StadiumBorder(),
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onOpenMenuAdvisor!();
                        },
                      ),
                      const SizedBox(width: 6),
                    ],
                    ActionChip(
                      avatar: Icon(
                        Symbols.schedule_rounded,
                        size: 16,
                        color: cs.primary,
                      ),
                      label: Text(
                        _loggedAtTime,
                        style: tt.labelMedium?.copyWith(
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      shape: const StadiumBorder(),
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (picked != null) {
                          setState(() {
                            _loggedAtTime =
                                '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                          });
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 4-Way Mode Segmented Button (Single-line clean labels)
            SegmentedButton<int>(
              showSelectedIcon: false,
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              segments: const [
                ButtonSegment(
                  value: 0,
                  label: Text('Testo'),
                ),
                ButtonSegment(
                  value: 1,
                  label: Text('Foto'),
                ),
                ButtonSegment(
                  value: 2,
                  label: Text('Barcode'),
                ),
                ButtonSegment(
                  value: 3,
                  label: Text('Dispensa'),
                ),
              ],
              selected: {_selectedMode},
              onSelectionChanged: (s) => _onModeChanged(s.first),
            ),
            const SizedBox(height: 14),

            if (widget.existingMeal == null &&
                widget.onSaveMultipleMeals != null &&
                _selectedImageBytes == null) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: FilterChip(
                  avatar: Icon(
                    Symbols.auto_stories_rounded,
                    size: 16,
                    color: _isFullDayMode ? cs.onSecondaryContainer : cs.primary,
                  ),
                  label: const Text('Racconta tutta la giornata (multi-pasto)'),
                  selected: _isFullDayMode,
                  onSelected: (v) {
                    setState(() {
                      _isFullDayMode = v;
                      _fullDayMeals = [];
                      _errorMessage = null;
                    });
                  },
                ),
              ),
              const SizedBox(height: 10),
            ],

            if (_selectedImageBytes != null) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cs.surfaceDim,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        _selectedImageBytes!,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Foto allegata',
                            style: tt.labelLarge,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Puoi aggiungere note sotto prima di premere Analizza.',
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Rimuovi foto',
                      onPressed: () {
                        setState(() {
                          _selectedImageBytes = null;
                          _localPhotoPath = null;
                        });
                      },
                      icon: const Icon(Symbols.close_rounded, size: 18),
                    ),
                  ],
                ),
              ),
            ],

            // Prompt Box
            TextField(
              controller: _promptCtrl,
              maxLines: 2,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _isAnalyzing ? null : _runAiAnalysis(),
              decoration: InputDecoration(
                filled: true,
                fillColor: cs.surfaceDim,
                hintText: _selectedImageBytes != null
                    ? 'Aggiungi note sulla foto (es. senza olio, metà porzione)...'
                    : _isFullDayMode
                        ? 'Es. Stamattina cappuccino e brioche, pranzo pasta al pesto, cena pizza...'
                        : 'Descrivi gli alimenti (es. 80g pasta, 100g tonno)...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                suffixIcon: _isAnalyzing
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        icon: Icon(
                          Symbols.auto_awesome_rounded,
                          color: cs.primary,
                        ),
                        onPressed: _runAiAnalysis,
                        tooltip: 'Analizza alimenti con AI',
                      ),
              ),
            ),
            if (_items.isEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: _isAnalyzing ? null : _runAiAnalysis,
                  icon: _isAnalyzing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Symbols.auto_awesome_rounded, size: 18),
                  label: Text(
                    _isAnalyzing ? 'Analisi AI in corso...' : 'Analizza pasto con AI',
                  ),
                ),
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.errorContainer,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Symbols.error_rounded,
                      color: cs.onErrorContainer,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: tt.bodySmall?.copyWith(
                          color: cs.onErrorContainer,
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        Symbols.close_rounded,
                        size: 16,
                        color: cs.onErrorContainer,
                      ),
                      onPressed: () => setState(() => _errorMessage = null),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),

            // Live Recalculated Total Banner
            if (_items.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _mealTitle.isEmpty ? 'Nuovo pasto' : _mealTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tt.titleMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'P: ${_totalP.round()}g  •  C: ${_totalC.round()}g  •  G: ${_totalG.round()}g',
                            style: tt.labelMedium?.copyWith(
                              color: cs.onPrimaryContainer.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$_totalKcal kcal',
                      style: tt.headlineSmall?.copyWith(color: cs.primary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Interactive Ingredient Cards with 120fps Gram Sliders (Swipe + Confirm to delete)
            ...List.generate(_items.length, (index) {
              final item = _items[index];
              final maxSlider = item.grams > 350 ? 600.0 : 350.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Dismissible(
                  key: ValueKey('ing_${item.id}'),
                  direction: DismissDirection.horizontal,
                  confirmDismiss: (_) async {
                    return await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Rimuovi ingrediente'),
                            content: Text(
                              'Vuoi rimuovere "${item.name}" (${item.grams.round()} g) da questo pasto?',
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
                  onDismissed: (_) {
                    setState(() {
                      _items.removeAt(index);
                    });
                  },
                  background: Container(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: cs.errorContainer,
                      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Symbols.delete_rounded,
                          color: cs.onErrorContainer,
                        ),
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
                        Icon(
                          Symbols.delete_rounded,
                          color: cs.onErrorContainer,
                        ),
                      ],
                    ),
                  ),
                  child: Card(
                    color: cs.surfaceContainer,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  '${index + 1}. ${item.name}',
                                  style: tt.titleMedium,
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Quick Half Portion Button
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                    icon: const Text('½', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    tooltip: 'Dimezza porzione (mezza porzione)',
                                    onPressed: () {
                                      setState(() {
                                        _items[index] = item.copyWith(
                                          grams: (item.grams / 2).clamp(5.0, 1000.0),
                                        );
                                      });
                                    },
                                  ),
                                  // Quick Double Portion Button
                                  IconButton(
                                    visualDensity: VisualDensity.compact,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                    icon: const Text('2×', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                    tooltip: 'Raddoppia porzione',
                                    onPressed: () {
                                      setState(() {
                                        _items[index] = item.copyWith(
                                          grams: (item.grams * 2).clamp(5.0, 1000.0),
                                        );
                                      });
                                    },
                                  ),
                                  const SizedBox(width: 4),
                                  // Tap to directly edit exact grams with keyboard
                                  InkWell(
                                    borderRadius: BorderRadius.circular(999),
                                    onTap: () async {
                                      final ctrl = TextEditingController(
                                        text: item.grams.round().toString(),
                                      );
                                      final newGrams = await showDialog<double>(
                                        context: context,
                                        builder: (ctx) => AlertDialog(
                                          title: Text('Grammi: ${item.name}'),
                                          content: TextField(
                                            controller: ctrl,
                                            autofocus: true,
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            decoration: const InputDecoration(
                                              labelText: 'Grammi (g)',
                                              suffixText: 'g',
                                            ),
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.pop(ctx),
                                              child: const Text('Annulla'),
                                            ),
                                            FilledButton(
                                              onPressed: () {
                                                final val = double.tryParse(ctrl.text.replaceAll(',', '.'));
                                                Navigator.pop(ctx, val);
                                              },
                                              child: const Text('Conferma'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (newGrams != null && newGrams > 0) {
                                        setState(() {
                                          _items[index] = item.copyWith(grams: newGrams);
                                        });
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: cs.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            '${item.grams.round()} g',
                                            style: tt.labelMedium?.copyWith(
                                              color: cs.primary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(width: 3),
                                          Icon(Symbols.edit_rounded, size: 12, color: cs.primary),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Slider(
                            value: item.grams.clamp(0.0, maxSlider),
                            min: 0,
                            max: maxSlider,
                            divisions: (maxSlider / 5).round(),
                            onChanged: (val) {
                              setState(() {
                                _items[index] = item.copyWith(grams: val);
                              });
                            },
                          ),
                          Row(
                            children: [
                              Text('${item.kcal} kcal', style: tt.labelMedium),
                              const SizedBox(width: 12),
                              Text(
                                'P: ${item.proteinG.round()}g',
                                style: tt.labelSmall?.copyWith(
                                  color: nutrients.protein,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'C: ${item.carbsG.round()}g',
                                style: tt.labelSmall?.copyWith(
                                  color: nutrients.carbs,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                'G: ${item.fatG.round()}g',
                                style: tt.labelSmall?.copyWith(
                                  color: nutrients.fat,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),

            // Conversational Refinement Input Bar
            if (_items.isNotEmpty) ...[
              const SizedBox(height: 4),
              TextField(
                controller: _refineCtrl,
                onSubmitted: (_) => _runAiRefinement(),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: cs.surfaceDim,
                  hintText: 'Modifica o aggiungi dettagli (es. "senza formaggio")...',
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(999),
                    borderSide: BorderSide(
                      color: cs.outlineVariant.withValues(alpha: 0.35),
                    ),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(Symbols.send_rounded, color: cs.primary),
                    onPressed: _runAiRefinement,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ] else ...[
              const SizedBox(height: 8),
            ],

            // Save CTA Button / Multi-meal Preview / Quick Estimate
            if (_fullDayMeals.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.primaryContainer.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pasti riconosciuti (${_fullDayMeals.length})',
                      style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ..._fullDayMeals.map(
                      (m) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Text(
                              m.loggedAt,
                              style: tt.labelSmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${m.title} (${m.items.map((i) => i.name).join(', ')})',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: tt.bodySmall,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${m.totalKcal} kcal',
                              style: tt.labelSmall?.copyWith(
                                color: cs.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: const StadiumBorder(),
                ),
                onPressed: () {
                  widget.onSaveMultipleMeals?.call(_fullDayMeals);
                  Navigator.of(context).pop();
                },
                icon: const Icon(Symbols.done_all_rounded),
                label: Text('Salva tutti i pasti (${_fullDayMeals.length})'),
              ),
            ] else ...[
              if (_items.isEmpty && widget.existingMeal == null && !_isFullDayMode) ...[
                Text(
                  'Stima rapida senza ingredienti',
                  style: tt.labelMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            _saveQuickEstimate('Pasto leggero', 500, 25, 55, 18),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: const Column(
                          children: [
                            Text('Leggero', style: TextStyle(fontSize: 12)),
                            Text('~500 kcal',
                                style: TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            _saveQuickEstimate('Pasto medio', 800, 40, 85, 30),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: const Column(
                          children: [
                            Text('Medio', style: TextStyle(fontSize: 12)),
                            Text('~800 kcal',
                                style: TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () =>
                            _saveQuickEstimate('Pasto abbondante', 1200, 50, 130, 48),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: const Column(
                          children: [
                            Text('Abbondante', style: TextStyle(fontSize: 12)),
                            Text('~1200 kcal',
                                style: TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  backgroundColor: _items.isEmpty && widget.existingMeal != null
                      ? cs.error
                      : null,
                  foregroundColor: _items.isEmpty && widget.existingMeal != null
                      ? cs.onError
                      : null,
                  shape: const StadiumBorder(),
                ),
                onPressed: _items.isEmpty && widget.existingMeal == null
                    ? null
                    : () {
                        if (_items.isEmpty) {
                          if (widget.existingMeal != null &&
                              widget.onDeleteMeal != null) {
                            widget.onDeleteMeal!();
                          }
                          Navigator.of(context).pop();
                          return;
                        }
                        final entry = MealEntry(
                          id: _mealId,
                          date: widget.selectedDate,
                          loggedAt: _loggedAtTime,
                          title: _mealTitle.isEmpty ? 'Pasto' : _mealTitle,
                          localPhotoPath: _localPhotoPath,
                          items: _items,
                        );
                        widget.onSaveMeal(entry);
                        Navigator.of(context).pop();
                      },
                icon: Icon(
                  _items.isEmpty && widget.existingMeal != null
                      ? Symbols.delete_rounded
                      : Symbols.check_rounded,
                ),
                label: Text(
                  _items.isEmpty && widget.existingMeal != null
                      ? 'Elimina pasto'
                      : 'Salva pasto ($_loggedAtTime)',
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  void _saveQuickEstimate(
    String title,
    int kcal,
    double proteinG,
    double carbsG,
    double fatG,
  ) {
    final item = MealItem(
      id: _uuid.v4(),
      mealId: _mealId,
      name: '$title (stima rapida)',
      grams: 100,
      kcalPer100g: kcal.toDouble(),
      proteinPer100g: proteinG,
      carbsPer100g: carbsG,
      fatPer100g: fatG,
      fiberPer100g: 4,
      source: MealItemSource.manual,
    );
    final entry = MealEntry(
      id: _mealId,
      date: widget.selectedDate,
      loggedAt: _loggedAtTime,
      title: title,
      items: [item],
    );
    widget.onSaveMeal(entry);
    Navigator.of(context).pop();
  }
}
