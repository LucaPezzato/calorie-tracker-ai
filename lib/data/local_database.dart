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
      waterMl: r['water_ml'] as int,
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
  }
}
