import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:uuid/uuid.dart';
import 'data/local_database.dart';
import 'models/nutrition_models.dart';
import 'screens/add_meal_bottom_sheet.dart';
import 'screens/menu_advisor_dialog.dart';
import 'screens/pantry_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/stats_screen.dart';
import 'screens/today_screen.dart';
import 'services/drive_backup_service.dart';
import 'theme/app_theme.dart';
import 'theme/nutrient_colors.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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

class _MainShellScreenState extends State<MainShellScreen> {
  final DriveBackupService _driveService = DriveBackupService();
  int _selectedIndex = 0;
  final String _todayDate = DateTime.now().toIso8601String().split('T').first;

  UserProfile _profile = const UserProfile();
  late DailyMetrics _metrics = DailyMetrics(
    date: _todayDate,
    waterMl: 1500,
    weightKg: 74.2,
  );
  List<MealEntry> _meals = [];
  double? _previousWeightKg;

  @override
  void initState() {
    super.initState();
    LocalDatabase.instance.onDataMutated = () {
      if (_profile.autoBackupEnabled) {
        _driveService.scheduleAutoBackup();
      }
    };
    _loadFromDatabase();
  }

  Future<void> _loadFromDatabase() async {
    final meals = await LocalDatabase.instance.getMealsForDate(_todayDate);
    final metrics = await LocalDatabase.instance.getDailyMetrics(_todayDate);
    final profile = await LocalDatabase.instance.getUserProfile();
    final prevWeight = await LocalDatabase.instance.getPreviousLoggedWeight(_todayDate);
    if (!mounted) return;
    setState(() {
      _meals = meals;
      _metrics = metrics;
      _profile = profile;
      _previousWeightKg = prevWeight;
    });
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

  void _openMealSheet({MealEntry? existingMeal}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddMealBottomSheet(
        selectedDate: _todayDate,
        profile: _profile,
        existingMeal: existingMeal,
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
        },
      ),
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
            date: _todayDate,
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
        title: Text(
          switch (_selectedIndex) {
            0 => 'Oggi',
            1 => 'Statistiche',
            2 => 'Dispensa',
            _ => 'Profilo',
          },
          style: tt.headlineSmall,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: cs.outlineVariant.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Symbols.cloud_done_rounded,
                    size: 14,
                    color: nutrients.fiber,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Sincronizzato',
                    style: tt.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontSize: 10,
                    ),
                  ),
                ],
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
            onDeleteMeal: _deleteMeal,
            onEditMeal: (meal) => _openMealSheet(existingMeal: meal),
          ),
          StatsScreen(profile: _profile),
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
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () => _openMealSheet(),
              icon: const Icon(Symbols.add_rounded),
              label: const Text('Aggiungi pasto'),
            )
          : null,
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
