import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/nutrition_models.dart';
import '../services/ai_nutrition_service.dart';
import '../theme/app_theme.dart';
import '../theme/nutrient_colors.dart';

class BarcodeScannerDialog extends StatefulWidget {
  final String mealId;

  const BarcodeScannerDialog({super.key, required this.mealId});

  @override
  State<BarcodeScannerDialog> createState() => _BarcodeScannerDialogState();
}

class _BarcodeScannerDialogState extends State<BarcodeScannerDialog> {
  final AiNutritionService _aiService = AiNutritionService();
  final ImagePicker _picker = ImagePicker();

  final TextEditingController _manualEanCtrl = TextEditingController(
    text: '5201054017415', // Fage Total 0% default test EAN
  );
  late final TextEditingController _gramsCtrl;
  late final MobileScannerController _cameraController;

  bool _isLoading = false;
  String? _errorMsg;
  MealItem? _foundProduct;
  double _grams = 100.0;
  double _standardServing = 100.0;
  bool _hasScanned = false;
  bool _torchOn = false;

  @override
  void initState() {
    super.initState();
    _gramsCtrl = TextEditingController(text: '100');
    // autoStart: false prevents duplicate initialization crash in Dialogs
    _cameraController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      facing: CameraFacing.back,
      torchEnabled: false,
      autoStart: false,
    );

    // Explicit single start after frame is mounted with automatic front/back fallback
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        if (mounted) {
          await _cameraController.start();
        }
      } catch (_) {
        try {
          if (mounted) {
            await _cameraController.switchCamera();
          }
        } catch (_) {}
      }
    });
  }

  @override
  void dispose() {
    _manualEanCtrl.dispose();
    _gramsCtrl.dispose();
    _cameraController.dispose();
    super.dispose();
  }

  void _updateGrams(double grams) {
    final clamped = grams.clamp(5.0, 1000.0);
    setState(() {
      _grams = clamped;
      _gramsCtrl.text = clamped.round().toString();
    });
  }

  Future<void> _lookupBarcode(String code) async {
    final cleaned = code.trim();
    if (_isLoading || cleaned.isEmpty) return;
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final item = await _aiService.lookupBarcodeOpenFoodFacts(
        barcode: cleaned,
        mealId: widget.mealId,
      );
      if (!mounted) return;
      setState(() {
        _foundProduct = item;
        if (item == null) {
          _errorMsg = 'Prodotto ($cleaned) non trovato su OpenFoodFacts.';
          _cameraController.start();
          _hasScanned = false;
        } else {
          _standardServing = item.grams > 10 ? item.grams : 100.0;
          _grams = _standardServing;
          _gramsCtrl.text = _grams.round().toString();
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMsg = 'Errore di rete durante la ricerca del codice $cleaned.';
        _cameraController.start();
        _hasScanned = false;
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _pickAndScanImage() async {
    try {
      final xfile = await _picker.pickImage(source: ImageSource.gallery);
      if (xfile == null) return;

      setState(() => _isLoading = true);
      final capture = await _cameraController.analyzeImage(xfile.path);
      if (capture != null && capture.barcodes.isNotEmpty) {
        final raw = capture.barcodes.first.rawValue;
        if (raw != null && raw.trim().isNotEmpty) {
          _manualEanCtrl.text = raw.trim();
          await _lookupBarcode(raw.trim());
          return;
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nessun codice a barre leggibile trovato nell\'immagine.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore lettura immagine: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _resetScanner() {
    setState(() {
      _foundProduct = null;
      _hasScanned = false;
      _errorMsg = null;
    });
    _cameraController.start();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final nutrients = context.nutrients;

    final currentKcal = _foundProduct != null
        ? ((_grams / 100.0) * _foundProduct!.kcalPer100g).round()
        : 0;
    final currentP = _foundProduct != null
        ? ((_grams / 100.0) * _foundProduct!.proteinPer100g)
        : 0.0;
    final currentC = _foundProduct != null
        ? ((_grams / 100.0) * _foundProduct!.carbsPer100g)
        : 0.0;
    final currentG = _foundProduct != null
        ? ((_grams / 100.0) * _foundProduct!.fatPer100g)
        : 0.0;
    final currentF = _foundProduct != null
        ? ((_grams / 100.0) * _foundProduct!.fiberPer100g)
        : 0.0;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusSheet),
      ),
      backgroundColor: cs.surfaceContainerLow,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 680),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'Scanner Barcode',
                      style: tt.titleLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Symbols.close_rounded),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Camera Viewfinder (if no product selected yet)
              if (_foundProduct == null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                  child: SizedBox(
                    height: 185,
                    width: double.infinity,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        MobileScanner(
                          controller: _cameraController,
                          errorBuilder: (context, error, child) {
                            // If controller was already started, not a fatal error
                            if (error.errorCode ==
                                MobileScannerErrorCode.controllerAlreadyInitialized) {
                              return const SizedBox.shrink();
                            }

                            final isPerm = error.errorCode ==
                                MobileScannerErrorCode.permissionDenied;
                            final errText = isPerm
                                ? 'Permesso fotocamera negato. Concedi il permesso nelle Impostazioni dell\'app o scansiona da foto/manuale.'
                                : 'Fotocamera: ${error.errorDetails?.message ?? error.errorCode.message}';

                            return Container(
                              color: cs.surfaceDim,
                              padding: const EdgeInsets.all(12),
                              alignment: Alignment.center,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isPerm
                                        ? Symbols.no_photography_rounded
                                        : Symbols.videocam_off_rounded,
                                    size: 30,
                                    color: cs.error,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    errText,
                                    textAlign: TextAlign.center,
                                    style: tt.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 6,
                                    alignment: WrapAlignment.center,
                                    children: [
                                      FilledButton.tonal(
                                        style: FilledButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        onPressed: () async {
                                          try {
                                            await _cameraController.stop();
                                            await _cameraController.start();
                                            if (mounted) setState(() {});
                                          } catch (_) {}
                                        },
                                        child: const Text('Riprova'),
                                      ),
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          visualDensity: VisualDensity.compact,
                                        ),
                                        icon: const Icon(
                                          Symbols.image_rounded,
                                          size: 16,
                                        ),
                                        label: const Text('Da Foto'),
                                        onPressed: _pickAndScanImage,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                          onDetect: (capture) {
                            if (_hasScanned || _isLoading) return;
                            final barcodes = capture.barcodes;
                            for (final b in barcodes) {
                              final raw = b.rawValue;
                              if (raw != null && raw.trim().isNotEmpty) {
                                _hasScanned = true;
                                _cameraController.stop();
                                _manualEanCtrl.text = raw.trim();
                                _lookupBarcode(raw.trim());
                                break;
                              }
                            }
                          },
                        ),

                        // Target scan line
                        IgnorePointer(
                          child: Container(
                            height: 2,
                            margin: const EdgeInsets.symmetric(horizontal: 24),
                            color: nutrients.protein,
                          ),
                        ),

                        // Camera controls overlay (Torch + Switch + Gallery)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton.filledTonal(
                                visualDensity: VisualDensity.compact,
                                icon: Icon(
                                  _torchOn
                                      ? Symbols.flash_on_rounded
                                      : Symbols.flash_off_rounded,
                                  size: 17,
                                ),
                                onPressed: () async {
                                  await _cameraController.toggleTorch();
                                  setState(() => _torchOn = !_torchOn);
                                },
                              ),
                              const SizedBox(width: 5),
                              IconButton.filledTonal(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(
                                  Symbols.flip_camera_android_rounded,
                                  size: 17,
                                ),
                                onPressed: () =>
                                    _cameraController.switchCamera(),
                              ),
                              const SizedBox(width: 5),
                              IconButton.filledTonal(
                                visualDensity: VisualDensity.compact,
                                tooltip: 'Scansiona da immagine in galleria',
                                icon: const Icon(Symbols.image_rounded, size: 17),
                                onPressed: _pickAndScanImage,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Manual EAN Input
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _manualEanCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: cs.surfaceDim,
                          labelText: 'Codice EAN-13 / EAN-8 manuale',
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusSmall,
                            ),
                          ),
                        ),
                        onSubmitted: (v) => _lookupBarcode(v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.tonal(
                      onPressed: _isLoading
                          ? null
                          : () => _lookupBarcode(_manualEanCtrl.text),
                      child: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Cerca'),
                    ),
                  ],
                ),
              ],

              if (_errorMsg != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cs.errorContainer,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Row(
                    children: [
                      Icon(Symbols.error_rounded, color: cs.onErrorContainer, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMsg!,
                          style: tt.bodySmall?.copyWith(
                            color: cs.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // PRODUCT FOUND & SERVING CUSTOMIZER
              if (_foundProduct != null) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product Title + EAN
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _foundProduct!.name,
                                  style: tt.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (_foundProduct!.barcode != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'EAN: ${_foundProduct!.barcode}',
                                    style: tt.labelSmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                            ),
                            icon: const Icon(Symbols.refresh_rounded, size: 16),
                            label: const Text('Altro'),
                            onPressed: _resetScanner,
                          ),
                        ],
                      ),
                      const Divider(height: 18),

                      // Grams Editor & Quick Portions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Porzione mangiata:',
                            style: tt.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          // Direct Grams Input Field
                          SizedBox(
                            width: 100,
                            height: 38,
                            child: TextField(
                              controller: _gramsCtrl,
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: false,
                              ),
                              textAlign: TextAlign.center,
                              decoration: InputDecoration(
                                contentPadding: EdgeInsets.zero,
                                suffixText: 'g ',
                                suffixStyle: tt.labelMedium?.copyWith(
                                  color: cs.primary,
                                ),
                                filled: true,
                                fillColor: cs.surfaceDim,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onChanged: (val) {
                                final parsed = double.tryParse(val);
                                if (parsed != null && parsed > 0) {
                                  setState(() => _grams = parsed);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Quick Portion Pills: ½ porzione, 100g, 1 porzione, 2×
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          ActionChip(
                            avatar: const Icon(Symbols.pie_chart_rounded, size: 15),
                            label: Text(
                              '½ porzione (${(_standardServing / 2).round()}g)',
                            ),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _updateGrams(_standardServing / 2),
                          ),
                          ActionChip(
                            label: const Text('100g'),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _updateGrams(100),
                          ),
                          ActionChip(
                            label: Text('1 porz. (${_standardServing.round()}g)'),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _updateGrams(_standardServing),
                          ),
                          ActionChip(
                            label: Text('2× (${(_standardServing * 2).round()}g)'),
                            visualDensity: VisualDensity.compact,
                            onPressed: () => _updateGrams(_standardServing * 2),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Continuous Grams Slider
                      Slider(
                        value: _grams.clamp(5.0, 500.0),
                        min: 5,
                        max: 500,
                        divisions: 99,
                        onChanged: (val) => _updateGrams(val),
                      ),

                      // Real-time Macro Pill Row
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: cs.surfaceDim,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusSmall,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '$currentKcal kcal',
                              style: tt.titleMedium?.copyWith(
                                color: cs.primary,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                            Text(
                              'P: ${currentP.toStringAsFixed(1)}g',
                              style: tt.labelSmall?.copyWith(
                                color: nutrients.protein,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                            Text(
                              'C: ${currentC.toStringAsFixed(1)}g',
                              style: tt.labelSmall?.copyWith(
                                color: nutrients.carbs,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                            Text(
                              'G: ${currentG.toStringAsFixed(1)}g',
                              style: tt.labelSmall?.copyWith(
                                color: nutrients.fat,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                            Text(
                              'F: ${currentF.toStringAsFixed(1)}g',
                              style: tt.labelSmall?.copyWith(
                                color: nutrients.fiber,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Confirm Button
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(48),
                          shape: const StadiumBorder(),
                        ),
                        onPressed: () {
                          final configuredItem = _foundProduct!.copyWith(
                            grams: _grams,
                          );
                          Navigator.of(context).pop(configuredItem);
                        },
                        icon: const Icon(Symbols.check_rounded),
                        label: Text(
                          'Aggiungi al pasto (${_grams.round()}g • $currentKcal kcal)',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
