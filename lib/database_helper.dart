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
      version: 3,
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
        is_favorite INTEGER NOT NULL DEFAULT 0
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
        created_at TEXT NOT NULL
      )
    ''');
  }

  // --- DAILY ENTRY METHODS ---
  Future<int> insertDailyEntry(String dateKey, String name, int protein, int carbs, int fat, {String? createdAt}) async {
    final db = await instance.database;
    return await db.insert('daily_entries', {
      'date_key': dateKey,
      'name': name,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'calories': (protein * 4) + (carbs * 4) + (fat * 9),
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

  Future<int> updateDailyEntry(int id, String name, int protein, int carbs, int fat) async {
    final db = await instance.database;
    return await db.update(
      'daily_entries',
      {
        'name': name,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'calories': (protein * 4) + (carbs * 4) + (fat * 9),
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
  Future<void> insertCustomFood(String name, int p, int c, int f) async {
    final db = await instance.database;
    await db.insert('custom_foods', {
      'name': name,
      'protein': p,
      'carbs': c,
      'fat': f,
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

  Future<int> updateCustomFood(int id, String name, int p, int c, int f) async {
    final db = await instance.database;
    return await db.update(
      'custom_foods',
      {
        'name': name,
        'protein': p,
        'carbs': c,
        'fat': f,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteCustomFood(int id) async {
    final db = await instance.database;
    return await db.delete('custom_foods', where: 'id = ?', whereArgs: [id]);
  }
}