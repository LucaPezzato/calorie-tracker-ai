import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'data/local_database.dart';
import 'models/nutrition_models.dart';
import 'screens/add_meal_bottom_sheet.dart';
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
  DailyMetrics _metrics = const DailyMetrics(
    date: '2026-11-10',
    waterMl: 1500,
    weightKg: 74.2,
  );
  List<MealEntry> _meals = [
    const MealEntry(
      id: 'm1',
      date: '2026-11-10',
      loggedAt: '08:30',
      title: 'Yogurt greco, avena e miele',
      items: [
        MealItem(
          id: 'i1',
          mealId: 'm1',
          name: 'Yogurt greco 0%',
          grams: 170,
          kcalPer100g: 54,
          proteinPer100g: 10.3,
          carbsPer100g: 3.0,
          fatPer100g: 0,
        ),
        MealItem(
          id: 'i2',
          mealId: 'm1',
          name: 'Fiocchi d\'avena',
          grams: 40,
          kcalPer100g: 375,
          proteinPer100g: 13.5,
          carbsPer100g: 60.0,
          fatPer100g: 7.0,
          fiberPer100g: 10.0,
        ),
      ],
    ),
    const MealEntry(
      id: 'm2',
      date: '2026-11-10',
      loggedAt: '13:15',
      title: 'Pasta integrale al tonno',
      items: [
        MealItem(
          id: 'i3',
          mealId: 'm2',
          name: 'Pasta integrale',
          grams: 100,
          kcalPer100g: 351,
          proteinPer100g: 14.5,
          carbsPer100g: 66.0,
          fatPer100g: 2.0,
          fiberPer100g: 6.5,
        ),
        MealItem(
          id: 'i4',
          mealId: 'm2',
          name: 'Tonno al naturale',
          grams: 120,
          kcalPer100g: 108,
          proteinPer100g: 24.0,
          carbsPer100g: 0,
          fatPer100g: 1.0,
        ),
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    LocalDatabase.instance.onDataMutated = () {
      if (_profile.autoBackupEnabled) {
        _driveService.scheduleAutoBackup();
      }
    };
  }

  void _openAddMealSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddMealBottomSheet(
        selectedDate: _todayDate,
        profile: _profile,
        onSaveMeal: (entry) {
          setState(() {
            _meals = [..._meals, entry]
              ..sort((a, b) => a.loggedAt.compareTo(b.loggedAt));
          });
          LocalDatabase.instance.saveMealEntry(entry);
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
            2 => 'Dispensa & Barcode',
            _ => 'Profilo & Cloud',
          },
          style: tt.headlineSmall,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: nutrients.fiber),
              ),
              child: Row(
                children: [
                  Icon(
                    Symbols.cloud_done_rounded,
                    size: 15,
                    fill: 1,
                    color: nutrients.fiber,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'Drive OK',
                    style: tt.labelSmall?.copyWith(color: nutrients.fiber),
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
            onAddWater: (ml) {
              setState(() {
                _metrics = _metrics.copyWith(waterMl: _metrics.waterMl + ml);
              });
              LocalDatabase.instance.upsertDailyMetrics(_metrics);
            },
            onTapWeight: _openWeightDialog,
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
            },
          ),
        ],
      ),
      // Scaffold positions endFloat 16dp above NavigationBar automatically
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton.extended(
              onPressed: _openAddMealSheet,
              icon: const Icon(Symbols.add_rounded),
              label: const Text('Aggiungi Pasto'),
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
