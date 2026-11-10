import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../models/nutrition_models.dart';
import '../services/ai_nutrition_service.dart';
import '../services/drive_backup_service.dart';
import '../services/secure_keys_service.dart';
import '../theme/app_theme.dart';
import '../theme/nutrient_colors.dart';

class ProfileScreen extends StatefulWidget {
  final UserProfile profile;
  final DriveBackupService driveService;
  final ValueChanged<UserProfile> onProfileChanged;

  const ProfileScreen({
    super.key,
    required this.profile,
    required this.driveService,
    required this.onProfileChanged,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final SecureKeysService _keysService = SecureKeysService();
  final AiNutritionService _aiService = AiNutritionService();

  late AiProviderType _provider;
  late GoalType _goalType;
  late bool _autoBackup;
  late bool _manualOverride;
  String? _maskedKey;
  String? _aiTestStatus;
  bool _isTestingAi = false;

  @override
  void initState() {
    super.initState();
    _provider = widget.profile.preferredAiProvider;
    _goalType = widget.profile.goalType;
    _autoBackup = widget.profile.autoBackupEnabled;
    _manualOverride = widget.profile.isManualOverride;
    _loadStoredKey();
  }

  Future<void> _loadStoredKey() async {
    final key = await _keysService.getApiKey(_provider);
    if (!mounted) return;
    setState(() {
      if (key == null || key.isEmpty) {
        _maskedKey = null;
      } else {
        final suffix = key.length > 4 ? key.substring(key.length - 4) : key;
        _maskedKey = '••••••••••••••••••••$suffix';
      }
    });
  }

  void _recalculateGuided({
    String? sex,
    int? birthYear,
    double? heightCm,
    double? weightKg,
    double? activityMultiplier,
    GoalType? newGoal,
  }) {
    final g = newGoal ?? _goalType;
    setState(() {
      _goalType = g;
      _manualOverride = false;
    });
    final updated = UserProfile.calculateGuided(
      sex: sex ?? widget.profile.sex,
      birthYear: birthYear ?? widget.profile.birthYear,
      heightCm: heightCm ?? widget.profile.heightCm,
      weightKg: weightKg ?? widget.profile.currentWeightKg,
      activityMultiplier:
          activityMultiplier ?? widget.profile.activityMultiplier,
      goalType: g,
      preferredAiProvider: _provider,
      preferredAiModel: _provider == AiProviderType.gemini
          ? 'gemini-2.5-flash'
          : 'gpt-4o-mini',
      autoBackupEnabled: _autoBackup,
    );
    widget.onProfileChanged(updated);
  }

  Future<void> _openPhysicalDataDialog() async {
    final p = widget.profile;
    String sex = p.sex;
    final yearCtrl = TextEditingController(text: '${p.birthYear}');
    final heightCtrl = TextEditingController(text: '${p.heightCm.round()}');
    final weightCtrl = TextEditingController(
      text: p.currentWeightKg.toStringAsFixed(1),
    );
    double activity = p.activityMultiplier;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Dati Fisici (Formula Mifflin-St Jeor)'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'M', label: Text('Uomo')),
                    ButtonSegment(value: 'F', label: Text('Donna')),
                  ],
                  selected: {sex},
                  onSelectionChanged: (s) =>
                      setDialogState(() => sex = s.first),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: yearCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Anno di nascita',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: heightCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Altezza (cm)'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: weightCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Peso attuale (kg)',
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<double>(
                  initialValue: activity,
                  decoration: const InputDecoration(
                    labelText: 'Livello Attività',
                  ),
                  items: const [
                    DropdownMenuItem(value: 1.2, child: Text('Sedentario')),
                    DropdownMenuItem(value: 1.375, child: Text('Leggero')),
                    DropdownMenuItem(value: 1.55, child: Text('Moderato')),
                    DropdownMenuItem(value: 1.725, child: Text('Intenso')),
                  ],
                  onChanged: (v) =>
                      setDialogState(() => activity = v ?? 1.55),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () {
                _recalculateGuided(
                  sex: sex,
                  birthYear: int.tryParse(yearCtrl.text) ?? p.birthYear,
                  heightCm: double.tryParse(heightCtrl.text) ?? p.heightCm,
                  weightKg:
                      double.tryParse(
                        weightCtrl.text.replaceAll(',', '.'),
                      ) ??
                      p.currentWeightKg,
                  activityMultiplier: activity,
                );
                Navigator.pop(ctx);
              },
              child: const Text('Ricalcola TDEE'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openManualTargetsDialog() async {
    final p = widget.profile;
    final kcalCtrl = TextEditingController(text: '${p.targetKcal}');
    final proCtrl = TextEditingController(text: '${p.targetProteinG.round()}');
    final carbCtrl = TextEditingController(text: '${p.targetCarbsG.round()}');
    final fatCtrl = TextEditingController(text: '${p.targetFatG.round()}');
    final fibCtrl = TextEditingController(text: '${p.targetFiberG.round()}');
    final watCtrl = TextEditingController(text: '${p.targetWaterMl}');

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Personalizza Target Giornalieri'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: kcalCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Calorie Target (kcal)',
                ),
              ),
              TextField(
                controller: proCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Proteine (g)'),
              ),
              TextField(
                controller: carbCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Carboidrati (g)'),
              ),
              TextField(
                controller: fatCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Grassi (g)'),
              ),
              TextField(
                controller: fibCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Fibre (g)'),
              ),
              TextField(
                controller: watCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Acqua (ml)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () {
              setState(() => _manualOverride = true);
              widget.onProfileChanged(
                UserProfile(
                  sex: p.sex,
                  birthYear: p.birthYear,
                  heightCm: p.heightCm,
                  currentWeightKg: p.currentWeightKg,
                  activityMultiplier: p.activityMultiplier,
                  goalType: p.goalType,
                  isManualOverride: true,
                  targetKcal: int.tryParse(kcalCtrl.text) ?? p.targetKcal,
                  targetProteinG:
                      double.tryParse(proCtrl.text) ?? p.targetProteinG,
                  targetCarbsG:
                      double.tryParse(carbCtrl.text) ?? p.targetCarbsG,
                  targetFatG: double.tryParse(fatCtrl.text) ?? p.targetFatG,
                  targetFiberG:
                      double.tryParse(fibCtrl.text) ?? p.targetFiberG,
                  targetWaterMl: int.tryParse(watCtrl.text) ?? p.targetWaterMl,
                  preferredAiProvider: _provider,
                  preferredAiModel: p.preferredAiModel,
                  autoBackupEnabled: _autoBackup,
                ),
              );
              Navigator.pop(ctx);
            },
            child: const Text('Salva Target'),
          ),
        ],
      ),
    );
  }

  Future<void> _openApiKeyDialog() async {
    final ctrl = TextEditingController();
    final provName = _provider == AiProviderType.gemini
        ? 'Google Gemini'
        : 'OpenAI';
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Configura API Key $provName'),
        content: TextField(
          controller: ctrl,
          obscureText: true,
          decoration: InputDecoration(
            hintText: _provider == AiProviderType.gemini
                ? 'AIzaSy...'
                : 'sk-proj-...',
            helperText: 'Salvata cifrata in Android Keystore',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () async {
              await _keysService.saveApiKey(_provider, ctrl.text);
              await _loadStoredKey();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Salva in Keystore'),
          ),
        ],
      ),
    );
  }

  Future<void> _testAiConnection() async {
    final key = await _keysService.getApiKey(_provider);
    if (key == null || key.isEmpty) {
      await _openApiKeyDialog();
      return;
    }

    setState(() {
      _isTestingAi = true;
      _aiTestStatus = null;
    });

    final sw = Stopwatch()..start();
    try {
      await _aiService.analyzeMeal(
        provider: _provider,
        modelName: _provider == AiProviderType.gemini
            ? 'gemini-2.5-flash'
            : 'gpt-4o-mini',
        apiKey: key,
        mealId: 'test',
        userPrompt: '1 mela rossa media (150g)',
      );
      sw.stop();
      if (!mounted) return;
      setState(() {
        _aiTestStatus = '✓ Connessione OK (${sw.elapsedMilliseconds} ms)';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _aiTestStatus = 'Errore: verifica la API Key inserita';
      });
    } finally {
      if (mounted) setState(() => _isTestingAi = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final nutrients = context.nutrients;
    final p = widget.profile;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // 1. GOOGLE SIGN-IN & GOOGLE DRIVE AUTO-BACKUP CARD
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusCard),
            side: BorderSide(color: cs.primary, width: 1.2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () async {
                    await widget.driveService.signInInteractive();
                    setState(() {});
                  },
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: cs.primary,
                        foregroundColor: cs.onPrimary,
                        child: Text('PZ', style: tt.titleMedium),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.driveService.currentUser?.email ??
                                  'Tocca per accedere con Google',
                              style: tt.titleMedium,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '☁️ Google Drive (appDataFolder) • Solo DB SQLite',
                              style: tt.labelSmall?.copyWith(color: cs.primary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Backup automatico ad ogni modifica',
                    style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Le foto restano solo nella cache del telefono',
                    style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  value: _autoBackup,
                  onChanged: (v) => setState(() => _autoBackup = v),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () async {
                          await widget.driveService.backupNow();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Backup SQLite su Google Drive completato!',
                                ),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Symbols.cloud_upload_rounded, size: 18),
                        label: const Text('Backup Ora'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await widget.driveService.restoreFromDrive();
                        },
                        icon: const Icon(
                          Symbols.cloud_download_rounded,
                          size: 18,
                        ),
                        label: const Text('Ripristina DB'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 2. MULTI-PROVIDER AI ENGINE CARD (GEMINI + OPENAI)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Motore AI Multi-Provider', style: tt.titleLarge),
                const SizedBox(height: 10),
                SegmentedButton<AiProviderType>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: AiProviderType.gemini,
                      label: Text('✨ Google Gemini'),
                    ),
                    ButtonSegment(
                      value: AiProviderType.openai,
                      label: Text('🧠 OpenAI GPT'),
                    ),
                  ],
                  selected: {_provider},
                  onSelectionChanged: (s) {
                    setState(() {
                      _provider = s.first;
                      _aiTestStatus = null;
                    });
                    _loadStoredKey();
                  },
                ),
                const SizedBox(height: 12),
                InkWell(
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  onTap: _openApiKeyDialog,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.surfaceDim,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      border: Border.all(
                        color: cs.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _maskedKey ?? 'Tocca per inserire API Key...',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: tt.labelMedium?.copyWith(color: cs.primary),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Symbols.key_rounded, size: 18, color: cs.primary),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isTestingAi ? null : _testAiConnection,
                    icon: const Icon(Symbols.bolt_rounded, size: 18),
                    label: Text(
                      _aiTestStatus ?? 'Testa Connessione AI',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 3. GUIDED TDEE & MACRO TARGETS + MANUAL OVERRIDE
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
                        'Obiettivi (TDEE)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.titleLarge,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _openPhysicalDataDialog,
                      icon: const Icon(Symbols.edit_rounded, size: 16),
                      label: const Text('Dati Fisici'),
                    ),
                  ],
                ),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: cs.surfaceDim,
                    borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  ),
                  child: Text(
                    '${p.sex == 'M' ? 'Uomo' : 'Donna'} • ${DateTime.now().year - p.birthYear}a • ${p.heightCm.round()} cm • ${p.currentWeightKg.toStringAsFixed(1)} kg',
                    style: tt.labelMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<GoalType>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                        value: GoalType.deficit,
                        label: Text('Deficit'),
                      ),
                      ButtonSegment(
                        value: GoalType.maintain,
                        label: Text('Mantieni'),
                      ),
                      ButtonSegment(
                        value: GoalType.surplus,
                        label: Text('Surplus'),
                      ),
                    ],
                    selected: {_goalType},
                    onSelectionChanged: (s) =>
                        _recalculateGuided(newGoal: s.first),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Personalizza target manualmente',
                    style: tt.bodyMedium,
                  ),
                  value: _manualOverride,
                  onChanged: (v) {
                    if (v) {
                      _openManualTargetsDialog();
                    } else {
                      _recalculateGuided();
                    }
                  },
                ),
                const SizedBox(height: 6),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final tileWidth = (constraints.maxWidth - 10) / 2;
                    return InkWell(
                      onTap: _openManualTargetsDialog,
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _TargetTile(
                            width: tileWidth,
                            label: 'CALORIE',
                            value: '${p.targetKcal} kcal',
                            color: cs.primary,
                          ),
                          _TargetTile(
                            width: tileWidth,
                            label: 'PROTEINE',
                            value: '${p.targetProteinG.round()} g',
                            color: nutrients.protein,
                          ),
                          _TargetTile(
                            width: tileWidth,
                            label: 'CARBOIDRATI',
                            value: '${p.targetCarbsG.round()} g',
                            color: nutrients.carbs,
                          ),
                          _TargetTile(
                            width: tileWidth,
                            label: 'GRASSI',
                            value: '${p.targetFatG.round()} g',
                            color: nutrients.fat,
                          ),
                          _TargetTile(
                            width: tileWidth,
                            label: 'FIBRE',
                            value: '${p.targetFiberG.round()} g',
                            color: nutrients.fiber,
                          ),
                          _TargetTile(
                            width: tileWidth,
                            label: 'ACQUA',
                            value: '${p.targetWaterMl} ml',
                            color: nutrients.water,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TargetTile extends StatelessWidget {
  final double width;
  final String label;
  final String value;
  final Color color;

  const _TargetTile({
    required this.width,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: cs.surfaceDim,
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: tt.labelSmall?.copyWith(color: color),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: tt.titleMedium),
          ),
        ],
      ),
    );
  }
}
