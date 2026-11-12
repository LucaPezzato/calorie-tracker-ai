import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../models/nutrition_models.dart';
import 'secure_keys_service.dart';

class AiMealAnalysisResult {
  final String mealTitle;
  final String? aiNotes;
  final List<MealItem> items;

  const AiMealAnalysisResult({
    required this.mealTitle,
    this.aiNotes,
    required this.items,
  });
}

class AiNutritionService {
  static const _uuid = Uuid();

  static const String _systemPrompt = '''
Sei un nutrizionista esperto italiano. Analizza il pasto descritto (o fotografato) e scomponilo nei singoli ingredienti.
Rispondi ESCLUSIVAMENTE con un oggetto JSON valido con questa struttura esatta:
{
  "meal_title": "Titolo sintetico del pasto in italiano",
  "ai_notes": "Breve nota su eventuali stime (es. olio di cottura)",
  "items": [
    {
      "name": "Nome ingrediente in italiano",
      "estimated_grams": 150.0,
      "per_100g": {
        "kcal": 165.0,
        "protein_g": 31.0,
        "carbs_g": 0.0,
        "fat_g": 3.6,
        "fiber_g": 0.0
      }
    }
  ]
}
Non aggiungere markdown o testo fuori dal JSON.
''';

  static const String _menuSystemPrompt = '''
Sei un nutrizionista e dietista clinico esperto.
Il tuo compito è analizzare i piatti di un menu di ristorante e consigliare all'utente le 3 scelte migliori per completare i suoi macro e calorie rimanenti per la giornata odierna.

Rispondi ESCLUSIVAMENTE con un oggetto JSON valido con questa struttura esatta:
{
  "restaurant_name": "Nome del ristorante (o 'Ristorante')",
  "summary_advice": "Breve strategia nutrizionale per questo pasto (es. 'Hai ancora 680 kcal e 45g di proteine: privilegia secondi magri e verdure')",
  "recommendations": [
    {
      "dish_name": "Nome esatto del piatto",
      "reasoning": "Spiegazione sintetica del perché è ideale rispetto a ciò che manca oggi (es. 'Apporta 38g di proteine colmando il tuo fabbisogno con pochi grassi')",
      "estimated_grams": 250,
      "estimated_kcal": 420,
      "estimated_protein_g": 38.0,
      "estimated_carbs_g": 12.0,
      "estimated_fat_g": 14.0,
      "estimated_fiber_g": 4.0,
      "is_top_pick": true,
      "caution_notes": "eventuale consiglio sui condimenti"
    }
  ],
  "dishes_to_avoid": [
    "Piatto sconsigliato 1 (troppo calorico o ricco di grassi saturi)",
    "Piatto sconsigliato 2"
  ]
}
Non aggiungere markdown o testo fuori dal JSON.
''';

  /// Analyze a meal from text and/or photo using either Google Gemini or OpenAI
  Future<AiMealAnalysisResult> analyzeMeal({
    required AiProviderType provider,
    required String modelName,
    required String apiKey,
    required String mealId,
    required String userPrompt,
    Uint8List? imageBytes,
  }) async {
    final rawJson = switch (provider) {
      AiProviderType.gemini => await _callGemini(
          modelName: modelName,
          apiKey: apiKey,
          prompt: userPrompt,
          imageBytes: imageBytes,
        ),
      AiProviderType.openai => await _callOpenAi(
          modelName: modelName,
          apiKey: apiKey,
          prompt: userPrompt,
          imageBytes: imageBytes,
        ),
    };

    return _parseStructuredResponse(
      rawJson,
      mealId: mealId,
      source:
          imageBytes != null ? MealItemSource.aiPhoto : MealItemSource.aiText,
    );
  }

  /// Conversational "Correggi con AI" refinement of an already analyzed meal
  Future<AiMealAnalysisResult> refineMealWithAi({
    required AiProviderType provider,
    required String modelName,
    required String apiKey,
    required String mealId,
    required AiMealAnalysisResult currentResult,
    required String correctionInstruction,
  }) async {
    final currentPayload = jsonEncode({
      'meal_title': currentResult.mealTitle,
      'items': currentResult.items
          .map(
            (i) => {
              'name': i.name,
              'estimated_grams': i.grams,
              'per_100g': {
                'kcal': i.kcalPer100g,
                'protein_g': i.proteinPer100g,
                'carbs_g': i.carbsPer100g,
                'fat_g': i.fatPer100g,
                'fiber_g': i.fiberPer100g,
              },
            },
          )
          .toList(),
    });

    final prompt =
        'Stato attuale del pasto JSON:\n$currentPayload\n\nApplica questa correzione richiesta dall\'utente e restituisci il nuovo JSON completo: "$correctionInstruction"';

    return analyzeMeal(
      provider: provider,
      modelName: modelName,
      apiKey: apiKey,
      mealId: mealId,
      userPrompt: prompt,
    );
  }

  /// Barcode lookup via OpenFoodFacts public API (Zero-cost)
  Future<MealItem?> lookupBarcodeOpenFoodFacts({
    required String barcode,
    required String mealId,
  }) async {
    final uri = Uri.parse(
      'https://world.openfoodfacts.org/api/v2/product/$barcode.json',
    );
    final response = await http.get(
      uri,
      headers: {'User-Agent': 'CalorieTrackerAI - Android - PersonalApp/1.0'},
    ).timeout(const Duration(seconds: 10));
    if (response.statusCode != 200) return null;

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (data['status'] != 1 || data['product'] == null) return null;

    final product = data['product'] as Map<String, dynamic>;
    final nutriments = product['nutriments'] as Map<String, dynamic>? ?? {};

    // Get brand + name for better identification
    final brand = (product['brands'] ?? '').toString().trim();
    final rawName = (product['product_name_it'] ??
            product['product_name'] ??
            product['generic_name_it'] ??
            product['generic_name'] ??
            'Prodotto $barcode')
        .toString()
        .trim();

    final name = (brand.isNotEmpty && !rawName.toLowerCase().contains(brand.toLowerCase()))
        ? '$brand - $rawName'
        : rawName;

    double numVal(List<String> keys) {
      for (final k in keys) {
        final val = nutriments[k];
        if (val is num && val > 0) return val.toDouble();
        if (val is String) {
          final parsed = double.tryParse(val.replaceAll(',', '.'));
          if (parsed != null && parsed > 0) return parsed;
        }
      }
      return 0.0;
    }

    // Try kcal first, fallback to kJ / 4.184
    double kcal = numVal([
      'energy-kcal_100g',
      'energy-kcal_value',
      'energy-kcal',
      'energy_kcal_100g',
    ]);
    if (kcal <= 0) {
      final kj = numVal(['energy_100g', 'energy-kj_100g', 'energy_value']);
      if (kj > 0) {
        kcal = (kj / 4.184).roundToDouble();
      }
    }

    final p = numVal(['proteins_100g', 'proteins_value', 'proteins']);
    final c = numVal(['carbohydrates_100g', 'carbohydrates_value', 'carbohydrates']);
    final g = numVal(['fat_100g', 'fat_value', 'fat']);
    final f = numVal(['fiber_100g', 'fiber_value', 'fiber']);

    // Detect serving quantity if present (e.g. 150g or 1 vasetto)
    double servingGrams = 100.0;
    final sq = product['serving_quantity'];
    if (sq is num && sq > 10 && sq < 1000) {
      servingGrams = sq.toDouble();
    } else if (product['serving_size'] != null) {
      final match = RegExp(r'(\d+[\.,]?\d*)\s*g', caseSensitive: false)
          .firstMatch(product['serving_size'].toString());
      if (match != null) {
        final parsed = double.tryParse(match.group(1)!.replaceAll(',', '.'));
        if (parsed != null && parsed > 10 && parsed < 1000) {
          servingGrams = parsed;
        }
      }
    }

    return MealItem(
      id: _uuid.v4(),
      mealId: mealId,
      name: name,
      grams: servingGrams,
      kcalPer100g: kcal,
      proteinPer100g: p,
      carbsPer100g: c,
      fatPer100g: g,
      fiberPer100g: f,
      source: MealItemSource.barcode,
      barcode: barcode,
    );
  }

  Future<String> _callGemini({
    required String modelName,
    required String apiKey,
    required String prompt,
    String? customSystemPrompt,
    Uint8List? imageBytes,
  }) async {
    final cleanKey = SecureKeysService.sanitizeKey(apiKey);
    final candidateModels = <String>{
      modelName,
      'gemini-2.5-flash',
      'gemini-2.0-flash',
      'gemini-flash-latest',
      'gemini-1.5-flash',
    }.toList();

    final sys = customSystemPrompt ?? _systemPrompt;
    final parts = <Map<String, dynamic>>[
      {'text': '$sys\n\nRichiesta utente:\n$prompt'},
    ];
    if (imageBytes != null) {
      parts.add({
        'inlineData': {
          'mimeType': 'image/jpeg',
          'data': base64Encode(imageBytes),
        },
      });
    }

    String lastError = 'Nessuna risposta da Gemini';
    for (final candidate in candidateModels) {
      final uri = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$candidate:generateContent?key=$cleanKey',
      );
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {'role': 'user', 'parts': parts},
          ],
          'generationConfig': {
            'temperature': 0.2,
            'responseMimeType': 'application/json',
          },
        }),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final candidates = decoded['candidates'] as List<dynamic>? ?? [];
        if (candidates.isEmpty) {
          throw Exception('Gemini non ha restituito candidati validi.');
        }
        final content =
            (candidates.first as Map<String, dynamic>)['content']
                as Map<String, dynamic>? ??
            {};
        final respParts = content['parts'] as List<dynamic>? ?? [];
        // Filter out Gemini 2.5 thinking parts ("thought": true) and join text parts
        final buffer = StringBuffer();
        for (final p in respParts) {
          if (p is Map<String, dynamic> && p['thought'] != true) {
            final t = p['text'];
            if (t is String) buffer.write(t);
          }
        }
        final text = buffer.toString().trim();
        if (text.isNotEmpty) return text;
      } else {
        // Parse Google API error message if present
        try {
          final errMap = jsonDecode(response.body) as Map<String, dynamic>;
          final errObj = errMap['error'] as Map<String, dynamic>?;
          lastError =
              errObj?['message']?.toString() ??
              'HTTP ${response.statusCode}';
        } catch (_) {
          lastError = 'HTTP ${response.statusCode}: ${response.body}';
        }
        // If API key itself is invalid (400 API_KEY_INVALID or 403), stop retrying models
        if (lastError.toLowerCase().contains('api key not valid') ||
            lastError.toLowerCase().contains('api_key_invalid')) {
          throw Exception('API Key Gemini non valida: controlla la chiave.');
        }
      }
    }

    throw Exception('Gemini: $lastError');
  }

  Future<String> _callOpenAi({
    required String modelName,
    required String apiKey,
    required String prompt,
    String? customSystemPrompt,
    Uint8List? imageBytes,
  }) async {
    final cleanKey = SecureKeysService.sanitizeKey(apiKey);
    final userContent = <Map<String, dynamic>>[
      {'type': 'text', 'text': prompt},
    ];
    if (imageBytes != null) {
      final b64 = base64Encode(imageBytes);
      userContent.add({
        'type': 'image_url',
        'image_url': {'url': 'data:image/jpeg;base64,$b64'},
      });
    }

    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: {
        'Authorization': 'Bearer $cleanKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'model': modelName,
        'response_format': {'type': 'json_object'},
        'temperature': 0.2,
        'messages': [
          {
            'role': 'system',
            'content': customSystemPrompt ?? _systemPrompt,
          },
          {'role': 'user', 'content': userContent},
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Errore OpenAI (${response.statusCode}): ${response.body}',
      );
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = decoded['choices'] as List<dynamic>;
    return (choices.first['message']['content'] as String?) ?? '{}';
  }

  /// Fetches clean text from a web URL (restaurant menu webpage, online menu)
  Future<String> fetchWebText(String url) async {
    try {
      final uri = Uri.parse(url);
      final res = await http.get(uri, headers: {
        'User-Agent':
            'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36 Mobile Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,text/plain;q=0.9',
      }).timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        String body = res.body;
        body = body
            .replaceAll(
              RegExp(r'<script[\s\S]*?</script>', caseSensitive: false),
              '',
            )
            .replaceAll(
              RegExp(r'<style[\s\S]*?</style>', caseSensitive: false),
              '',
            )
            .replaceAll(RegExp(r'<[^>]*>'), ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        if (body.length > 9000) {
          body = body.substring(0, 9000);
        }
        return body;
      }
    } catch (_) {}
    return '';
  }

  /// Analyze a restaurant menu (from Link, Text, or Photo) and recommend the best dishes
  /// matching the user's remaining calories and macronutrient gaps today
  Future<MenuAnalysisResult> analyzeMenuAndRecommend({
    required AiProviderType provider,
    required String modelName,
    required String apiKey,
    String? menuText,
    String? menuUrl,
    Uint8List? menuImageBytes,
    required int remainingKcal,
    required double remainingProteinG,
    required double remainingCarbsG,
    required double remainingFatG,
  }) async {
    String menuContent = menuText?.trim() ?? '';
    if (menuUrl != null && menuUrl.trim().isNotEmpty) {
      final webText = await fetchWebText(menuUrl.trim());
      if (webText.isNotEmpty) {
        menuContent =
            'URL Menu: $menuUrl\nContenuto estratto dalla pagina:\n$webText\n\n$menuContent';
      } else {
        menuContent = 'URL Menu: $menuUrl\n$menuContent';
      }
    }

    final promptBuffer = StringBuffer();
    promptBuffer.writeln(
      'BILANCIO NUTRIZIONALE RIMANENTE DI OGGI PER L\'UTENTE:',
    );
    promptBuffer.writeln('- Calorie rimanenti: $remainingKcal kcal');
    promptBuffer.writeln('- Proteine mancanti: ${remainingProteinG.round()} g');
    promptBuffer.writeln('- Carboidrati mancanti: ${remainingCarbsG.round()} g');
    promptBuffer.writeln('- Grassi rimanenti: ${remainingFatG.round()} g');
    promptBuffer.writeln('\nMENU DEL RISTORANTE DA ANALIZZARE:\n');
    promptBuffer.writeln(
      menuContent.isNotEmpty
          ? menuContent
          : 'Vedi immagine del menu allegata.',
    );

    final rawJson = switch (provider) {
      AiProviderType.gemini => await _callGemini(
          modelName: modelName,
          apiKey: apiKey,
          prompt: promptBuffer.toString(),
          customSystemPrompt: _menuSystemPrompt,
          imageBytes: menuImageBytes,
        ),
      AiProviderType.openai => await _callOpenAi(
          modelName: modelName,
          apiKey: apiKey,
          prompt: promptBuffer.toString(),
          customSystemPrompt: _menuSystemPrompt,
          imageBytes: menuImageBytes,
        ),
    };

    return _parseMenuResponse(rawJson);
  }

  MenuAnalysisResult _parseMenuResponse(String rawJson) {
    String cleaned = rawJson
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();
    final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(cleaned);
    if (jsonMatch != null) {
      cleaned = jsonMatch.group(0)!;
    }
    final map = jsonDecode(cleaned) as Map<String, dynamic>;
    final rawRecs = (map['recommendations'] as List<dynamic>? ?? []);
    final recs = rawRecs.map((e) {
      final m = e as Map<String, dynamic>;
      return MenuDishRecommendation(
        dishName: (m['dish_name'] ?? 'Piatto consigliato').toString(),
        reasoning: (m['reasoning'] ?? '').toString(),
        estimatedGrams: (m['estimated_grams'] as num?)?.toInt() ?? 250,
        estimatedKcal: (m['estimated_kcal'] as num?)?.toInt() ?? 350,
        estimatedProteinG:
            (m['estimated_protein_g'] as num?)?.toDouble() ?? 30.0,
        estimatedCarbsG: (m['estimated_carbs_g'] as num?)?.toDouble() ?? 20.0,
        estimatedFatG: (m['estimated_fat_g'] as num?)?.toDouble() ?? 10.0,
        estimatedFiberG: (m['estimated_fiber_g'] as num?)?.toDouble() ?? 0.0,
        isTopPick: (m['is_top_pick'] as bool?) ?? false,
        cautionNotes: m['caution_notes'] as String?,
      );
    }).toList();

    final avoids = (map['dishes_to_avoid'] as List<dynamic>? ?? [])
        .map((e) => e.toString())
        .toList();

    return MenuAnalysisResult(
      restaurantName: (map['restaurant_name'] ?? 'Menu Ristorante').toString(),
      summaryAdvice: (map['summary_advice'] ??
              'Ecco le migliori opzioni per completare i tuoi macro di oggi.')
          .toString(),
      recommendations: recs,
      dishesToAvoid: avoids,
    );
  }

  AiMealAnalysisResult _parseStructuredResponse(
    String rawJson, {
    required String mealId,
    required MealItemSource source,
  }) {
    String cleaned = rawJson
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();
    final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(cleaned);
    if (jsonMatch != null) {
      cleaned = jsonMatch.group(0)!;
    }
    final map = jsonDecode(cleaned) as Map<String, dynamic>;
    final rawItems = (map['items'] as List<dynamic>? ?? []);

    final items = rawItems.map((e) {
      final itemMap = e as Map<String, dynamic>;
      final per100 =
          itemMap['per_100g'] as Map<String, dynamic>? ?? <String, dynamic>{};
      return MealItem(
        id: _uuid.v4(),
        mealId: mealId,
        name: (itemMap['name'] ?? 'Alimento').toString(),
        grams: (itemMap['estimated_grams'] as num?)?.toDouble() ?? 100.0,
        kcalPer100g: (per100['kcal'] as num?)?.toDouble() ?? 0.0,
        proteinPer100g: (per100['protein_g'] as num?)?.toDouble() ?? 0.0,
        carbsPer100g: (per100['carbs_g'] as num?)?.toDouble() ?? 0.0,
        fatPer100g: (per100['fat_g'] as num?)?.toDouble() ?? 0.0,
        fiberPer100g: (per100['fiber_g'] as num?)?.toDouble() ?? 0.0,
        source: source,
      );
    }).toList();

    return AiMealAnalysisResult(
      mealTitle: (map['meal_title'] ?? 'Pasto').toString(),
      aiNotes: map['ai_notes'] as String?,
      items: items,
    );
  }

  /// Generates an end-of-day AI nutritional summary & coaching report
  Future<DailyAiSummary> generateDailySummary({
    required AiProviderType provider,
    required String modelName,
    required String apiKey,
    required String date,
    required UserProfile profile,
    required List<MealEntry> meals,
    required DailyMetrics metrics,
  }) async {
    final totalKcal = meals.fold(0, (s, m) => s + m.totalKcal);
    final totalP = meals.fold(0.0, (s, m) => s + m.totalProteinG).round();
    final totalC = meals.fold(0.0, (s, m) => s + m.totalCarbsG).round();
    final totalG = meals.fold(0.0, (s, m) => s + m.totalFatG).round();
    final totalFiber = meals.fold(0.0, (s, m) => s + m.totalFiberG).round();

    final mealsSummary = meals.isEmpty
        ? 'Nessun pasto registrato.'
        : meals
            .map((m) =>
                '- ${m.loggedAt} ${m.title}: ${m.totalKcal} kcal (P:${m.totalProteinG.round()}g C:${m.totalCarbsG.round()}g G:${m.totalFatG.round()}g)')
            .join('\n');

    const customSys = '''
Sei un nutrizionista sportivo AI. Analizza la giornata alimentare dell'utente in italiano in modo costruttivo, preciso e conciso.
Rispondi ESCLUSIVAMENTE con un JSON valido con questo schema esatto:
{
  "score": 8.5,
  "headline": "Titolo breve (max 60 caratteri)",
  "verdict": "Riassunto di 1-2 frasi sul bilancio calorico e macro della giornata.",
  "strengths": ["Punto di forza 1", "Punto di forza 2"],
  "warnings": ["Eventuale criticità o carenza 1"],
  "advice_tomorrow": "Un consiglio pratico e concreto per domani."
}
''';

    final prompt = '''
Data: $date
Obiettivo utente: ${profile.goalType.name}
Target giornaliero: ${profile.targetKcal} kcal | P: ${profile.targetProteinG.round()}g | C: ${profile.targetCarbsG.round()}g | G: ${profile.targetFatG.round()}g | Fibre: ${profile.targetFiberG.round()}g | Acqua: ${profile.targetWaterMl} ml

Consumo effettivo di oggi:
- Calorie totali: $totalKcal kcal
- Proteine: ${totalP}g | Carboidrati: ${totalC}g | Grassi: ${totalG}g | Fibre: ${totalFiber}g
- Acqua bevuta: ${metrics.waterMl} ml
- Caffè: ${metrics.coffeeCups} tazzine
${metrics.weightKg != null ? '- Peso registrato: ${metrics.weightKg!.toStringAsFixed(1)} kg' : ''}

Pasti registrati:
$mealsSummary
''';

    final rawJson = switch (provider) {
      AiProviderType.gemini => await _callGemini(
          modelName: modelName,
          apiKey: apiKey,
          prompt: prompt,
          customSystemPrompt: customSys,
        ),
      AiProviderType.openai => await _callOpenAi(
          modelName: modelName,
          apiKey: apiKey,
          prompt: prompt,
          customSystemPrompt: customSys,
        ),
    };

    String cleaned = rawJson
        .replaceAll('```json', '')
        .replaceAll('```', '')
        .trim();
    final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(cleaned);
    if (jsonMatch != null) {
      cleaned = jsonMatch.group(0)!;
    }
    final map = jsonDecode(cleaned) as Map<String, dynamic>;

    List<String> toStrList(dynamic v) {
      if (v is List) return v.map((e) => e.toString()).toList();
      return const [];
    }

    return DailyAiSummary(
      date: date,
      score: ((map['score'] as num?) ?? 7.5).toDouble().clamp(1.0, 10.0),
      headline: (map['headline'] ?? 'Resoconto giornata').toString(),
      verdict: (map['verdict'] ?? '').toString(),
      strengths: toStrList(map['strengths']),
      warnings: toStrList(map['warnings']),
      adviceTomorrow: (map['advice_tomorrow'] ?? '').toString(),
      createdAt: DateTime.now().toIso8601String(),
    );
  }
}
