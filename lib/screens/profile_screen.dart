import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../data/local_database.dart';
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
  final VoidCallback? onDatabaseRestored;

  const ProfileScreen({
    super.key,
    required this.profile,
    required this.driveService,
    required this.onProfileChanged,
    this.onDatabaseRestored,
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
  bool _isBackingUp = false;
  bool _isRestoring = false;
  DateTime? _lastKnownDriveBackup;

  @override
  void initState() {
    super.initState();
    _provider = widget.profile.preferredAiProvider;
    _goalType = widget.profile.goalType;
    _autoBackup = widget.profile.autoBackupEnabled;
    _manualOverride = widget.profile.isManualOverride;
    _lastKnownDriveBackup = widget.profile.lastDriveBackupAt;
    _loadStoredKey();
    _checkDriveBackupMetadata();
  }

  Future<void> _checkDriveBackupMetadata() async {
    final info = await widget.driveService.getLatestBackupInfo();
    if (info != null && mounted) {
      setState(() => _lastKnownDriveBackup = info.modifiedTime);
    }
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
    final existing = await _keysService.getApiKey(_provider);
    if (!mounted) return;
    final ctrl = TextEditingController(text: existing ?? '');
    bool obscure = true;
    final provName = _provider == AiProviderType.gemini
        ? 'Google Gemini'
        : 'OpenAI';
    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Configura API Key $provName'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: ctrl,
                obscureText: obscure,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  hintText: _provider == AiProviderType.gemini
                      ? 'AIzaSy...'
                      : 'sk-proj-...',
                  helperText: 'Salvata cifrata sul dispositivo',
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          obscure
                              ? Symbols.visibility_rounded
                              : Symbols.visibility_off_rounded,
                        ),
                        tooltip: 'Mostra/Nascondi',
                        onPressed: () =>
                            setDialogState(() => obscure = !obscure),
                      ),
                      IconButton(
                        icon: const Icon(Symbols.content_paste_rounded),
                        tooltip: 'Incolla dagli appunti',
                        onPressed: () async {
                          final clip = await Clipboard.getData(
                            Clipboard.kTextPlain,
                          );
                          if (clip?.text != null) {
                            ctrl.text = clip!.text!.trim();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            if (existing != null && existing.isNotEmpty)
              TextButton(
                onPressed: () async {
                  await _keysService.deleteApiKey(_provider);
                  await _loadStoredKey();
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Text(
                  'Elimina',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () async {
                await _keysService.saveApiKey(_provider, ctrl.text);
                await _loadStoredKey();
                if (ctx.mounted) Navigator.pop(ctx);
                await _testAiConnection();
              },
              child: const Text('Salva e Testa'),
            ),
          ],
        ),
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
      _aiTestStatus = 'Verifica in corso...';
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
        _aiTestStatus = 'Connessione attiva (${sw.elapsedMilliseconds} ms)';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Connessione verificata con successo in ${sw.elapsedMilliseconds} ms',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final cleanErr = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _aiTestStatus = 'Errore AI (tocca per riprovare)';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 6),
          content: Text('Errore test AI: $cleanErr'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isTestingAi = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    try {
      if (widget.driveService.currentUser != null) {
        // Confirm sign out
        final confirm = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Disconnetti account Google'),
            content: Text(
              'Vuoi disconnettere "${widget.driveService.currentUser?.email}" da Google Drive?',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Disconnetti')),
            ],
          ),
        );
        if (confirm == true) {
          await widget.driveService.signOut();
          if (!mounted) return;
          setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account Google scollegato.')),
          );
        }
        return;
      }

      final account = await widget.driveService.signInInteractive();
      if (!mounted) return;
      setState(() {});
      if (account != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Connesso come ${account.email}')),
        );
        await _checkDriveBackupMetadata();
      }
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Stato Google Sign-In'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(msg),
              const SizedBox(height: 12),
              const Text(
                'Nota: se stai testando la tua app Android personale senza Google Cloud OAuth, puoi sempre usare il pulsante "Backup & Ripristino Locale (File/JSON)" sottostante, che funziona offline al 100%.',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Ho capito'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _handleDriveBackup() async {
    setState(() => _isBackingUp = true);
    try {
      final date = await widget.driveService.backupNow();
      if (!mounted) return;
      setState(() => _lastKnownDriveBackup = date);
      widget.onProfileChanged(widget.profile.copyWith(lastDriveBackupAt: date));
      await LocalDatabase.instance.saveUserProfile(
        widget.profile.copyWith(lastDriveBackupAt: date),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Backup su Google Drive completato alle ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 6),
          content: Text('Errore backup: $msg'),
          action: SnackBarAction(
            label: 'Info',
            onPressed: () => _handleGoogleSignIn(),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isBackingUp = false);
    }
  }

  Future<void> _handleDriveRestore() async {
    if (widget.driveService.currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Effettua prima l\'accesso con Google toccando la card sopra.'),
        ),
      );
      return;
    }

    setState(() => _isRestoring = true);
    try {
      final info = await widget.driveService.getLatestBackupInfo();
      if (info == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nessun file di backup trovato su Google Drive per questo account.'),
          ),
        );
        return;
      }

      if (!mounted) return;
      final dateStr =
          '${info.modifiedTime.day}/${info.modifiedTime.month}/${info.modifiedTime.year} alle ${info.modifiedTime.hour.toString().padLeft(2, '0')}:${info.modifiedTime.minute.toString().padLeft(2, '0')}';

      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Ripristina da Google Drive'),
          content: Text(
            'Trovato backup del $dateStr.\n\nAttenzione: tutti i pasti e le metriche attuali sul telefono verranno sovrascritti con quelli del backup.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annulla'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Ripristina ora'),
            ),
          ],
        ),
      );

      if (confirm != true) return;

      await widget.driveService.restoreFromDrive();
      if (!mounted) return;

      // Reload entire app memory
      widget.onDatabaseRestored?.call();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          content: Text('Database ripristinato da Google Drive ($dateStr)'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(duration: const Duration(seconds: 6), content: Text('Errore ripristino: $msg')),
      );
    } finally {
      if (mounted) setState(() => _isRestoring = false);
    }
  }

  Future<void> _handleExportLocalBackup() async {
    try {
      final jsonMap = await LocalDatabase.instance.exportDatabaseAsJson();
      final jsonText = const JsonEncoder.withIndent('  ').convert(jsonMap);
      if (!mounted) return;

      final mealsCount = (jsonMap['meal_entries'] as List?)?.length ?? 0;
      final favsCount = (jsonMap['favorite_foods'] as List?)?.length ?? 0;

      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Esporta Backup Locale (JSON)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Backup generato con successo:\n• $mealsCount pasti registrati\n• $favsCount alimenti in dispensa',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              const Text(
                'Copia questo testo per salvarlo nelle tue note, inviarlo su Telegram o salvarlo dove preferisci:',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 8),
              Container(
                height: 120,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceDim,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    jsonText,
                    style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Chiudi'),
            ),
            FilledButton.icon(
              icon: const Icon(Symbols.content_copy_rounded, size: 16),
              label: const Text('Copia Backup Negli Appunti'),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: jsonText));
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Backup JSON copiato negli appunti')),
                  );
                }
              },
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore esportazione backup: $e')),
      );
    }
  }

  Future<void> _handleImportLocalBackup() async {
    final ctrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ripristina da Backup Locale (JSON)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Incolla qui il testo JSON del backup esportato in precedenza:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: '{\n  "version": 1,\n  "meal_entries": [...]\n}',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Verifica e Ripristina'),
          ),
        ],
      ),
    );

    if (confirm != true || ctrl.text.trim().isEmpty) return;

    try {
      final decoded = jsonDecode(ctrl.text.trim());
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Formato non valido: deve essere un oggetto JSON.');
      }
      await LocalDatabase.instance.importDatabaseFromJson(decoded);
      if (!mounted) return;

      widget.onDatabaseRestored?.call();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Database locale ripristinato con successo dal JSON'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore importazione: formato JSON non valido ($e)')),
      );
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
            side: BorderSide(
              color: widget.driveService.currentUser != null
                  ? nutrients.fiber
                  : cs.outlineVariant.withValues(alpha: 0.6),
              width: 1.2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: widget.driveService.currentUser != null
                          ? nutrients.fiber
                          : cs.surfaceContainerHighest,
                      foregroundColor: widget.driveService.currentUser != null
                          ? Colors.black
                          : cs.onSurface,
                      child: Icon(
                        widget.driveService.currentUser != null
                            ? Symbols.cloud_done_rounded
                            : Symbols.cloud_off_rounded,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.driveService.currentUser?.email ??
                                'Google Drive non collegato',
                            style: tt.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _lastKnownDriveBackup != null
                                ? 'Ultimo backup: ${_lastKnownDriveBackup!.day}/${_lastKnownDriveBackup!.month} alle ${_lastKnownDriveBackup!.hour.toString().padLeft(2, '0')}:${_lastKnownDriveBackup!.minute.toString().padLeft(2, '0')}'
                                : 'Archiviazione privata Google Drive',
                            style: tt.labelSmall?.copyWith(
                              color: widget.driveService.currentUser != null
                                  ? nutrients.fiber
                                  : cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                      ),
                      onPressed: _handleGoogleSignIn,
                      child: Text(
                        widget.driveService.currentUser != null
                            ? 'Cambia'
                            : 'Accedi',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Backup automatico ad ogni modifica',
                    style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    'Sincronizza SQLite in background (le foto restano solo sul telefono)',
                    style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  value: _autoBackup,
                  onChanged: (v) {
                    setState(() => _autoBackup = v);
                    final updated = widget.profile.copyWith(autoBackupEnabled: v);
                    widget.onProfileChanged(updated);
                    LocalDatabase.instance.saveUserProfile(updated);
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _isBackingUp || _isRestoring
                            ? null
                            : _handleDriveBackup,
                        icon: _isBackingUp
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Symbols.cloud_upload_rounded, size: 18),
                        label: Text(_isBackingUp ? 'Salvataggio...' : 'Backup Ora'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _isBackingUp || _isRestoring
                            ? null
                            : _handleDriveRestore,
                        icon: _isRestoring
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(
                                Symbols.cloud_download_rounded,
                                size: 18,
                              ),
                        label: Text(_isRestoring ? 'Download...' : 'Ripristina DB'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 1B. LOCAL BACKUP & RESTORE CARD (100% OFFLINE / INDEPENDENT)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Symbols.folder_zip_rounded, color: cs.primary, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Backup & Ripristino Locale (Offline)',
                        style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Esporta l\'intero database in formato JSON per conservarlo nelle note, inviarlo o ripristinarlo in qualsiasi momento senza account.',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: _handleExportLocalBackup,
                        icon: const Icon(Symbols.upload_rounded, size: 17),
                        label: const Text('Esporta JSON'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _handleImportLocalBackup,
                        icon: const Icon(Symbols.download_rounded, size: 17),
                        label: const Text('Importa JSON'),
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
                Text('Riconoscimento pasti', style: tt.titleLarge),
                const SizedBox(height: 10),
                SegmentedButton<AiProviderType>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: AiProviderType.gemini,
                      label: Text('Gemini'),
                      icon: Icon(Symbols.bolt_rounded, size: 16),
                    ),
                    ButtonSegment(
                      value: AiProviderType.openai,
                      label: Text('OpenAI'),
                      icon: Icon(Symbols.smart_toy_rounded, size: 16),
                    ),
                  ],
                  selected: {_provider},
                  onSelectionChanged: (s) {
                    final newProv = s.first;
                    setState(() {
                      _provider = newProv;
                      _aiTestStatus = null;
                    });
                    widget.onProfileChanged(
                      UserProfile(
                        sex: p.sex,
                        birthYear: p.birthYear,
                        heightCm: p.heightCm,
                        currentWeightKg: p.currentWeightKg,
                        activityMultiplier: p.activityMultiplier,
                        goalType: p.goalType,
                        isManualOverride: p.isManualOverride,
                        targetKcal: p.targetKcal,
                        targetProteinG: p.targetProteinG,
                        targetCarbsG: p.targetCarbsG,
                        targetFatG: p.targetFatG,
                        targetFiberG: p.targetFiberG,
                        targetWaterMl: p.targetWaterMl,
                        preferredAiProvider: newProv,
                        preferredAiModel: newProv == AiProviderType.gemini
                            ? 'gemini-2.5-flash'
                            : 'gpt-4o-mini',
                        autoBackupEnabled: _autoBackup,
                      ),
                    );
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
                        color: cs.outlineVariant.withValues(alpha: 0.25),
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
                    icon: const Icon(Symbols.check_circle_rounded, size: 18),
                    label: Text(
                      _aiTestStatus ?? 'Verifica connessione',
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
                            label: 'Calorie',
                            value: '${p.targetKcal} kcal',
                            color: cs.primary,
                          ),
                          _TargetTile(
                            width: tileWidth,
                            label: 'Proteine',
                            value: '${p.targetProteinG.round()} g',
                            color: nutrients.protein,
                          ),
                          _TargetTile(
                            width: tileWidth,
                            label: 'Carboidrati',
                            value: '${p.targetCarbsG.round()} g',
                            color: nutrients.carbs,
                          ),
                          _TargetTile(
                            width: tileWidth,
                            label: 'Grassi',
                            value: '${p.targetFatG.round()} g',
                            color: nutrients.fat,
                          ),
                          _TargetTile(
                            width: tileWidth,
                            label: 'Fibre',
                            value: '${p.targetFiberG.round()} g',
                            color: nutrients.fiber,
                          ),
                          _TargetTile(
                            width: tileWidth,
                            label: 'Acqua',
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
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.25),
        ),
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
            child: Text(
              value,
              style: tt.titleMedium?.copyWith(
                fontFeatures: const [
                  FontFeature.tabularFigures(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
