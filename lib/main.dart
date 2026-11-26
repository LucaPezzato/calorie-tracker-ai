import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:uuid/uuid.dart';
import 'data/local_database.dart';
import 'models/nutrition_models.dart';
import 'screens/add_meal_bottom_sheet.dart';
import 'screens/daily_ai_summary_sheet.dart';
import 'screens/menu_advisor_dialog.dart';
import 'screens/pantry_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/today_screen.dart';
import 'services/app_update_service.dart';
import 'services/drive_backup_service.dart';
import 'services/firebase_backup_service.dart';
import 'services/water_reminder_service.dart';
import 'services/widget_sync_service.dart';
import 'theme/app_theme.dart';
import 'theme/nutrient_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await WidgetSyncService.initialize();
  } catch (_) {}
  try {
    await WaterReminderService.instance.initialize();
  } catch (_) {}
  runApp(const ProviderScope(child: CalorieTrackerAiApp()));
}

class CalorieTrackerAiApp extends StatelessWidget {
  const CalorieTrackerAiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return MaterialApp(
          title: 'Calorie Tracker AI',
          debugShowCheckedModeBanner: false,
          themeMode: ThemeMode.dark,
          theme: AppTheme.buildTheme(
            dynamicScheme: lightDynamic,
            brightness: Brightness.light,
          ),
          darkTheme: AppTheme.buildTheme(
            dynamicScheme: darkDynamic,
            brightness: Brightness.dark,
          ),
          home: const SplashScreen(nextScreen: MainShellScreen()),
        );
      },
    );
  }
}

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> with WidgetsBindingObserver {
  final DriveBackupService _driveService = DriveBackupService();
  final FirebaseBackupService _firebaseService = FirebaseBackupService();
  int _selectedIndex = 0;
  String get _todayDate => DateTime.now().toIso8601String().split('T').first;
  late String _selectedDate = _todayDate;
  bool get _isViewingToday => _selectedDate == _todayDate;

  UserProfile _profile = const UserProfile();
  late DailyMetrics _metrics = DailyMetrics(
    date: _selectedDate,
    waterMl: 1500,
    weightKg: 74.2,
  );
  List<MealEntry> _meals = [];
  List<MealEntry> _quickRepeatMeals = [];
  double? _previousWeightKg;
  int? _daysSinceLastMeal;
  bool _recoveryDismissed = false;
  int _dataVersion = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    HomeWidget.initiallyLaunchedFromHomeWidget().then((uri) {
      if (uri != null && mounted) {
        _handleWidgetUri(uri);
      }
    });
    HomeWidget.widgetClicked.listen((uri) {
      if (uri != null && mounted) {
        _handleWidgetUri(uri);
      }
    });
    _firebaseService.initialize().then((_) {
      if (mounted) setState(() {});
    });
    LocalDatabase.instance.onDataMutated = () {
      WidgetSyncService.syncTodayData(
        profile: _profile,
        metrics: _metrics,
        meals: _meals,
      );
      if (_profile.autoBackupEnabled) {
        if (_firebaseService.currentUser != null) {
          _firebaseService.scheduleAutoBackup();
        } else if (_driveService.currentUser != null) {
          _driveService.scheduleAutoBackup();
        }
      }
    };
    _loadFromDatabase();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        AppUpdateService.calorieTracker.checkAndPrompt(context, silent: true);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadFromDatabase();
    }
  }

  void _handleWidgetUri(Uri uri) {
    setState(() {
      _selectedIndex = 0;
      _selectedDate = _todayDate;
    });
    _loadFromDatabase();
    if (uri.host == 'add-meal') {
      final mode = uri.queryParameters['mode'] == 'photo' ? 1 : 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openMealSheet(initialMode: mode);
      });
    }
  }

  Future<void> _loadFromDatabase() async {
    final meals = await LocalDatabase.instance.getMealsForDate(_selectedDate);
    final metrics = await LocalDatabase.instance.getDailyMetrics(_selectedDate);
    final profile = await LocalDatabase.instance.getUserProfile();
    final prevWeight = await LocalDatabase.instance.getPreviousLoggedWeight(_selectedDate);
    final yesterdayStr = DateTime.parse(_selectedDate)
        .subtract(const Duration(days: 1))
        .toIso8601String()
        .split('T')
        .first;
    final yesterdayMeals = await LocalDatabase.instance.getMealsForDate(yesterdayStr);
    final frequentMeals = await LocalDatabase.instance.getFrequentMeals(limit: 4);
    final seenTitles = <String>{};
    final quickRepeats = <MealEntry>[];
    for (final m in [...yesterdayMeals, ...frequentMeals]) {
      final key = m.title.trim().toLowerCase();
      if (key.isNotEmpty && seenTitles.add(key)) {
        quickRepeats.add(m);
        if (quickRepeats.length >= 4) break;
      }
    }
    final daysGap = _isViewingToday
        ? await LocalDatabase.instance.getDaysSinceLastMeal(_todayDate)
        : null;
    final todayMealsCount = _isViewingToday
        ? meals.length
        : (await LocalDatabase.instance.getMealsForDate(_todayDate)).length;

    if (!mounted) return;
    setState(() {
      _meals = meals;
      _metrics = metrics;
      _profile = profile;
      _previousWeightKg = prevWeight;
      _quickRepeatMeals = quickRepeats;
      _daysSinceLastMeal = daysGap;
      _dataVersion++;
    });
    if (_isViewingToday) {
      WidgetSyncService.syncTodayData(
        profile: profile,
        metrics: metrics,
        meals: meals,
      );
    }
    WaterReminderService.instance.syncSchedule(profile);
    WaterReminderService.instance.syncMealReminder(
      profile: profile,
      todayMealsCount: todayMealsCount,
    );
  }

  void _shiftSelectedDate(int deltaDays) {
    final current = DateTime.parse(_selectedDate);
    final next = current.add(Duration(days: deltaDays));
    final today = DateTime.parse(_todayDate);
    if (next.isAfter(today)) return;
    setState(() {
      _selectedDate = next.toIso8601String().split('T').first;
    });
    _loadFromDatabase();
  }

  Future<void> _pickSelectedDate() async {
    final current = DateTime.parse(_selectedDate);
    final today = DateTime.parse(_todayDate);
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2023),
      lastDate: today,
    );
    if (picked == null) return;
    setState(() {
      _selectedDate = picked.toIso8601String().split('T').first;
    });
    _loadFromDatabase();
  }

  String _formatSelectedDateTitle() {
    if (_isViewingToday) return 'Oggi';
    final d = DateTime.parse(_selectedDate);
    final yesterday = DateTime.parse(_todayDate).subtract(const Duration(days: 1));
    if (d.year == yesterday.year &&
        d.month == yesterday.month &&
        d.day == yesterday.day) {
      return 'Ieri';
    }
    const months = [
      'Gen', 'Feb', 'Mar', 'Apr', 'Mag', 'Giu',
      'Lug', 'Ago', 'Set', 'Ott', 'Nov', 'Dic',
    ];
    return '${d.day} ${months[d.month - 1]}';
  }

  Future<void> _deleteMeal(MealEntry meal) async {
    setState(() {
      _meals = _meals.where((m) => m.id != meal.id).toList();
    });
    await LocalDatabase.instance.deleteMealEntry(meal.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Pasto "${meal.title}" eliminato'),
        action: SnackBarAction(
          label: 'Annulla',
          onPressed: () async {
            await LocalDatabase.instance.saveMealEntry(meal);
            await _loadFromDatabase();
          },
        ),
      ),
    );
  }

  void _openMealSheet({MealEntry? existingMeal, int initialMode = 0}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddMealBottomSheet(
        selectedDate: _selectedDate,
        profile: _profile,
        existingMeal: existingMeal,
        initialMode: initialMode,
        onOpenMenuAdvisor: _openMenuAdvisor,
        onDeleteMeal: existingMeal != null
            ? () => _deleteMeal(existingMeal)
            : null,
        onSaveMeal: (entry) {
          setState(() {
            final withoutOld = _meals.where((m) => m.id != entry.id).toList();
            _meals = [...withoutOld, entry]
              ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
          });
          LocalDatabase.instance.saveMealEntry(entry);
          _syncTodayMealReminder();
        },
        onSaveMultipleMeals: (entries) async {
          setState(() {
            _meals = [..._meals, ...entries]
              ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
          });
          for (final entry in entries) {
            await LocalDatabase.instance.saveMealEntry(entry);
          }
          await _syncTodayMealReminder();
        },
      ),
    );
  }

  Future<void> _syncTodayMealReminder() async {
    final todayMeals = await LocalDatabase.instance.getMealsForDate(_todayDate);
    await WaterReminderService.instance.syncMealReminder(
      profile: _profile,
      todayMealsCount: todayMeals.length,
    );
  }

  Future<void> _quickRepeatMeal(MealEntry template) async {
    final newId = const Uuid().v4();
    final now = TimeOfDay.now();
    final timeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    final clonedItems = template.items
        .map(
          (i) => MealItem(
            id: const Uuid().v4(),
            mealId: newId,
            name: i.name,
            grams: i.grams,
            kcalPer100g: i.kcalPer100g,
            proteinPer100g: i.proteinPer100g,
            carbsPer100g: i.carbsPer100g,
            fatPer100g: i.fatPer100g,
            fiberPer100g: i.fiberPer100g,
            source: MealItemSource.favorite,
            barcode: i.barcode,
          ),
        )
        .toList();
    final entry = MealEntry(
      id: newId,
      date: _selectedDate,
      loggedAt: timeStr,
      title: template.title,
      notes: template.notes,
      items: clonedItems,
    );
    setState(() {
      _meals = [..._meals, entry]
        ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
    });
    await LocalDatabase.instance.saveMealEntry(entry);
    await _syncTodayMealReminder();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Aggiunto "${entry.title}" (${entry.totalKcal} kcal)')),
    );
  }

  void _openMenuAdvisor() {
    final consumedKcal = _meals.fold(0, (s, m) => s + m.totalKcal);
    final consumedP = _meals.fold(0.0, (s, m) => s + m.totalProteinG);
    final consumedC = _meals.fold(0.0, (s, m) => s + m.totalCarbsG);
    final consumedG = _meals.fold(0.0, (s, m) => s + m.totalFatG);

    final remainingKcal = (_profile.targetKcal - consumedKcal).clamp(0, 5000);
    final remainingP = (_profile.targetProteinG - consumedP).clamp(0.0, 500.0);
    final remainingC = (_profile.targetCarbsG - consumedC).clamp(0.0, 800.0);
    final remainingG = (_profile.targetFatG - consumedG).clamp(0.0, 400.0);

    showDialog<void>(
      context: context,
      builder: (_) => MenuAdvisorDialog(
        profile: _profile,
        remainingKcal: remainingKcal,
        remainingProteinG: remainingP,
        remainingCarbsG: remainingC,
        remainingFatG: remainingG,
        onSelectDish: (dish) {
          final now = TimeOfDay.now();
          final timeStr =
              '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
          final mealId = const Uuid().v4();
          final per100Multiplier = 100.0 / dish.estimatedGrams;
          final entry = MealEntry(
            id: mealId,
            date: _selectedDate,
            loggedAt: timeStr,
            title: dish.dishName,
            notes: dish.reasoning,
            items: [
              MealItem(
                id: const Uuid().v4(),
                mealId: mealId,
                name: dish.dishName,
                grams: dish.estimatedGrams.toDouble(),
                kcalPer100g: dish.estimatedKcal * per100Multiplier,
                proteinPer100g: dish.estimatedProteinG * per100Multiplier,
                carbsPer100g: dish.estimatedCarbsG * per100Multiplier,
                fatPer100g: dish.estimatedFatG * per100Multiplier,
                fiberPer100g: dish.estimatedFiberG * per100Multiplier,
                source: MealItemSource.aiText,
              ),
            ],
          );
          _openMealSheet(existingMeal: entry);
        },
      ),
    );
  }

  Future<void> _openWeightDialog() async {
    final ctrl = TextEditingController(
      text: (_metrics.weightKg ?? _profile.currentWeightKg).toStringAsFixed(1),
    );
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Registra Peso di Oggi'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Peso corporeo (kg)',
            suffixText: 'kg',
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
              if (val != null && val > 20 && val < 300) {
                setState(() {
                  _metrics = _metrics.copyWith(weightKg: val);
                });
                LocalDatabase.instance.upsertDailyMetrics(_metrics);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Salva Peso'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final nutrients = context.nutrients;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: _selectedIndex == 0
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    tooltip: 'Giorno precedente',
                    onPressed: () => _shiftSelectedDate(-1),
                    icon: const Icon(Symbols.chevron_left_rounded, size: 22),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: _pickSelectedDate,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _formatSelectedDateTitle(),
                            style: tt.headlineSmall,
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Symbols.calendar_today_rounded,
                            size: 16,
                            color: cs.primary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    tooltip: 'Giorno successivo',
                    onPressed:
                        _isViewingToday ? null : () => _shiftSelectedDate(1),
                    icon: const Icon(Symbols.chevron_right_rounded, size: 22),
                  ),
                ],
              )
            : Text(
                switch (_selectedIndex) {
                  1 => 'Statistiche',
                  2 => 'Dispensa',
                  _ => 'Profilo',
                },
                style: tt.headlineSmall,
              ),
        actions: [
          if (_selectedIndex == 0 && !_isViewingToday)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: TextButton.icon(
                onPressed: () {
                  setState(() => _selectedDate = _todayDate);
                  _loadFromDatabase();
                },
                icon: const Icon(Symbols.today_rounded, size: 16),
                label: const Text('Oggi'),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              tooltip: 'Dati sincronizzati in locale',
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Dati salvati in locale e pronti per il backup.'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              icon: Icon(
                Symbols.cloud_done_rounded,
                size: 20,
                color: nutrients.fiber,
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          TodayScreen(
            profile: _profile,
            metrics: _metrics,
            meals: _meals,
            previousWeightKg: _previousWeightKg,
            daysSinceLastMeal: _recoveryDismissed ? null : _daysSinceLastMeal,
            quickRepeatMeals: _quickRepeatMeals,
            onQuickRepeatMeal: _quickRepeatMeal,
            onDismissRecovery: () => setState(() => _recoveryDismissed = true),
            onOpenQuickAdd: () => _openMealSheet(),
            onAddWater: (ml) {
              setState(() {
                _metrics = _metrics.copyWith(
                  waterMl: (_metrics.waterMl + ml).clamp(0, 10000),
                );
              });
              LocalDatabase.instance.upsertDailyMetrics(_metrics);
            },
            onUpdateCoffee: (cups) {
              setState(() {
                _metrics = _metrics.copyWith(
                  coffeeCups: cups.clamp(0, 30),
                );
              });
              LocalDatabase.instance.upsertDailyMetrics(_metrics);
            },
            onTapWeight: _openWeightDialog,
            onOpenMenuAdvisor: _openMenuAdvisor,
            onOpenDailySummary: () => DailyAiSummarySheet.show(
              context,
              date: _selectedDate,
              profile: _profile,
              meals: _meals,
              metrics: _metrics,
            ),
            onDeleteMeal: _deleteMeal,
            onEditMeal: (meal) => _openMealSheet(existingMeal: meal),
          ),
          StatsScreen(
            key: ValueKey(_dataVersion),
            profile: _profile,
            onDataChanged: _loadFromDatabase,
          ),
          PantryScreen(
            onQuickAddMeal: (entry) {
              setState(() {
                _meals = [..._meals, entry]
                  ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
                _selectedIndex = 0;
              });
              LocalDatabase.instance.saveMealEntry(entry);
            },
          ),
          ProfileScreen(
            profile: _profile,
            driveService: _driveService,
            firebaseService: _firebaseService,
            onProfileChanged: (updated) {
              setState(() => _profile = updated);
              LocalDatabase.instance.saveUserProfile(updated);
            },
            onDatabaseRestored: _loadFromDatabase,
          ),
        ],
      ),
      // Scaffold positions endFloat 16dp above NavigationBar automatically
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: IgnorePointer(
        ignoring: _selectedIndex != 0,
        child: AnimatedSlide(
          offset: _selectedIndex == 0 ? Offset.zero : const Offset(0, 0.14),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: _selectedIndex == 0 ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 170),
            curve: Curves.easeOutCubic,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FloatingActionButton.small(
                  heroTag: 'fab_quick_camera',
                  tooltip: 'Scatta foto pasto',
                  backgroundColor: cs.secondaryContainer,
                  foregroundColor: cs.onSecondaryContainer,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  onPressed: () => _openMealSheet(initialMode: 1),
                  child: const Icon(Symbols.photo_camera_rounded),
                ),
                const SizedBox(height: 10),
                FloatingActionButton.extended(
                  heroTag: 'fab_add_meal',
                  onPressed: () => _openMealSheet(),
                  icon: const Icon(Symbols.add_rounded),
                  label: const Text('Aggiungi pasto'),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Symbols.today_rounded, fill: 0),
            selectedIcon: Icon(Symbols.today_rounded, fill: 1),
            label: 'Oggi',
          ),
          NavigationDestination(
            icon: Icon(Symbols.monitoring_rounded, fill: 0),
            selectedIcon: Icon(Symbols.monitoring_rounded, fill: 1),
            label: 'Statistiche',
          ),
          NavigationDestination(
            icon: Icon(Symbols.kitchen_rounded, fill: 0),
            selectedIcon: Icon(Symbols.kitchen_rounded, fill: 1),
            label: 'Dispensa',
          ),
          NavigationDestination(
            icon: Icon(Symbols.person_rounded, fill: 0),
            selectedIcon: Icon(Symbols.person_rounded, fill: 1),
            label: 'Profilo',
          ),
        ],
      ),
    );
  }
}
