import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/nutrition_models.dart';

class LocalDatabase {
  static const String dbFileName = 'calorie_tracker_ai.sqlite';
  static final LocalDatabase instance = LocalDatabase._();

  Database? _db;
  void Function()? onDataMutated;

  LocalDatabase._();

  Future<String> get databaseFilePath async {
    final docsDir = await getApplicationDocumentsDirectory();
    return p.join(docsDir.path, dbFileName);
  }

  Future<Database> get database async {
    if (_db != null) return _db!;
    final path = await databaseFilePath;
    _db = await openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onOpen: (db) async {
        try {
          await db.execute(
            'ALTER TABLE daily_metrics ADD COLUMN coffee_cups INTEGER NOT NULL DEFAULT 0',
          );
        } catch (_) {}
      },
      onCreate: _onCreate,
    );
    return _db!;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE user_profile (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        sex TEXT NOT NULL DEFAULT 'M',
        birth_year INTEGER NOT NULL DEFAULT 1995,
        height_cm REAL NOT NULL DEFAULT 178.0,
        current_weight_kg REAL NOT NULL DEFAULT 74.2,
        activity_multiplier REAL NOT NULL DEFAULT 1.55,
        goal_type TEXT NOT NULL DEFAULT 'deficit',
        is_manual_override INTEGER NOT NULL DEFAULT 0,
        target_kcal INTEGER NOT NULL DEFAULT 2400,
        target_protein_g REAL NOT NULL DEFAULT 150.0,
        target_carbs_g REAL NOT NULL DEFAULT 240.0,
        target_fat_g REAL NOT NULL DEFAULT 65.0,
        target_fiber_g REAL NOT NULL DEFAULT 30.0,
        target_water_ml INTEGER NOT NULL DEFAULT 2500,
        preferred_ai_provider TEXT NOT NULL DEFAULT 'gemini',
        preferred_ai_model TEXT NOT NULL DEFAULT 'gemini-2.5-flash',
        auto_backup_enabled INTEGER NOT NULL DEFAULT 1,
        last_drive_backup_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE meal_entries (
        id TEXT PRIMARY KEY,
        date TEXT NOT NULL,
        logged_at TEXT NOT NULL,
        title TEXT NOT NULL,
        notes TEXT,
        local_photo_path TEXT,
        total_kcal INTEGER NOT NULL DEFAULT 0,
        total_protein_g REAL NOT NULL DEFAULT 0,
        total_carbs_g REAL NOT NULL DEFAULT 0,
        total_fat_g REAL NOT NULL DEFAULT 0,
        total_fiber_g REAL NOT NULL DEFAULT 0
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_meal_entries_date ON meal_entries(date, logged_at)',
    );

    await db.execute('''
      CREATE TABLE meal_items (
        id TEXT PRIMARY KEY,
        meal_id TEXT NOT NULL,
        name TEXT NOT NULL,
        grams REAL NOT NULL,
        kcal_per_100g REAL NOT NULL,
        protein_per_100g REAL NOT NULL,
        carbs_per_100g REAL NOT NULL,
        fat_per_100g REAL NOT NULL,
        fiber_per_100g REAL NOT NULL DEFAULT 0,
        source TEXT NOT NULL,
        barcode TEXT,
        FOREIGN KEY (meal_id) REFERENCES meal_entries(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE daily_metrics (
        date TEXT PRIMARY KEY,
        water_ml INTEGER NOT NULL DEFAULT 0,
        coffee_cups INTEGER NOT NULL DEFAULT 0,
        weight_kg REAL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE favorite_foods (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        default_grams REAL NOT NULL,
        kcal_per_100g REAL NOT NULL,
        protein_per_100g REAL NOT NULL,
        carbs_per_100g REAL NOT NULL,
        fat_per_100g REAL NOT NULL,
        fiber_per_100g REAL NOT NULL DEFAULT 0,
        barcode TEXT,
        use_count INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // Insert default profile row
    await db.insert('user_profile', {'id': 1});

    // Seed initial pantry foods (can be deleted anytime by user)
    final initialFoods = [
      const FavoriteFood(
        id: 'f1',
        name: 'Yogurt Greco Fage Total 0%',
        defaultGrams: 170,
        kcalPer100g: 54,
        proteinPer100g: 10.3,
        carbsPer100g: 3.0,
        fatPer100g: 0,
        barcode: '5201054017415',
        useCount: 38,
      ),
      const FavoriteFood(
        id: 'f2',
        name: 'Pasta Integrale Rummo',
        defaultGrams: 100,
        kcalPer100g: 351,
        proteinPer100g: 14.5,
        carbsPer100g: 66.0,
        fatPer100g: 2.0,
        fiberPer100g: 6.0,
        barcode: '8008343200553',
        useCount: 24,
      ),
      const FavoriteFood(
        id: 'f3',
        name: 'Petto di Pollo (Crudo)',
        defaultGrams: 200,
        kcalPer100g: 110,
        proteinPer100g: 23.0,
        carbsPer100g: 0,
        fatPer100g: 1.6,
        useCount: 21,
      ),
      const FavoriteFood(
        id: 'f4',
        name: 'Olio Extravergine d\'Oliva (1 cucchiaio)',
        defaultGrams: 10,
        kcalPer100g: 884,
        proteinPer100g: 0,
        carbsPer100g: 0,
        fatPer100g: 100.0,
        useCount: 45,
      ),
    ];

    for (final f in initialFoods) {
      await db.insert('favorite_foods', {
        'id': f.id,
        'name': f.name,
        'default_grams': f.defaultGrams,
        'kcal_per_100g': f.kcalPer100g,
        'protein_per_100g': f.proteinPer100g,
        'carbs_per_100g': f.carbsPer100g,
        'fat_per_100g': f.fatPer100g,
        'fiber_per_100g': f.fiberPer100g,
        'barcode': f.barcode,
        'use_count': f.useCount,
      });
    }

    // Seed initial demo meals & metrics for today on first install (can be deleted anytime)
    final today = DateTime.now().toIso8601String().split('T').first;
    await db.insert('daily_metrics', {
      'date': today,
      'water_ml': 1500,
      'weight_kg': 74.2,
      'updated_at': DateTime.now().toIso8601String(),
    });

    final demoMeals = [
      MealEntry(
        id: 'm1',
        date: today,
        loggedAt: '08:30',
        title: 'Yogurt greco, avena e miele',
        items: const [
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
      MealEntry(
        id: 'm2',
        date: today,
        loggedAt: '13:15',
        title: 'Pasta integrale al tonno',
        items: const [
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

    for (final entry in demoMeals) {
      await db.insert('meal_entries', {
        'id': entry.id,
        'date': entry.date,
        'logged_at': entry.loggedAt,
        'title': entry.title,
        'notes': entry.notes,
        'local_photo_path': entry.localPhotoPath,
        'total_kcal': entry.totalKcal,
        'total_protein_g': entry.totalProteinG,
        'total_carbs_g': entry.totalCarbsG,
        'total_fat_g': entry.totalFatG,
        'total_fiber_g': entry.totalFiberG,
      });
      for (final item in entry.items) {
        await db.insert('meal_items', item.toMap());
      }
    }
  }

  /// Fetch chronological timeline meals for a specific date (YYYY-MM-DD)
  Future<List<MealEntry>> getMealsForDate(String date) async {
    final db = await database;
    final entryRows = await db.query(
      'meal_entries',
      where: 'date = ?',
      whereArgs: [date],
      orderBy: 'logged_at ASC',
    );

    final result = <MealEntry>[];
    for (final row in entryRows) {
      final mealId = row['id'] as String;
      final itemRows = await db.query(
        'meal_items',
        where: 'meal_id = ?',
        whereArgs: [mealId],
      );
      result.add(
        MealEntry(
          id: mealId,
          date: row['date'] as String,
          loggedAt: row['logged_at'] as String,
          title: row['title'] as String,
          notes: row['notes'] as String?,
          localPhotoPath: row['local_photo_path'] as String?,
          items: itemRows.map(MealItem.fromMap).toList(),
        ),
      );
    }
    return result;
  }

  /// Insert or update a meal entry with its ingredients and trigger auto-backup debounce
  Future<void> saveMealEntry(MealEntry entry) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.insert(
        'meal_entries',
        {
          'id': entry.id,
          'date': entry.date,
          'logged_at': entry.loggedAt,
          'title': entry.title,
          'notes': entry.notes,
          'local_photo_path': entry.localPhotoPath,
          'total_kcal': entry.totalKcal,
          'total_protein_g': entry.totalProteinG,
          'total_carbs_g': entry.totalCarbsG,
          'total_fat_g': entry.totalFatG,
          'total_fiber_g': entry.totalFiberG,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      await txn.delete(
        'meal_items',
        where: 'meal_id = ?',
        whereArgs: [entry.id],
      );

      for (final item in entry.items) {
        await txn.insert('meal_items', item.toMap());
      }
    });

    onDataMutated?.call();
  }

  /// Delete a meal entry (and its items via ON DELETE CASCADE) from SQLite
  Future<void> deleteMealEntry(String mealId) async {
    final db = await database;
    await db.delete('meal_entries', where: 'id = ?', whereArgs: [mealId]);
    onDataMutated?.call();
  }

  Future<List<FavoriteFood>> getFavoriteFoods() async {
    final db = await database;
    final rows = await db.query('favorite_foods', orderBy: 'use_count DESC');
    return rows
        .map(
          (r) => FavoriteFood(
            id: r['id'] as String,
            name: r['name'] as String,
            defaultGrams: (r['default_grams'] as num).toDouble(),
            kcalPer100g: (r['kcal_per_100g'] as num).toDouble(),
            proteinPer100g: (r['protein_per_100g'] as num).toDouble(),
            carbsPer100g: (r['carbs_per_100g'] as num).toDouble(),
            fatPer100g: (r['fat_per_100g'] as num).toDouble(),
            fiberPer100g: (r['fiber_per_100g'] as num?)?.toDouble() ?? 0.0,
            barcode: r['barcode'] as String?,
            useCount: (r['use_count'] as int?) ?? 1,
          ),
        )
        .toList();
  }

  Future<void> saveFavoriteFood(FavoriteFood food) async {
    final db = await database;
    await db.insert(
      'favorite_foods',
      {
        'id': food.id,
        'name': food.name,
        'default_grams': food.defaultGrams,
        'kcal_per_100g': food.kcalPer100g,
        'protein_per_100g': food.proteinPer100g,
        'carbs_per_100g': food.carbsPer100g,
        'fat_per_100g': food.fatPer100g,
        'fiber_per_100g': food.fiberPer100g,
        'barcode': food.barcode,
        'use_count': food.useCount,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    onDataMutated?.call();
  }

  Future<void> deleteFavoriteFood(String id) async {
    final db = await database;
    await db.delete('favorite_foods', where: 'id = ?', whereArgs: [id]);
    onDataMutated?.call();
  }

  Future<DailyMetrics> getDailyMetrics(String date) async {
    final db = await database;
    final rows = await db.query(
      'daily_metrics',
      where: 'date = ?',
      whereArgs: [date],
    );
    if (rows.isEmpty) return DailyMetrics(date: date);
    final r = rows.first;
    return DailyMetrics(
      date: date,
      waterMl: (r['water_ml'] as int?) ?? 0,
      coffeeCups: (r['coffee_cups'] as int?) ?? 0,
      weightKg: (r['weight_kg'] as num?)?.toDouble(),
    );
  }

  Future<void> upsertDailyMetrics(DailyMetrics metrics) async {
    final db = await database;
    await db.insert(
      'daily_metrics',
      {
        'date': metrics.date,
        'water_ml': metrics.waterMl,
        'coffee_cups': metrics.coffeeCups,
        'weight_kg': metrics.weightKg,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    onDataMutated?.call();
  }

  /// Flushes SQLite WAL to the main .sqlite file before uploading to Google Drive
  Future<File> prepareDatabaseFileForBackup() async {
    final db = await database;
    await db.rawQuery('PRAGMA wal_checkpoint(FULL)');
    final path = await databaseFilePath;
    return File(path);
  }

  /// Replaces the local SQLite database with a snapshot downloaded from Google Drive
  Future<void> restoreDatabaseFromBytes(List<int> bytes) async {
    if (_db != null) {
      await _db!.close();
      _db = null;
    }
    final path = await databaseFilePath;
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    await database;
    onDataMutated?.call();
  }

  /// Exports the entire database content into a structured JSON map
  Future<Map<String, dynamic>> exportDatabaseAsJson() async {
    final db = await database;
    final profiles = await db.query('user_profile');
    final meals = await db.query('meal_entries');
    final items = await db.query('meal_items');
    final metrics = await db.query('daily_metrics');
    final favorites = await db.query('favorite_foods');

    return {
      'version': 1,
      'exported_at': DateTime.now().toIso8601String(),
      'user_profile': profiles.isNotEmpty ? profiles.first : null,
      'meal_entries': meals,
      'meal_items': items,
      'daily_metrics': metrics,
      'favorite_foods': favorites,
    };
  }

  /// Restores the entire database from a structured JSON map inside an atomic transaction
  Future<void> importDatabaseFromJson(Map<String, dynamic> data) async {
    final db = await database;
    await db.transaction((txn) async {
      // 1. Restore Profile if present
      if (data['user_profile'] is Map) {
        final profMap = Map<String, dynamic>.from(data['user_profile'] as Map);
        await txn.insert('user_profile', profMap, conflictAlgorithm: ConflictAlgorithm.replace);
      }

      // 2. Restore Meal Entries
      if (data['meal_entries'] is List) {
        await txn.delete('meal_items');
        await txn.delete('meal_entries');
        for (final m in data['meal_entries'] as List) {
          if (m is Map) {
            await txn.insert('meal_entries', Map<String, dynamic>.from(m), conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
      }

      // 3. Restore Meal Items
      if (data['meal_items'] is List) {
        for (final it in data['meal_items'] as List) {
          if (it is Map) {
            await txn.insert('meal_items', Map<String, dynamic>.from(it), conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
      }

      // 4. Restore Daily Metrics
      if (data['daily_metrics'] is List) {
        await txn.delete('daily_metrics');
        for (final met in data['daily_metrics'] as List) {
          if (met is Map) {
            await txn.insert('daily_metrics', Map<String, dynamic>.from(met), conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
      }

      // 5. Restore Favorite Foods
      if (data['favorite_foods'] is List) {
        await txn.delete('favorite_foods');
        for (final fav in data['favorite_foods'] as List) {
          if (fav is Map) {
            await txn.insert('favorite_foods', Map<String, dynamic>.from(fav), conflictAlgorithm: ConflictAlgorithm.replace);
          }
        }
      }
    });

    onDataMutated?.call();
  }

  Future<UserProfile> getUserProfile() async {
    final db = await database;
    final rows = await db.query('user_profile', where: 'id = 1');
    if (rows.isEmpty) return const UserProfile();
    final r = rows.first;
    return UserProfile(
      sex: r['sex'] as String? ?? 'M',
      birthYear: (r['birth_year'] as int?) ?? 1995,
      heightCm: (r['height_cm'] as num?)?.toDouble() ?? 178.0,
      currentWeightKg: (r['current_weight_kg'] as num?)?.toDouble() ?? 74.2,
      activityMultiplier: (r['activity_multiplier'] as num?)?.toDouble() ?? 1.55,
      goalType: GoalType.values.firstWhere(
        (e) => e.name == (r['goal_type'] as String?),
        orElse: () => GoalType.deficit,
      ),
      isManualOverride: (r['is_manual_override'] as int?) == 1,
      targetKcal: (r['target_kcal'] as int?) ?? 2400,
      targetProteinG: (r['target_protein_g'] as num?)?.toDouble() ?? 150.0,
      targetCarbsG: (r['target_carbs_g'] as num?)?.toDouble() ?? 240.0,
      targetFatG: (r['target_fat_g'] as num?)?.toDouble() ?? 65.0,
      targetFiberG: (r['target_fiber_g'] as num?)?.toDouble() ?? 30.0,
      targetWaterMl: (r['target_water_ml'] as int?) ?? 2500,
      preferredAiProvider: (r['preferred_ai_provider'] as String?) == 'openai'
          ? AiProviderType.openai
          : AiProviderType.gemini,
      preferredAiModel: (r['preferred_ai_model'] as String?) ?? 'gemini-2.5-flash',
      autoBackupEnabled: (r['auto_backup_enabled'] as int?) != 0,
      lastDriveBackupAt: r['last_drive_backup_at'] != null
          ? DateTime.tryParse(r['last_drive_backup_at'] as String)
          : null,
    );
  }

  Future<void> saveUserProfile(UserProfile p) async {
    final db = await database;
    await db.insert(
      'user_profile',
      {
        'id': 1,
        'sex': p.sex,
        'birth_year': p.birthYear,
        'height_cm': p.heightCm,
        'current_weight_kg': p.currentWeightKg,
        'activity_multiplier': p.activityMultiplier,
        'goal_type': p.goalType.name,
        'is_manual_override': p.isManualOverride ? 1 : 0,
        'target_kcal': p.targetKcal,
        'target_protein_g': p.targetProteinG,
        'target_carbs_g': p.targetCarbsG,
        'target_fat_g': p.targetFatG,
        'target_fiber_g': p.targetFiberG,
        'target_water_ml': p.targetWaterMl,
        'preferred_ai_provider': p.preferredAiProvider.name,
        'preferred_ai_model': p.preferredAiModel,
        'auto_backup_enabled': p.autoBackupEnabled ? 1 : 0,
        'last_drive_backup_at': p.lastDriveBackupAt?.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    onDataMutated?.call();
  }
}
