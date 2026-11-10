import 'package:flutter/material.dart';
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
  final TextEditingController _manualEanCtrl = TextEditingController(
    text: '5201054017415', // Fage Total 0% default test EAN
  );

  bool _isLoading = false;
  String? _errorMsg;
  MealItem? _foundProduct;
  bool _hasScanned = false;

  @override
  void dispose() {
    _manualEanCtrl.dispose();
    super.dispose();
  }

  Future<void> _lookupBarcode(String code) async {
    if (_isLoading || code.trim().isEmpty) return;
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final item = await _aiService.lookupBarcodeOpenFoodFacts(
        barcode: code.trim(),
        mealId: widget.mealId,
      );
      if (!mounted) return;
      setState(() {
        _foundProduct = item;
        if (item == null) {
          _errorMsg = 'Prodotto ($code) non trovato su OpenFoodFacts.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMsg = 'Errore di rete durante la ricerca del codice $code.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final nutrients = context.nutrients;

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusHero),
      ),
      backgroundColor: cs.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Scanner Barcode (OpenFoodFacts)', style: tt.titleLarge),
                IconButton(
                  icon: const Icon(Symbols.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Live Camera Viewfinder Cutout
            ClipRRect(
              borderRadius: BorderRadius.circular(AppTheme.radiusCard),
              child: SizedBox(
                height: 190,
                width: double.infinity,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    MobileScanner(
                      onDetect: (capture) {
                        if (_hasScanned) return;
                        final barcodes = capture.barcodes;
                        if (barcodes.isNotEmpty &&
                            barcodes.first.rawValue != null) {
                          _hasScanned = true;
                          final raw = barcodes.first.rawValue!;
                          _manualEanCtrl.text = raw;
                          _lookupBarcode(raw);
                        }
                      },
                    ),
                    Container(
                      height: 2,
                      margin: const EdgeInsets.symmetric(horizontal: 28),
                      color: nutrients.protein,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Manual / Emulator EAN-13 Input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _manualEanCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: cs.surfaceDim,
                      labelText: 'Codice EAN-13 / EAN-8 (test emulatore)',
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusSmall,
                        ),
                      ),
                    ),
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

            if (_errorMsg != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorMsg!,
                style: tt.bodyMedium?.copyWith(color: cs.error),
              ),
            ],

            if (_foundProduct != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                  border: Border.all(color: cs.primary),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_foundProduct!.name, style: tt.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      'Valori per 100g: ${_foundProduct!.kcal} kcal  •  '
                      'P: ${_foundProduct!.proteinPer100g.toStringAsFixed(1)}g  '
                      'C: ${_foundProduct!.carbsPer100g.toStringAsFixed(1)}g  '
                      'G: ${_foundProduct!.fatPer100g.toStringAsFixed(1)}g',
                      style: tt.labelSmall?.copyWith(color: cs.primary),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        shape: const StadiumBorder(),
                      ),
                      onPressed: () =>
                          Navigator.of(context).pop(_foundProduct),
                      icon: const Icon(Symbols.add_rounded),
                      label: const Text('Usa questo alimento'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
