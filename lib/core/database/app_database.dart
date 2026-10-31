import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;

    final databasePath = await getDatabasesPath();

    _database = await openDatabase(
      path.join(databasePath, 'preplist.db'),
      version: 8,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _createMealsTable(db);
        await _createRecipeTables(db);
        await _createShoppingTables(db);
        await _createInventoryUsageTable(db);
        await _createFoodTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createRecipeTables(db);
        }

        if (oldVersion < 3) {
          await db.execute(
            "ALTER TABLE meals ADD COLUMN item_type TEXT NOT NULL DEFAULT 'ingredient'",
          );
          await db.execute('ALTER TABLE meals ADD COLUMN recipe_id INTEGER');
          await db.execute(
            "ALTER TABLE meals ADD COLUMN quantity TEXT NOT NULL DEFAULT ''",
          );
          await db.execute(
            "ALTER TABLE meals ADD COLUMN unit TEXT NOT NULL DEFAULT ''",
          );
        }

        if (oldVersion < 4) {
          await _createShoppingTables(db);
        }

        if (oldVersion >= 4 && oldVersion < 5) {
          await db.execute(
            'ALTER TABLE grocery_items '
            'ADD COLUMN inventory_added INTEGER NOT NULL DEFAULT 0',
          );
        }

        if (oldVersion < 6) {
          await db.execute(
            'ALTER TABLE recipe_ingredients ADD COLUMN food_id INTEGER',
          );
          await db.execute('ALTER TABLE meals ADD COLUMN food_id INTEGER');
        }

        if (oldVersion < 7) {
          await _createInventoryUsageTable(db);
        }

        if (oldVersion < 8) {
          await _createFoodTables(db);
        }
      },
    );

    return _database!;
  }

  Future<void> _createMealsTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE meals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        category TEXT NOT NULL,
        name TEXT NOT NULL,
        item_type TEXT NOT NULL DEFAULT 'ingredient',
        recipe_id INTEGER,
        food_id INTEGER,
        quantity TEXT NOT NULL DEFAULT '',
        unit TEXT NOT NULL DEFAULT ''
      )
    ''');

    await db.execute('''
      CREATE INDEX meals_date_index ON meals(date)
    ''');
  }

  Future<void> _createRecipeTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE recipes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT NOT NULL DEFAULT '',
        instructions TEXT NOT NULL DEFAULT '',
        prep_minutes INTEGER NOT NULL DEFAULT 0,
        cook_minutes INTEGER NOT NULL DEFAULT 0,
        servings INTEGER NOT NULL DEFAULT 1,
        calories REAL NOT NULL DEFAULT 0,
        protein REAL NOT NULL DEFAULT 0,
        carbs REAL NOT NULL DEFAULT 0,
        fat REAL NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE recipe_ingredients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        recipe_id INTEGER NOT NULL,
        food_id INTEGER,
        name TEXT NOT NULL,
        amount TEXT NOT NULL DEFAULT '',
        unit TEXT NOT NULL DEFAULT '',
        FOREIGN KEY (recipe_id)
          REFERENCES recipes(id)
          ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE INDEX recipe_ingredients_recipe_index
      ON recipe_ingredients(recipe_id)
    ''');
  }

  Future<void> _createShoppingTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE grocery_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        item_key TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        amount TEXT NOT NULL DEFAULT '',
        unit TEXT NOT NULL DEFAULT '',
        is_bought INTEGER NOT NULL DEFAULT 0,
        inventory_added INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE inventory_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        item_key TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        amount TEXT NOT NULL DEFAULT '',
        unit TEXT NOT NULL DEFAULT ''
      )
    ''');
  }

  Future<void> _createInventoryUsageTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE inventory_usage (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        item_key TEXT NOT NULL,
        name TEXT NOT NULL,
        amount TEXT NOT NULL,
        unit TEXT NOT NULL DEFAULT '',
        used_at TEXT NOT NULL,
        is_undone INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE INDEX inventory_usage_date_index
      ON inventory_usage(used_at)
    ''');
  }

  Future<void> _createFoodTables(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE foods (
        external_id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        synonyms TEXT NOT NULL DEFAULT '',
        calories REAL NOT NULL DEFAULT 0,
        protein REAL NOT NULL DEFAULT 0,
        carbs REAL NOT NULL DEFAULT 0,
        fat REAL NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE INDEX foods_name_index ON foods(name)
    ''');

    await db.execute('''
      CREATE TABLE metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }
}
