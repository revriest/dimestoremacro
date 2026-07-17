import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  // Singleton pattern to ensure we only have one database instance open
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('dimestore_macros.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 6,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS daily_entries (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date_key TEXT NOT NULL,
          name TEXT NOT NULL,
          protein INTEGER NOT NULL,
          carbs INTEGER NOT NULL,
          fat INTEGER NOT NULL,
          calories INTEGER NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');

      final legacyRows = await db.query('daily_logs');
      for (final row in legacyRows) {
        await db.insert('daily_entries', {
          'date_key': row['date_key'],
          'name': 'Migrated Total',
          'protein': row['protein'],
          'carbs': row['carbs'],
          'fat': row['fat'],
          'calories': row['calories'],
          'created_at': '${row['date_key']}T00:00:00',
        });
      }
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE custom_foods ADD COLUMN is_favorite INTEGER NOT NULL DEFAULT 0');
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS weight_logs (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date_key TEXT NOT NULL UNIQUE,
          weight_kg REAL NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 5) {
      await db.execute(
        "ALTER TABLE daily_entries ADD COLUMN entry_mode TEXT NOT NULL DEFAULT 'grams'",
      );
    }
    if (oldVersion < 6) {
      await db.execute(
        "ALTER TABLE custom_foods ADD COLUMN measure_mode TEXT NOT NULL DEFAULT 'grams'",
      );
      await db.execute(
        'ALTER TABLE custom_foods ADD COLUMN measure_amount REAL NOT NULL DEFAULT 100',
      );
      await db.execute(
        'ALTER TABLE custom_foods ADD COLUMN serving_grams REAL',
      );
    }
  }

  Future _createDB(Database db, int version) async {
    // Table for daily macro totals
    await db.execute('''
      CREATE TABLE daily_logs (
        date_key TEXT PRIMARY KEY,
        protein INTEGER NOT NULL,
        carbs INTEGER NOT NULL,
        fat INTEGER NOT NULL,
        calories INTEGER NOT NULL
      )
    ''');

    // Table for the Custom Food Library
    await db.execute('''
      CREATE TABLE custom_foods (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        protein INTEGER NOT NULL,
        carbs INTEGER NOT NULL,
        fat INTEGER NOT NULL,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        measure_mode TEXT NOT NULL DEFAULT 'grams',
        measure_amount REAL NOT NULL DEFAULT 100,
        serving_grams REAL
      )
    ''');

    // Table for per-entry daily logs
    await db.execute('''
      CREATE TABLE daily_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date_key TEXT NOT NULL,
        name TEXT NOT NULL,
        protein INTEGER NOT NULL,
        carbs INTEGER NOT NULL,
        fat INTEGER NOT NULL,
        calories INTEGER NOT NULL,
        entry_mode TEXT NOT NULL DEFAULT 'grams',
        created_at TEXT NOT NULL
      )
    ''');

    // Table for daily weight tracking history
    await db.execute('''
      CREATE TABLE weight_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date_key TEXT NOT NULL UNIQUE,
        weight_kg REAL NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
  }

  // --- WEIGHT TRACKING METHODS ---
  Future<void> upsertWeightLog(String dateKey, double weightKg, {String? createdAt}) async {
    final db = await instance.database;
    await db.insert(
      'weight_logs',
      {
        'date_key': dateKey,
        'weight_kg': weightKg,
        'created_at': createdAt ?? DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getWeightForDate(String dateKey) async {
    final db = await instance.database;
    final maps = await db.query(
      'weight_logs',
      where: 'date_key = ?',
      whereArgs: [dateKey],
      limit: 1,
    );
    if (maps.isNotEmpty) return maps.first;
    return null;
  }

  Future<Map<String, dynamic>?> getLatestWeight() async {
    final db = await instance.database;
    final maps = await db.query(
      'weight_logs',
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (maps.isNotEmpty) return maps.first;
    return null;
  }

  Future<List<Map<String, dynamic>>> getWeightHistoryInRange(DateTime startInclusive, DateTime endInclusive) async {
    final db = await instance.database;
    return await db.query(
      'weight_logs',
      where: 'created_at >= ? AND created_at <= ?',
      whereArgs: [startInclusive.toIso8601String(), endInclusive.toIso8601String()],
      orderBy: 'created_at ASC',
    );
  }

  // --- DAILY ENTRY METHODS ---
  Future<int> insertDailyEntry(
    String dateKey,
    String name,
    int protein,
    int carbs,
    int fat, {
    String entryMode = 'grams',
    String? createdAt,
  }) async {
    final db = await instance.database;
    return await db.insert('daily_entries', {
      'date_key': dateKey,
      'name': name,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'calories': (protein * 4) + (carbs * 4) + (fat * 9),
      'entry_mode': entryMode,
      'created_at': createdAt ?? DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getDailyEntries(String dateKey) async {
    final db = await instance.database;
    return await db.query(
      'daily_entries',
      where: 'date_key = ?',
      whereArgs: [dateKey],
      orderBy: 'created_at ASC',
    );
  }

  Future<Map<String, int>> getDailyTotals(String dateKey) async {
    final db = await instance.database;
    final result = await db.rawQuery(
      'SELECT SUM(protein) AS protein, SUM(carbs) AS carbs, SUM(fat) AS fat, SUM(calories) AS calories FROM daily_entries WHERE date_key = ?',
      [dateKey],
    );
    final row = result.first;
    return {
      'protein': row['protein'] as int? ?? 0,
      'carbs': row['carbs'] as int? ?? 0,
      'fat': row['fat'] as int? ?? 0,
      'calories': row['calories'] as int? ?? 0,
    };
  }

  Future<int> updateDailyEntry(
    int id,
    String name,
    int protein,
    int carbs,
    int fat, {
    String entryMode = 'grams',
  }) async {
    final db = await instance.database;
    return await db.update(
      'daily_entries',
      {
        'name': name,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'calories': (protein * 4) + (carbs * 4) + (fat * 9),
        'entry_mode': entryMode,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteDailyEntry(int id) async {
    final db = await instance.database;
    return await db.delete('daily_entries', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> deleteEntriesForDate(String dateKey) async {
    final db = await instance.database;
    return await db.delete('daily_entries', where: 'date_key = ?', whereArgs: [dateKey]);
  }

  // --- DAILY LOG METHODS ---
  Future<void> saveDailyLog(String dateKey, int p, int c, int f, int cal) async {
    final db = await instance.database;
    await db.insert(
      'daily_logs',
      {'date_key': dateKey, 'protein': p, 'carbs': c, 'fat': f, 'calories': cal},
      conflictAlgorithm: ConflictAlgorithm.replace, // Overwrites if the day already exists
    );
  }

  Future<Map<String, dynamic>?> getDailyLog(String dateKey) async {
    final db = await instance.database;
    final maps = await db.query(
      'daily_logs',
      where: 'date_key = ?',
      whereArgs: [dateKey],
    );
    if (maps.isNotEmpty) return maps.first;
    return null;
  }

  // --- CUSTOM FOOD METHODS ---
  Future<void> insertCustomFood(
    String name,
    int p,
    int c,
    int f, {
    String measureMode = 'grams',
    double measureAmount = 100,
    double? servingGrams,
  }) async {
    final db = await instance.database;
    await db.insert('custom_foods', {
      'name': name,
      'protein': p,
      'carbs': c,
      'fat': f,
      'measure_mode': measureMode,
      'measure_amount': measureAmount,
      'serving_grams': servingGrams,
    });
  }

  Future<List<Map<String, dynamic>>> getAllCustomFoods({bool favoritesOnly = false}) async {
    final db = await instance.database;
    if (favoritesOnly) {
      return await db.query('custom_foods', where: 'is_favorite = 1', orderBy: 'name ASC');
    }
    return await db.query('custom_foods', orderBy: 'name ASC');
  }

  Future<int> toggleCustomFoodFavorite(int id, bool isFavorite) async {
    final db = await instance.database;
    return await db.update(
      'custom_foods',
      {'is_favorite': isFavorite ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateCustomFood(
    int id,
    String name,
    int p,
    int c,
    int f, {
    String? measureMode,
    double? measureAmount,
    double? servingGrams,
  }) async {
    final db = await instance.database;
    final values = <String, dynamic>{
      'name': name,
      'protein': p,
      'carbs': c,
      'fat': f,
    };
    if (measureMode != null) values['measure_mode'] = measureMode;
    if (measureAmount != null) values['measure_amount'] = measureAmount;
    if (servingGrams != null) values['serving_grams'] = servingGrams;

    return await db.update(
      'custom_foods',
      values,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteCustomFood(int id) async {
    final db = await instance.database;
    return await db.delete('custom_foods', where: 'id = ?', whereArgs: [id]);
  }
}